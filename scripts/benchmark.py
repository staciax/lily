#!/usr/bin/env -S uv run --python 3.14 --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "rich",
#     "wcwidth",
# ]
# ///
from __future__ import annotations

import argparse
import json
import os
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from collections.abc import Sequence
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from enum import Enum
from pathlib import Path

from rich.console import Console  # ty: ignore[unresolved-import]
from rich.markdown import Markdown  # ty: ignore[unresolved-import]
from wcwidth import wcswidth  # ty: ignore[unresolved-import]

REPO_URL = "git@github.com:staciax/pre-lily.git"


class Alignment(Enum):
    left = "left"
    right = "right"
    center = "center"


@dataclass
class CommandResult:
    stdout: str
    stderr: str
    returncode: int

    @property
    def ok(self) -> bool:
        return self.returncode == 0


@dataclass
class BenchmarkData:
    runs: list[list[dict]]
    stats: dict[str, dict]


@dataclass
class BenchmarkResult:
    main: BenchmarkData
    pr: BenchmarkData


@dataclass
class BenchmarkContext:
    main_dir: Path
    pr_dir: Path
    swift_path: str
    benchmark_filter: str
    runs: int
    report_path: Path | None


def find_binary(name: str) -> str:
    path = shutil.which(name)
    if not path:
        raise FileNotFoundError(f"{name} not found in PATH")
    return path


def run_binary(
    name: str,
    args: Sequence[str],
    check: bool = False,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
) -> CommandResult:
    binary = find_binary(name)
    result = subprocess.run(
        [binary, *args],
        capture_output=True,
        text=True,
        cwd=cwd,
        env=env,
    )
    if check and result.returncode != 0:
        raise subprocess.CalledProcessError(
            result.returncode, [name, *args], result.stdout, result.stderr
        )
    return CommandResult(stdout=result.stdout, stderr=result.stderr, returncode=result.returncode)


def _strip_ansi(text: str) -> str:
    import re
    return re.sub(r"\x1b\[[0-9;]*m", "", text)


def _cell_width(text: str) -> int:
    return wcswidth(_strip_ansi(text))


def _pad(text: str, width: int) -> str:
    padding = width - _cell_width(text)
    return text + " " * max(padding, 0)


def render_markdown_table(
    headers: Sequence[str],
    rows: Sequence[Sequence[str]],
    align: Sequence[Alignment] | None = None,
) -> str:
    if align is None:
        align = [Alignment.left] * len(headers)

    col_count = len(headers)
    widths = [_cell_width(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row[:col_count]):
            widths[i] = max(widths[i], _cell_width(cell))

    def _sep(a: Alignment, w: int) -> str:
        if a == Alignment.right:
            return "-" * (w - 1) + ":"
        if a == Alignment.center:
            return ":" + "-" * (w - 2) + ":"
        return "-" * w

    header_line = "| " + " | ".join(_pad(h, widths[i]) for i, h in enumerate(headers)) + " |"
    sep_line = "| " + " | ".join(_sep(align[i], widths[i]) for i in range(col_count)) + " |"
    data_lines = []
    for row in rows:
        cells = [_pad(row[i] if i < len(row) else "", widths[i]) for i in range(col_count)]
        data_lines.append("| " + " | ".join(cells) + " |")

    return "\n".join([header_line, sep_line, *data_lines])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Benchmark comparison for Lily",
        suggest_on_error=True
    )
    parser.add_argument("--main", type=Path, default=None, help="Path to main branch checkout (auto-clones if omitted)")
    parser.add_argument("--pr", type=Path, default=Path.cwd(), help="Path to PR branch checkout")
    parser.add_argument("--branch", default="main", help="Branch to clone if --main omitted")
    parser.add_argument("--runs", type=int, default=int(os.environ.get("BENCH_RUNS", "10")), help="Benchmark runs per state")
    parser.add_argument("--filter", default="", help="Benchmark filter string")
    parser.add_argument("--sync", action=argparse.BooleanOptionalAction, help="Sync Benchmarks/ from PR to main before running (default: skip)")
    parser.add_argument("--cleanup", action=argparse.BooleanOptionalAction, help="Delete cloned main after run")
    parser.add_argument("--report", type=Path, default=None, help="Output report file path (prints to stdout if omitted)")
    parser.add_argument("--swift", default=None, help="Path to swift binary (auto-detected if omitted)")
    parser.add_argument("--repo-url", default=REPO_URL, help="Git repo URL for cloning main")
    return parser.parse_args()


