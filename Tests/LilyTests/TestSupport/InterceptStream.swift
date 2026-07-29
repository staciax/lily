//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

final class InterceptStream: TextOutputStream, @unchecked Sendable {
    private var lock = NSLock()
    private(set) var output: [String] = []

    func write(_ string: String) {
        lock.withLock { output.append(string) }
    }

    var combined: String {
        lock.withLock { output.joined() }
    }
}
