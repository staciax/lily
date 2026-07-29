//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Logging

/// A named closure-backed log filter.
public struct LogFilter: LogFiltering {
    /// The unique name identifying this filter in a handler's chain.
    public let name: String

    private let filter: @Sendable (LogEvent) -> LogEvent?

    /// Creates a filter with the specified name and filter closure.
    ///
    /// - Parameters:
    ///   - name: The filter name used as its identity in filter chains.
    ///   - filter: A closure that takes a log event and returns the (potentially
    ///     modified) event to pass along, or `nil` to drop it.
    public init(name: String, filter: @escaping @Sendable (LogEvent) -> LogEvent?) {
        self.name = name
        self.filter = filter
    }

    /// Filters the log event using the backing filter closure.
    ///
    /// - Parameter event: The log event to evaluate.
    /// - Returns: The event returned by the filter closure, or `nil` if it was dropped.
    public func filter(_ event: LogEvent) -> LogEvent? {
        self.filter(event)
    }
}
