//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Logging
import Testing

@testable import Lily

@Suite("LogHandlingTests", .tags(.handling))
struct LogHandlingTests {

    @Test("addFilter adds a filter and returns true")
    func addFilterReturnsTrue() {
        var handler = StreamLogHandler(
            label: "test",
            stream: InterceptStream(),
            filters: []
        )
        let result = handler.addFilter(KeepFilter(name: "keep"))
        #expect(result == true)
        #expect(handler.filters.count == 1)
    }

    @Test("addFilter returns false when filter with same name already exists")
    func addFilterReturnsFalseForDuplicate() {
        var handler = StreamLogHandler(
            label: "test",
            stream: InterceptStream(),
            filters: [KeepFilter(name: "keep")]
        )
        let result = handler.addFilter(KeepFilter(name: "keep"))
        #expect(result == false)
        #expect(handler.filters.count == 1)
    }

    @Test("removeFilter removes filter by name")
    func removeFilterByName() {
        var handler = StreamLogHandler(
            label: "test",
            stream: InterceptStream(),
            filters: [KeepFilter(name: "keep"), DropFilter(name: "drop")]
        )
        handler.removeFilter(KeepFilter(name: "keep"))
        #expect(handler.filters.count == 1)
        #expect(handler.filters[0].name == "drop")
    }

    @Test("removeFilter does nothing when filter not present")
    func removeFilterNoOpWhenMissing() {
        var handler = StreamLogHandler(
            label: "test",
            stream: InterceptStream(),
            filters: [KeepFilter(name: "keep")]
        )
        handler.removeFilter(KeepFilter(name: "nonexistent"))
        #expect(handler.filters.count == 1)
    }

    @Test("filter chain passes event through multiple keep filters")
    func filterChainPassesEventThroughKeepFilters() {
        let handler = StreamLogHandler(
            label: "test",
            stream: InterceptStream(),
            filters: [KeepFilter(name: "k1"), KeepFilter(name: "k2")]
        )
        let event = makeEvent(message: "pass through")
        let result = handler.filter(event)
        #expect(result?.message.description == "pass through")
    }

    @Test("filter chain drops event when any filter returns nil")
    func filterChainDropsEventWhenAnyFilterDrops() {
        let handler = StreamLogHandler(
            label: "test",
            stream: InterceptStream(),
            filters: [KeepFilter(name: "k1"), DropFilter(name: "drop"), KeepFilter(name: "k2")]
        )
        let event = makeEvent()
        let result = handler.filter(event)
        #expect(result == nil)
    }

    @Test("filter chain with no filters passes event through")
    func filterChainEmptyPassesEvent() {
        let handler = StreamLogHandler(
            label: "test",
            stream: InterceptStream(),
            filters: []
        )
        let event = makeEvent(message: "unchanged")
        let result = handler.filter(event)
        #expect(result?.message.description == "unchanged")
    }
}