def flush_system_caches() -> None:
    run_binary("sync", [], check=False)
    time.sleep(0.5)


def clone_main(branch: str, repo_url: str) -> Path:
    tmp_dir = Path(tempfile.mkdtemp(prefix="lily-main-"))
    clone_dir = tmp_dir / "lily-main"
    print(f"Cloning {repo_url} (branch: {branch}) → {clone_dir}")
    run_binary("git", ["clone", "--branch", branch, "--depth", "1", repo_url, str(clone_dir)], check=True)
    return clone_dir


def _benchmarks_differ(pr_bench: Path, main_bench: Path) -> bool:
    pr_files = sorted(f.relative_to(pr_bench) for f in pr_bench.rglob("*.swift"))
    main_files = sorted(f.relative_to(main_bench) for f in main_bench.rglob("*.swift"))
    if pr_files != main_files:
        return True
    for rel in pr_files:
        if (pr_bench / rel).read_bytes() != (main_bench / rel).read_bytes():
            return True
    return False


def sync_benchmarks(pr_dir: Path, main_dir: Path, *, sync: bool = False) -> None:
    pr_bench = pr_dir / "Benchmarks"
    main_bench = main_dir / "Benchmarks"

    if not pr_bench.exists():
        print("Benchmarks/: PR directory not found, skipping")
        return

    if not sync:
        if main_bench.exists() and _benchmarks_differ(pr_bench, main_bench):
            print("WARNING: Benchmarks/ differ between PR and main — results may not be comparable", file=sys.stderr)
        return

    if main_bench.exists():
        shutil.rmtree(main_bench)
    shutil.copytree(pr_bench, main_bench)
    print("Benchmarks/: synced from PR → main")


def benchmark_flags_str(benchmark_filter: str) -> str:
    filter_flag = f"--filter {benchmark_filter} " if benchmark_filter else ""
    return f"{filter_flag}--format jsonSmallerIsBetter --path stdout --quiet --no-progress"


def parse_json_array(output: str) -> list[dict]:
    idx = output.rfind("[")
    while idx != -1:
        candidate = output[idx:].strip()
        try:
            parsed = json.loads(candidate)
            if isinstance(parsed, list):
                return parsed
        except json.JSONDecodeError:
            pass
        idx = output.rfind("[", 0, idx)
    raise ValueError(f"No JSON array found in benchmark output.\nSTDOUT:\n{output}")


def inject_throughput(payload: list[dict]) -> list[dict]:
    augmented = list(payload)
    for item in payload:
        name = item["name"]
        if name.endswith(" - Time (total CPU)"):
            target = name.split(" - ")[0]
            val = item["value"]
            if val > 0:
                tp = round(1_000_000_000.0 / val, 2)
                augmented.append({
                    "unit": "ops/s",
                    "name": f"{target} - Throughput (ops/s)",
                    "value": tp,
                })
    return augmented


def run_single_benchmark(
    iteration_num: int,
    tag: str,
    cwd: Path,
    context: BenchmarkContext,
) -> list[dict]:
    flush_system_caches()
    args = ["package", "--disable-sandbox", "benchmark"]
    if context.benchmark_filter:
        args.extend(["--filter", context.benchmark_filter])
    args.extend(["--format", "jsonSmallerIsBetter", "--path", "stdout", "--quiet", "--no-progress"])
    env = {**os.environ, "ENABLE_LILY_BENCHMARKS": "1"}
    print(f"[{tag}] Running iteration {iteration_num}/{context.runs} in {cwd.name}...")
    res = run_binary("swift", args, check=True, cwd=cwd, env=env)
    payload = parse_json_array(res.stdout)
    return inject_throughput(payload)


def collect_runs(tag: str, cwd: Path, context: BenchmarkContext) -> list[list[dict]]:
    return [
        run_single_benchmark(i, tag, cwd, context)
        for i in range(1, context.runs + 1)
    ]


