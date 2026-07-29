//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Logging

/// A type that specifies the format for timestamps in log messages.
public struct DateFormat: ExpressibleByStringLiteral, Equatable, Sendable {
    /// The raw `strftime` format string.
    public let rawValue: String

    /// Creates a custom date format from a string literal.
    ///
    /// - Parameter value: A POSIX-compliant `strftime` format string.
    public init(stringLiteral value: String) { self.rawValue = value }

    /// Creates a custom date format.
    ///
    /// - Parameter rawValue: A POSIX-compliant `strftime` format string.
    public init(_ rawValue: String) { self.rawValue = rawValue }

    /// ISO 8601 format (e.g., "2026-06-12T15:40:00+0700").
    public static let iso8601: DateFormat = "%Y-%m-%dT%H:%M:%S%z"
}
