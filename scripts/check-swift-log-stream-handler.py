#!/usr/bin/env -S uv run --python 3.14t --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
from __future__ import annotations

import argparse
import difflib
import json
import os
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path, PurePath, PurePosixPath

UPSTREAM_RAW_BASE = "https://raw.githubusercontent.com/apple/swift-log"


@dataclass(frozen=True)
class TrackedFile:
    # Path of the file within the upstream swift-log repository.
    upstream_relative: PurePosixPath
    # Pinned snapshot of the upstream file, vendored in this repo.
    snapshot: Path
    # Lily's local adaptation and the patch that should reproduce it from the
    # snapshot. Both are `None` for files we only track for upstream drift (e.g.
    # the upstream test, which Lily reimplements rather than patches).
    local: Path | None = None
    expected_patch: Path | None = None


TRACKED_FILES = [
    # The vendored handler: must equal `snapshot + expected_patch`.
    TrackedFile(
        upstream_relative=PurePosixPath("Sources/Logging/Handlers/StreamLogHandler.swift"),
        snapshot=Path("Tests/Fixtures/swift-log/Sources/Logging/Handlers/StreamLogHandler.swift"),
        local=Path("Sources/Lily/Handlers/StreamLogHandler.swift"),
        expected_patch=Path(
            "Tests/Fixtures/swift-log/Sources/Logging/Handlers/StreamLogHandler.patch"
        ),
    ),
    # The upstream handler test: tracked for upstream drift only. Lily's port
    # (`Tests/LilyTests/Handlers/StreamLogHandlerTests.swift`) is a superset
    # rewrite, so there is no patch to enforce — a drift warning is the cue to
    # review and re-port new upstream cases.
    TrackedFile(
        upstream_relative=PurePosixPath("Tests/LoggingTests/StreamLogHandlerTest.swift"),
        snapshot=Path("Tests/Fixtures/swift-log/Tests/LoggingTests/StreamLogHandlerTest.swift"),
    ),
]


def repo_path(root: Path, path: Path) -> Path:
    return path if path.is_absolute() else root / path


def display_path(root: Path, path: PurePath) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def unified_diff(root: Path, old_path: PurePath, old: str, new_path: PurePath, new: str) -> str:
    return "".join(
        difflib.unified_diff(
            old.splitlines(keepends=True),
            new.splitlines(keepends=True),
            fromfile=display_path(root, old_path),
            tofile=display_path(root, new_path),
        )
    )


def _should_color(mode: str) -> bool:
    """Decide whether to emit ANSI color codes on stderr."""
    if mode == "always":
        return True
    if mode == "never":
        return False
    # mode == "auto": color only when stderr is a real terminal.
    return (
        sys.stderr.isatty()
        and "NO_COLOR" not in os.environ
        and os.environ.get("TERM") != "dumb"
    )


def _colorize_diff(diff_text: str, *, color: bool) -> str:
    """Apply ANSI color codes to unified-diff output."""
    if not color:
        return diff_text
    lines: list[str] = []
    for line in diff_text.splitlines(keepends=True):
        # Determine color. Order matters: `---`/`+++` must be checked before
        # `-`/`+` since they share the same prefix.
        if line.startswith("---") or line.startswith("+++"):
            code = "\033[1m"       # bold — file headers
        elif line.startswith("@@"):
            code = "\033[36m"      # cyan — hunk headers
        elif line.startswith("-"):
            code = "\033[31m"      # red — deletions
        elif line.startswith("+"):
            code = "\033[32m"      # green — additions
        else:
            lines.append(line)
            continue
        # Insert reset before trailing newline so colour doesn't bleed.
        if line.endswith("\n"):
            lines.append(f"{code}{line[:-1]}\033[0m\n")
        else:
            lines.append(f"{code}{line}\033[0m")
    return "".join(lines)


