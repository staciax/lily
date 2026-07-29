//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Logging

/// A type that formats a log event and its handler-owned values.
public protocol LogFormatting: Sendable {
    /// The format used by a handler to prepare timestamps.
    var dateFormat: DateFormat { get }

    /// The default metadata values used as a fallback.
    var defaults: Logger.Metadata? { get }

    /// Returns a formatted string for the supplied context.
    ///
    /// Conformers may throw only ``LogFormattingError``. Prefer returning a fallback
    /// string over throwing, since a handler drops the log line when formatting throws.
    ///
    /// - Parameter context: The formatting context containing the event and handler values.
    /// - Returns: The formatted log line.
    /// - Throws: A ``LogFormattingError`` if a formatting constraint is violated.
    func format(_ context: LogFormattingContext) throws(LogFormattingError) -> String
}

extension LogFormatting {
    /// The default format used for handler-prepared timestamps.
    public var dateFormat: DateFormat { .iso8601 }

    /// The default metadata values.
    public var defaults: Logger.Metadata? { nil }
}
