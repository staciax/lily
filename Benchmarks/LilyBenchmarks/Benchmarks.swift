//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//
//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Benchmark
import Foundation

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration = .init(
        metrics: ProcessInfo.processInfo.environment["CI"] != nil
            ? [
                .instructions,
                .mallocCountTotal,
                .throughput,
            ]
            : [
                .cpuTotal,
                .instructions,
                .mallocCountTotal,
                .throughput,
            ],
        warmupIterations: 10
    )

    formattingBenchmarks()
    filteringBenchmarks()
}
