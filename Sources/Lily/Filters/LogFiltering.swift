//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Logging

/// A type that can keep, replace, or drop log events.
public protocol LogFiltering: Sendable {
    /// The filter name, which also serves as its identity in a handler's chain.
    var name: String { get }

    /// Returns the event to continue with, or `nil` to drop it.
    ///
    /// - Parameter event: The log event to evaluate.
    /// - Returns: The event to pass to the next filter, or `nil` if it should be dropped.
    func filter(_ event: LogEvent) -> LogEvent?
}
