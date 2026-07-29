//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

/// An error that can occur while formatting a log event.
public enum LogFormattingError: Error, Sendable, Equatable {
    /// A required metadata value is missing from metadata.
    ///
    /// - Parameter key: The key of the missing metadata value.
    case missingMetadataValue(key: String)
}
