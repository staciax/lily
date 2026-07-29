//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Logging

/// The event and handler-owned values supplied to a log formatter.
public struct LogFormattingContext: Sendable {
    /// The active formatter instance, exposing `defaults` to field-formatter closures.
    ///
    /// - Warning: Read `formatter.defaults` only. Do not call
    ///   `context.formatter.format(_:)` from inside a formatter closure — that
    ///   re-enters the formatter and recurses indefinitely.
    public let formatter: any LogFormatting

    /// The logger label owned by the handler.
    public let label: String

    /// The filtered log event containing fully resolved effective metadata.
    public let event: LogEvent

    /// The timestamp string prepared by the handler.
    public let timestamp: String

    /// Whether the output destination supports ANSI color escape sequences.
    public let supportsColor: Bool

    /// Creates a formatting context.
    ///
    /// - Parameters:
    ///   - formatter: The active formatter instance.
    ///   - label: The logger label owned by the handler.
    ///   - event: The filtered event containing resolved effective metadata.
    ///   - timestamp: The timestamp string prepared by the handler.
    ///   - supportsColor: Whether the destination supports ANSI color.
    public init(
        formatter: any LogFormatting,
        label: String,
        event: LogEvent,
        timestamp: String,
        supportsColor: Bool
    ) {
        self.formatter = formatter
        self.label = label
        self.event = event
        self.timestamp = timestamp
        self.supportsColor = supportsColor
    }
}