def _stats_for_metric(name: str, values: list[float]) -> tuple[str, dict[str, float | list[float]]]:
    return name, {
        "values": values,
        "median": statistics.median(values),
        "mean": statistics.mean(values),
        "min": min(values),
        "max": max(values),
        "stdev": statistics.stdev(values) if len(values) > 1 else 0.0,
    }


def compute_statistics(runs_data: list[list[dict]]) -> dict[str, dict[str, float | list[float]]]:
    metrics_map: dict[str, list[float]] = {}
    for run in runs_data:
        for item in run:
            metrics_map.setdefault(item["name"], []).append(item["value"])

    with ThreadPoolExecutor(max_workers=min(len(metrics_map) or 1, (os.cpu_count() or 4) * 2)) as pool:
        return dict(pool.map(lambda kv: _stats_for_metric(*kv), metrics_map.items()))


def delta_percent(main_value: float, pr_value: float) -> str:
    if main_value == 0:
        return "n/a"
    return f"{((pr_value - main_value) / main_value) * 100:+.2f}%"


def format_value(value: float, metric_type: str) -> str:
    if metric_type == "Throughput (ops/s)":
        if value >= 1_000_000:
            return f"{value / 1_000_000:.2f} M ops/s"
        return f"{int(round(value)):,} ops/s"
    elif metric_type == "Time (total CPU)":
        if value < 1000:
            return f"{value:.1f} ns" if value % 1 != 0 else f"{int(value)} ns"
        return f"{value:,.1f} ns"
    elif metric_type == "Malloc (total)":
        return f"{int(round(value))}"
    return f"{int(round(value)):,}" if value >= 10 else f"{value:.2f}"


def build_summary_table(main_stats: dict[str, dict], pr_stats: dict[str, dict]) -> str:
    all_keys = set(main_stats.keys()) & set(pr_stats.keys())
    targets = sorted(set(k.split(" - ")[0] for k in all_keys))

    headers = ["Target", "main", "pr", "Delta"]
    align = [Alignment.left, Alignment.right, Alignment.right, Alignment.right]

    # Throughput
    tp_rows = []
    for t in targets:
        tp_main = main_stats.get(f"{t} - Throughput (ops/s)", {}).get("median", 0)
        tp_pr = pr_stats.get(f"{t} - Throughput (ops/s)", {}).get("median", 0)
        tp_rows.append([
            f"{t}",
            format_value(tp_main, "Throughput (ops/s)"),
            f"**{format_value(tp_pr, 'Throughput (ops/s)')}**",
            f"**{delta_percent(float(tp_main), float(tp_pr))}**",
        ])
    tp_table = render_markdown_table(headers, tp_rows, align)

    # Malloc
    m_rows = []
    for t in targets:
        m_main = main_stats.get(f"{t} - Malloc (total)", {}).get("median", 0)
        m_pr = pr_stats.get(f"{t} - Malloc (total)", {}).get("median", 0)
        m_rows.append([
            f"{t}",
            format_value(m_main, "Malloc (total)"),
            f"**{format_value(m_pr, 'Malloc (total)')}**",
            f"**{delta_percent(float(m_main), float(m_pr))}**",
        ])
    m_table = render_markdown_table(headers, m_rows, align)

    # Instructions
    inst_rows = []
    for t in targets:
        i_main = main_stats.get(f"{t} - Instructions", {}).get("median", 0)
        i_pr = pr_stats.get(f"{t} - Instructions", {}).get("median", 0)
        inst_rows.append([
            f"{t}",
            format_value(i_main, "Instructions"),
            f"**{format_value(i_pr, 'Instructions')}**",
            f"**{delta_percent(float(i_main), float(i_pr))}**",
        ])
    inst_table = render_markdown_table(headers, inst_rows, align)

    return f"### throughput\n\n{tp_table}\n\n### malloc\n\n{m_table}\n\n### instructions\n\n{inst_table}"


