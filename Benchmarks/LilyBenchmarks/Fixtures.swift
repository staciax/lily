//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Lily
import Logging

/// The reverse-DNS logger label a backend service would use.
let serviceLabel = "com.example.api.RequestLogger"

/// A lifecycle/infra log without metadata.
let lifecycleEvent = LogEvent(
    level: .notice,
    message: "http server started on :8080",
    metadata: nil,
    source: "Server",
    file: "Server.swift",
    function: "start()",
    line: 1
)

/// The dominant app log: a completed request with rich, mixed-type metadata and no secrets.
let requestEvent = LogEvent(
    level: .info,
    message: "completed request",
    metadata: [
        "request-id": "01J9Z3K8P2QX9V",
        "method": "GET",
        "path": "/v1/users/42",
        "status": .stringConvertible(200),
        "duration-ms": .stringConvertible(13.4),
        "user-id": .stringConvertible(4242),
    ],
    source: "RequestLogger",
    file: "RequestLogger.swift",
    function: "log(_:)",
    line: 1
)

/// A high-frequency debug log that a production min-level filter drops.
let debugEvent = LogEvent(
    level: .debug,
    message: "cache lookup",
    metadata: [
        "key": "user:42",
        "hit": .stringConvertible(true),
    ],
    source: "Cache",
    file: "Cache.swift",
    function: "get(_:)",
    line: 1
)

/// An auth-path log carrying sensitive metadata to be redacted.
let sensitiveEvent = LogEvent(
    level: .warning,
    message: "authentication retry",
    metadata: [
        "request-id": "01J9Z3K8P2QX9V",
        "user-id": .stringConvertible(4242),
        "authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
        "token": "token_abc123",
    ],
    source: "Auth",
    file: "Auth.swift",
    function: "authenticate()",
    line: 1
)

/// A log event carrying extremely short metadata values to test buffer capacity reservation.
/// Note on Malloc Anomaly: Unlike `requestEvent` (which uses `.stringConvertible(Int/Double)`
/// and incurs boxing/interpolation overhead in unoptimized code), all values here are pure `.string`
/// literals. Consequently, baseline unoptimized formatting required fewer heap allocations (18 Mallocs)
/// despite having more total keys (15 keys vs 11 keys in standard request logging).
let shortValueEvent = LogEvent(
    level: .info,
    message: "short metadata event",
    metadata: [
        "k01": "1", "k02": "2", "k03": "3", "k04": "4", "k05": "5",
        "k06": "6", "k07": "7", "k08": "8", "k09": "9", "k10": "0",
    ],
    source: "EdgeCaseLogger",
    file: "EdgeCase.swift",
    function: "testShort()",
    line: 1
)

/// A log event carrying large repeating strings that exceed estimated buffer capacity.
let longValueEvent: LogEvent = {
    let val100 = String(repeating: "A", count: 100)
    let val250 = String(repeating: "B", count: 250)
    let val500 = String(repeating: "C", count: 500)
    return LogEvent(
        level: .error,
        message: "long metadata event",
        metadata: [
            "payload.small": .string(val100),
            "payload.medium": .string(val250),
            "payload.large": .string(val500),
        ],
        source: "EdgeCaseLogger",
        file: "EdgeCase.swift",
        function: "testLong()",
        line: 1
    )
}()

/// A log event carrying a high metadata key count to test dictionary lookup and sorting.
let manyKeysEvent: LogEvent = {
    var meta: Logger.Metadata = [:]
    for i in 1...30 {
        let key = String(format: "param_%02d", i)
        let value = String(repeating: "x", count: 10)
        meta[key] = .string(value)
    }
    return LogEvent(
        level: .debug,
        message: "many keys event",
        metadata: meta,
        source: "EdgeCaseLogger",
        file: "EdgeCase.swift",
        function: "testMany()",
        line: 1
    )
}()

/// A log event carrying 30+ metadata keys alongside sensitive tokens to test redaction COW scaling.
let manyKeysSensitiveEvent: LogEvent = {
    var meta: Logger.Metadata = [
        "authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
        "token": "token_abc123",
        "request-id": "01J9Z3K8P2QX9V",
        "user-id": .stringConvertible(4242),
    ]
    for i in 1...30 {
        let key = String(format: "param_%02d", i)
        meta[key] = .string(String(repeating: "v", count: 10))
    }
    return LogEvent(
        level: .warning,
        message: "large sensitive event",
        metadata: meta,
        source: "AuthService",
        file: "AuthService.swift",
        function: "authenticate()",
        line: 100
    )
}()

/// A log event exercising every filter in the sanitization pipeline:
/// passes the level gate, carries sensitive keys for redaction, includes
/// a value exceeding 200 chars for truncation, and has an "internal."-
/// prefixed key for prefix stripping.
let sanitizationEvent: LogEvent = {
    let longPayload = String(repeating: "X", count: 300)
    return LogEvent(
        level: .info,
        message: "sanitized request",
        metadata: [
            "request-id": "01J9Z3K8P2QX9V",
            "method": "POST",
            "path": "/v1/orders",
            "status": .stringConvertible(201),
            "authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
            "token": "token_abc123",
            "payload": .string(longPayload),
            "internal.traceId": "abc-def-123",
        ],
        source: "RequestLogger",
        file: "RequestLogger.swift",
        function: "log(_:)",
        line: 1
    )
}()

/// Builds a formatting context with a fixed timestamp, so the formatter does pure
/// string assembly.
func context(
    for event: LogEvent,
    formatter: any LogFormatting,
    supportsColor: Bool = false
) -> LogFormattingContext {
    LogFormattingContext(
        formatter: formatter,
        label: serviceLabel,
        event: event,
        timestamp: "2026-06-15T09:00:00+0000",
        supportsColor: supportsColor
    )
}
