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

@Suite("LogFilterTests", .tags(.filtering))
struct LogFilterTests {

    @Test("LogFilter stores and exposes name")
    func logFilterStoresName() {
        let filter = LogFilter(name: "test-filter") { $0 }
        #expect(filter.name == "test-filter")
    }

    @Test("LogFilter passes event through keep closure")
    func logFilterPassesEvent() {
        let filter = LogFilter(name: "keep") { $0 }
        let event = makeEvent(message: "keep me")
        #expect(filter.filter(event)?.message.description == "keep me")
    }

    @Test("LogFilter drops event when closure returns nil")
    func logFilterDropsEvent() {
        let filter = LogFilter(name: "drop") { _ in nil }
        let event = makeEvent()
        #expect(filter.filter(event) == nil)
    }

    @Test("LogFilter closure can transform event level")
    func logFilterTransformsEvent() {
        let filter = LogFilter(name: "upgrade") { event in
            var e = event
            e.level = .critical
            return e
        }
        let event = makeEvent(level: .trace)
        let result = filter.filter(event)
        #expect(result?.level == .critical)
    }

    @Test("LogFilter is Sendable — usable across async boundaries")
    func logFilterIsSendable() async {
        let filter = LogFilter(name: "async-filter") { $0 }
        let event = makeEvent(message: "async message")
        let result = await Task { filter.filter(event) }.value
        #expect(result?.message.description == "async message")
    }
}
