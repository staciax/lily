// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "lily",
    products: [
        .library(name: "Lily", targets: ["Lily"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.14.0")
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

if Context.environment["ENABLE_LILY_BENCHMARKS"] != nil {
    package.platforms = [.macOS(.v15), .iOS(.v18), .macCatalyst(.v18), .tvOS(.v18), .visionOS(.v2)]
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
