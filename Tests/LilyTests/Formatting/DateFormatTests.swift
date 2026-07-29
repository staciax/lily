//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Lily
import Testing

@Suite("DateFormatTests", .tags(.formatting))
struct DateFormatTests {

    @Test("iso8601 rawValue is the expected strftime format string")
    func iso8601RawValue() {
        #expect(DateFormat.iso8601.rawValue == "%Y-%m-%dT%H:%M:%S%z")
    }

    @Test("string literal round-trip", arguments: ["%Y-%m-%d", "%H:%M:%S", "custom-format"])
    func stringLiteralRoundTrip(_ value: String) {
        let format: DateFormat = DateFormat(stringLiteral: value)
        #expect(format.rawValue == value)
    }

    @Test("direct init round-trip")
    func directInitRoundTrip() {
        let rawPattern: String = "%d/%m/%Y"
        let format = DateFormat(rawPattern)
        #expect(format.rawValue == rawPattern)
    }

    @Test("user preset extensibility via static property")
    func userPresetExtensibility() {
        let format: DateFormat = .appShortDate
        #expect(format.rawValue == "%Y-%m-%d")
    }

    @Test("DateFormat is Sendable — usable across async boundaries")
    func sendableAcrossAsync() async {
        let format: DateFormat = .iso8601
        let rawValue = await Task { format.rawValue }.value
        #expect(rawValue == "%Y-%m-%dT%H:%M:%S%z")
    }
}

extension DateFormat {
    /// A test-local custom preset, demonstrating user extensibility.
    fileprivate static let appShortDate: DateFormat = "%Y-%m-%d"
}
