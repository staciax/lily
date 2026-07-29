//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Lily
import Logging

struct FixedFormatter: LogFormatting {
    let fixed: String
    let dateFormat: DateFormat
    let defaults: Logger.Metadata?

    init(_ fixed: String, dateFormat: DateFormat = .iso8601, defaults: Logger.Metadata? = nil) {
        self.fixed = fixed
        self.dateFormat = dateFormat
        self.defaults = defaults
    }

    func format(_ context: LogFormattingContext) throws(LogFormattingError) -> String {
        fixed
    }
}

struct ThrowingFormatter: LogFormatting {
    let dateFormat: DateFormat = .iso8601
    let defaults: Logger.Metadata? = nil

    func format(_ context: LogFormattingContext) throws(LogFormattingError) -> String {
        throw LogFormattingError.missingMetadataValue(key: "test")
    }
}