def pinned_swift_log_revision(package_resolved: Path) -> str:
    data = json.loads(read_text(package_resolved))

    for pin in data.get("pins", []):
        if pin.get("identity") == "swift-log":
            revision = pin.get("state", {}).get("revision")
            if revision:
                return revision

    raise RuntimeError(f"swift-log pin not found in {package_resolved}")


def upstream_url(revision: str, relative: PurePosixPath) -> str:
    return f"{UPSTREAM_RAW_BASE}/{revision}/{relative.as_posix()}"


def fetch_text(url: str) -> str:
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            return response.read().decode("utf-8")
    except urllib.error.URLError as error:
        raise RuntimeError(f"failed to fetch {url}: {error}") from error


def check_tracked_file(root: Path, tracked: TrackedFile, revision: str, *, color: bool, update: bool = False) -> bool:
    """Checks one tracked file. Returns ``True`` on any failure."""
    snapshot = repo_path(root, tracked.snapshot)
    if not snapshot.is_file():
        print(f"missing required path: {display_path(root, snapshot)}", file=sys.stderr)
        return True

    snapshot_text = read_text(snapshot)

    url = upstream_url(revision, tracked.upstream_relative)
    try:
        upstream_text = fetch_text(url)
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        return True

    failed = False

    # 1) Upstream drift: the snapshot must match the pinned upstream revision.
    # Use a PurePosixPath only as a display label for the diff header; do not
    # round-trip the URL through Path(), since Path() collapses "https://" to "https:/".
    upstream_drift = unified_diff(root, snapshot, snapshot_text, PurePosixPath(url), upstream_text)
    if upstream_drift:
        print(
            f"upstream snapshot drift for {tracked.upstream_relative.as_posix()}:",
            file=sys.stderr,
        )
        sys.stderr.write(_colorize_diff(upstream_drift, color=color))
        failed = True

    # 2) Patch drift (impl only): local file must equal snapshot + expected patch.
    if tracked.local is not None and tracked.expected_patch is not None:
        local = repo_path(root, tracked.local)
        expected_patch = repo_path(root, tracked.expected_patch)
        for path in (local, expected_patch):
            if not path.is_file():
                print(f"missing required path: {display_path(root, path)}", file=sys.stderr)
                return True

        local_text = read_text(local)
        expected_patch_text = read_text(expected_patch)
        actual_patch_text = unified_diff(root, snapshot, snapshot_text, local, local_text)

        if actual_patch_text != expected_patch_text:
            if update:
                expected_patch.write_text(actual_patch_text, encoding="utf-8")
                print(f"Updated {display_path(root, expected_patch)}")
            else:
                print(f"local patch drift for {display_path(root, local)}:", file=sys.stderr)
                sys.stderr.write(
                    _colorize_diff(
                        unified_diff(
                            root,
                            expected_patch,
                            expected_patch_text,
                            Path("<generated local patch>"),
                            actual_patch_text,
                        ),
                        color=color,
                    )
                )
                failed = True

    return failed


def main() -> int:
    root = Path(__file__).resolve().parents[1]

    parser = argparse.ArgumentParser(
        color=True,
        suggest_on_error=True,
    )
    parser.add_argument("--package-resolved", type=Path, default=Path("Package.resolved"))
    parser.add_argument(
        "--color",
        choices=["auto", "always", "never"],
        default="auto",
        help="colorize diff output (default: auto)",
    )
    parser.add_argument(
        "--update",
        "-u",
        action=argparse.BooleanOptionalAction,
        default=False,
        help="automatically update expected patch files from current local files",
    )
    args = parser.parse_args()

    package_resolved = repo_path(root, args.package_resolved)
    if not package_resolved.is_file():
        print(f"missing required path: {display_path(root, package_resolved)}", file=sys.stderr)
        return 1

    try:
        revision = pinned_swift_log_revision(package_resolved)
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        return 1

    color = _should_color(args.color)

    failed = False
    for tracked in TRACKED_FILES:
        if check_tracked_file(root, tracked, revision, color=color, update=args.update):
            failed = True

    if failed:
        return 1

    print("swift-log StreamLogHandler copy is in sync.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
