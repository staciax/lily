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

/// A production console formatter: the standard layout, with the level colored by severity.
private let consoleFormatter = LogFormatter([
    .timestamp,
    " ",
    .level { render, ctx in
        guard ctx.supportsColor else { return render() }
        let code =
            switch ctx.event.level {
            case .critical, .error: "31"  // red
            case .warning: "33"  // yellow
            case .notice, .info: "32"  // green
            default: "90"  // bright black (trace/debug)
            }
        return "\u{1B}[\(code)m\(render())\u{1B}[0m"
    },
    .when({ !$0.label.isEmpty }, then: [" ", .label]),
    ":",
    .when({ $0.event.metadata?.isEmpty == false }, then: [" ", .metadata]),
    " ",
    .group(["[", .source, "]"]),
    " ",
    .message,
])

/// A production formatter with OpenTelemetry resource attributes bound to every log event.
private let defaultsFormatter = LogFormatter(
    [
        .timestamp,
        " ",
        .group(["[", .level, "]"]),
        " ",
        .group([.label, "/", .source]),
        ": ",
        .message,
        " | ",
        .metadata,
    ],
    defaults: [
        "service.name": "api-gateway",
        "deployment.environment.name": "production",
        "cloud.region": "ap-southeast-1",
        "service.version": "1.2.7",
        "service.instance.id": "019f98fc-123c-7786-81a8-a390eab25d9b",
    ]
)

/// A production formatter testing the `.excluding` filter path on merged metadata.
private let excludingFormatter = LogFormatter(
    [
        .timestamp,
        " ",
        .group(["[", .level, "]"]),
        " ",
        .group([.label, "/", .source]),
        ": ",
        .message,
        " | ",
        .metadata(excluding: ["service.name", "request-id", "param_01", "param_02"]),
    ],
    defaults: [
        "service.name": "api-gateway",
        "deployment.environment.name": "production",
        "cloud.region": "ap-southeast-1",
        "service.version": "1.2.7",
        "service.instance.id": "019f98fc-123c-7786-81a8-a390eab25d9b",
    ]
)

func formattingBenchmarks() {
    Benchmark("format_lifecycle", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let context = context(for: lifecycleEvent, formatter: LogFormatter.standard)
        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            blackHole(try! LogFormatter.standard.format(context))
        }
    }

    Benchmark("format_request", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let context = context(for: requestEvent, formatter: LogFormatter.standard)
        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            blackHole(try! LogFormatter.standard.format(context))
        }
    }

    Benchmark("format_request_colored", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let context = context(for: requestEvent, formatter: consoleFormatter, supportsColor: true)
        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            blackHole(try! consoleFormatter.format(context))
        }
    }

    Benchmark("format_defaults_empty_event", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let context = context(for: lifecycleEvent, formatter: defaultsFormatter)
        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            blackHole(try! defaultsFormatter.format(context))
        }
    }

    Benchmark("format_defaults_with_event", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let context = context(for: requestEvent, formatter: defaultsFormatter)
        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            blackHole(try! defaultsFormatter.format(context))
        }
    }

    Benchmark("format_defaults_with_event_short", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let context = context(for: shortValueEvent, formatter: defaultsFormatter)
        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            blackHole(try! defaultsFormatter.format(context))
        }
    }

    Benchmark("format_defaults_with_event_long", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let context = context(for: longValueEvent, formatter: defaultsFormatter)
        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            blackHole(try! defaultsFormatter.format(context))
        }
    }

    Benchmark("format_defaults_with_event_many_keys", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let context = context(for: manyKeysEvent, formatter: defaultsFormatter)
        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            blackHole(try! defaultsFormatter.format(context))
        }
    }

    Benchmark("format_defaults_with_event_excluding", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let context = context(for: requestEvent, formatter: excludingFormatter)
        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            blackHole(try! excludingFormatter.format(context))
        }
    }

    Benchmark("format_defaults_with_event_many_keys_excluding", configuration: .init(scalingFactor: .kilo)) {
        benchmark in
        let context = context(for: manyKeysEvent, formatter: excludingFormatter)
        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            blackHole(try! excludingFormatter.format(context))
        }
    }
}
