//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Lily
import Logging

struct KeepFilter: LogFiltering {
    let name: String
    func filter(_ event: LogEvent) -> LogEvent? { event }
}

struct DropFilter: LogFiltering {
    let name: String
    func filter(_ event: LogEvent) -> LogEvent? { nil }
}
