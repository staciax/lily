//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Lily
import Logging
import Testing

@Suite("LogFilteringTests", .tags(.filtering))
struct LogFilteringTests {

    @Test("KeepFilter passes the event through unchanged")
    func keepFilterPassesEvent() {
        let filter = KeepFilter(name: "keep")
        let event = makeEvent(message: "original")
        let result = filter.filter(event)
        #expect(result?.message.description == "original")
    }

    @Test("DropFilter always returns nil")
    func dropFilterReturnsNil() {
        let filter = DropFilter(name: "drop")
        let event = makeEvent()
        let result = filter.filter(event)
        #expect(result == nil)
    }

    @Test("filter protocol requires a name property")
    func filterHasNameProperty() {
        let filter: any LogFiltering = KeepFilter(name: "my-filter")
        #expect(filter.name == "my-filter")
    }

    @Test("custom filter can modify the event")
    func customFilterModifiesEvent() {
        let filter = LogFilter(name: "level-upgrade") { event in
            var modified = event
            modified.level = .error
            return modified
        }
        let event = makeEvent(level: .info)
        let result = filter.filter(event)
        #expect(result?.level == .error)
    }
}
