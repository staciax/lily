# Benchmarks

Performance benchmarks for Lily's

## Prerequisites

- macOS: `brew install jemalloc`
- Linux: `apt-get install -y libjemalloc-dev`

## Running

From the repository root, with benchmarks enabled:

```sh
ENABLE_LILY_BENCHMARKS=1 swift package --disable-sandbox benchmark
```