def format_report(context: BenchmarkContext, result: BenchmarkResult, *, file_output: bool) -> str:
    raw_dataset = {
        "main_dir": str(context.main_dir),
        "pr_dir": str(context.pr_dir),
        "benchmark_filter": context.benchmark_filter,
        "runs_per_state": context.runs,
        "pr": {f"run{i + 1}": result.pr.runs[i] for i in range(context.runs)},
        "main": {f"run{i + 1}": result.main.runs[i] for i in range(context.runs)},
    }
    summary_table = build_summary_table(result.main.stats, result.pr.stats)

    details_section = ""
    if file_output:
        details_section = f"""
---

<details>
<summary>Detailed Statistics</summary>

### Main
```json
{json.dumps({k: {m: v for m, v in val.items() if m != 'values'} for k, val in result.main.stats.items()}, indent=2)}
```

### PR
```json
{json.dumps({k: {m: v for m, v in val.items() if m != 'values'} for k, val in result.pr.stats.items()}, indent=2)}
```

</details>

---

<details>
<summary>Raw Dataset</summary>

```json
{json.dumps(raw_dataset, indent=2)}
```

</details>
"""

    return f"""# Benchmark Comparison

| | |
|---|---|
| Main | `{context.main_dir}` |
| PR | `{context.pr_dir}` |
| Filter | `{context.benchmark_filter or 'None'}` |
| Runs | `{context.runs}` |
| Command | `ENABLE_LILY_BENCHMARKS=1 {context.swift_path} package --disable-sandbox benchmark {benchmark_flags_str(context.benchmark_filter)}` |
| Python | `{sys.version_info.major}.{sys.version_info.minor}` |

---

## Performance Results

{summary_table}
{details_section}"""


def main() -> int:
    args = parse_args()
    if args.swift:
        swift_path = str(args.swift)
        if not Path(swift_path).is_file():
            print(f"Error: swift not found at: {swift_path}", file=sys.stderr)
            return 1
    else:
        try:
            swift_path = find_binary("swift")
        except FileNotFoundError as e:
            print(f"Error: {e}", file=sys.stderr)
            return 1

    # Resolve main directory
    cloned = False
    main_dir = Path(".")

    try:
        # Resolve main directory
        if args.main is not None:
            main_dir = args.main.resolve()
        else:
            main_dir = clone_main(args.branch, args.repo_url)
            cloned = True

        pr_dir = args.pr.resolve()

        context = BenchmarkContext(
            main_dir=main_dir,
            pr_dir=pr_dir,
            swift_path=swift_path,
            benchmark_filter=args.filter,
            runs=args.runs,
            report_path=args.report,
        )

        print(f"benchmark: {context.runs} runs")
        print(f"main: {context.main_dir}")
        print(f"pr: {context.pr_dir}")
        print(f"filter: {context.benchmark_filter or 'None'}")
        print(f"python: {sys.version_info.major}.{sys.version_info.minor}")
        swift_ver = run_binary("swift", ["--version"]).stdout.splitlines()[0] if swift_path else "unknown"
        print(f"swift: {context.swift_path} ({swift_ver})")

        sync_benchmarks(context.pr_dir, context.main_dir, sync=args.sync)

        if not context.main_dir.exists():
            print(f"Error: Main directory not found: {context.main_dir}", file=sys.stderr)
            return 1
        if not context.pr_dir.exists():
            print(f"Error: PR directory not found: {context.pr_dir}", file=sys.stderr)
            return 1

        print("\nphase 1: main")
        main_runs = collect_runs("main", context.main_dir, context)

        print("\nphase 2: pr")
        pr_runs = collect_runs("pr", context.pr_dir, context)

        print("\nphase 3: stats + report")
        main_stats = compute_statistics(main_runs)
        pr_stats = compute_statistics(pr_runs)

        result = BenchmarkResult(
            main=BenchmarkData(runs=main_runs, stats=main_stats),
            pr=BenchmarkData(runs=pr_runs, stats=pr_stats),
        )
        if context.report_path is not None:
            report = format_report(context, result, file_output=True)
            context.report_path.write_text(report, encoding="utf-8")
            print(f"\nBenchmark report written to: {context.report_path}")
        else:
            console = Console()
            console.print(Markdown(format_report(context, result, file_output=False)))

        if cloned and args.cleanup:
            print(f"\nCleaning up cloned main: {context.main_dir.parent}")
            shutil.rmtree(context.main_dir.parent)
        elif cloned:
            print(f"\nCloned main preserved at: {context.main_dir.parent}")

    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        if cloned:
            shutil.rmtree(main_dir.parent, ignore_errors=True)
        return 130

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
