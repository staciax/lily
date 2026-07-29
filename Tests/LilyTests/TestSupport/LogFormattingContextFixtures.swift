//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Lily
import Logging

func makeContext(
    formatter: any LogFormatting = LogFormatter([]),
    label: String = "test.label",
    event: LogEvent? = nil,
    timestamp: String = "2026-06-14T00:00:00+0000",
    supportsColor: Bool = false
) -> LogFormattingContext {
    LogFormattingContext(
        formatter: formatter,
        label: label,
        event: event ?? makeEvent(),
        timestamp: timestamp,
        supportsColor: supportsColor
    )
}
