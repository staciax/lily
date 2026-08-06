//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Benchmark
import Lily
import Logging

// MARK: - Filters

private struct MinimumLevelFilter: LogFiltering {
    var name: String { "min-level" }
    let threshold: Logger.Level

    func filter(_ event: LogEvent) -> LogEvent? {
        event.level >= threshold ? event : nil
    }
}

private struct RedactingFilter: LogFiltering {
    var name: String { "redact" }
    let sensitiveKeys: Set<String>

    func filter(_ event: LogEvent) -> LogEvent? {
        guard var metadata = event.metadata else { return event }
        var didRedact = false
        for key in sensitiveKeys where metadata[key] != nil {
            metadata[key] = .string("***")
            didRedact = true
        }
        guard didRedact else { return event }
        var redacted = event
        redacted.metadata = metadata
        return redacted
    }
}

private struct SourceDenylistFilter: LogFiltering {
    var name: String { "source-denylist" }
    let denylist: Set<String>

    func filter(_ event: LogEvent) -> LogEvent? {
        denylist.contains(event.source) ? nil : event
    }
}

private struct TruncatingFilter: LogFiltering {
    var name: String { "attribute-limiter" }
    let maxCharacters: Int

    func filter(_ event: LogEvent) -> LogEvent? {
        guard var metadata = event.metadata else { return event }
        var didTruncate = false
        for (key, value) in metadata {
            guard case .string(let str) = value else { continue }
            guard str.utf8.count > maxCharacters, str.count > maxCharacters else { continue }
            metadata[key] = .string(String(str.prefix(maxCharacters)) + "...")
            didTruncate = true
        }
        guard didTruncate else { return event }
        var truncated = event
        truncated.metadata = metadata
        return truncated
    }
}

private struct PrefixStrippingFilter: LogFiltering {
    var name: String { "strip-internal" }
    let prefix: String

    func filter(_ event: LogEvent) -> LogEvent? {
        guard var metadata = event.metadata else { return event }
        let initialCount = metadata.count
        metadata = metadata.filter { !$0.key.hasPrefix(prefix) }
        guard metadata.count != initialCount else { return event }
        var sanitized = event
        sanitized.metadata = metadata
        return sanitized
    }
}

func filteringBenchmarks() {
    let safetyFilters: [any LogFiltering] = [
        MinimumLevelFilter(threshold: .info),
        RedactingFilter(sensitiveKeys: ["password", "token", "authorization"]),
    ]
    let safetyHandler = StreamLogHandler.standardOutput(label: serviceLabel, filters: safetyFilters)

    Benchmark("filter_dropped_below_level", configuration: .init(scalingFactor: .kilo)) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(safetyHandler.filter(debugEvent))
        }
    }

    Benchmark("filter_passed", configuration: .init(scalingFactor: .kilo)) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(safetyHandler.filter(requestEvent))
        }
    }

    Benchmark("filter_redacted", configuration: .init(scalingFactor: .kilo)) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(safetyHandler.filter(sensitiveEvent))
        }
    }

    Benchmark("filter_empty", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let handler = StreamLogHandler.standardOutput(label: serviceLabel, filters: [])
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(handler.filter(requestEvent))
        }
    }

    Benchmark("filter_redacted_many_keys", configuration: .init(scalingFactor: .kilo)) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(safetyHandler.filter(manyKeysSensitiveEvent))
        }
    }

    Benchmark("filter_dropped_by_source", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let handler = StreamLogHandler.standardOutput(
            label: serviceLabel,
            filters: [SourceDenylistFilter(denylist: ["Cache", "HealthCheck"])]
        )
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(handler.filter(debugEvent))
        }
    }

    Benchmark("filter_truncated_long_values", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let handler = StreamLogHandler.standardOutput(
            label: serviceLabel,
            filters: [TruncatingFilter(maxCharacters: 200)]
        )
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(handler.filter(longValueEvent))
        }
    }

    Benchmark("filter_sanitization_pipeline", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let handler = StreamLogHandler.standardOutput(
            label: serviceLabel,
            filters: safetyFilters + [
                SourceDenylistFilter(denylist: ["HealthCheck", "KubeProbe", "Cache"]),
                TruncatingFilter(maxCharacters: 200),
                PrefixStrippingFilter(prefix: "internal."),
            ]
        )
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(handler.filter(sanitizationEvent))
        }
    }
}
