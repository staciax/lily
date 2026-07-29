// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "lily",
    products: [
        .library(name: "Lily", targets: ["Lily"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.12.0")
    ],
    targets: [
        .target(
            name: "Lily",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources/Lily"
        ),
        .testTarget(
            name: "LilyTests",
            dependencies: ["Lily"],
            path: "Tests/LilyTests"
        ),
    ]
)

// Benchmarks are opt-in so consumers never resolve package-benchmark.
// Enable with: ENABLE_LILY_BENCHMARKS=1 swift package benchmark
if Context.environment["ENABLE_LILY_BENCHMARKS"] != nil {
    package.platforms = [.macOS(.v14)]
    package.dependencies.append(
        .package(url: "https://github.com/ordo-one/benchmark", from: "1.34.1")
    )
    package.targets.append(
        .executableTarget(
            name: "LilyBenchmarks",
            dependencies: [
                "Lily",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Benchmark", package: "benchmark"),
            ],
            path: "Benchmarks/LilyBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark")
            ]
        )
    )
}
