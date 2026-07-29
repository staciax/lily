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

@Suite("FieldFormattingTests", .tags(.formatting))
struct FieldFormattingTests {

    struct FieldCase: CustomTestStringConvertible {
        let component: LogComponent
        let context: LogFormattingContext
        let expected: String
        var testDescription: String { "expected='\(expected)'" }
    }

    @Test(
        "field formattedBy renders the field's default value",
        arguments: [
            FieldCase(
                component: .timestamp(formattedBy: { r, _ in "v:\(r())" }),
                context: makeContext(timestamp: "2026-01-01T00:00:00+0000"),
                expected: "v:2026-01-01T00:00:00+0000"
            ),
            FieldCase(
                component: .level(formattedBy: { r, _ in "v:\(r())" }),
                context: makeContext(event: makeEvent(level: .warning)),
                expected: "v:warning"
            ),
            FieldCase(
                component: .label(formattedBy: { r, _ in "v:\(r())" }),
                context: makeContext(label: "my.service"),
                expected: "v:my.service"
            ),
            FieldCase(
                component: .message(formattedBy: { r, _ in "v:\(r())" }),
                context: makeContext(event: makeEvent(message: "hello world")),
                expected: "v:hello world"
            ),
            FieldCase(
                component: .source(formattedBy: { r, _ in "v:\(r())" }),
                context: makeContext(event: makeEvent(source: "Module")),
                expected: "v:Module"
            ),
            FieldCase(
                component: .file(formattedBy: { r, _ in "v:\(r())" }),
                context: makeContext(event: makeEvent(file: "main.swift")),
                expected: "v:main.swift"
            ),
            FieldCase(
                component: .function(formattedBy: { r, _ in "v:\(r())" }),
                context: makeContext(event: makeEvent(function: "run()")),
                expected: "v:run()"
            ),
            FieldCase(
                component: .line(formattedBy: { r, _ in "v:\(r())" }),
                context: makeContext(event: makeEvent(line: 42)),
                expected: "v:42"
            ),
        ]
    )
    func fieldFormattedBy(_ field: FieldCase) throws {
        #expect(try LogFormatter([field.component]).format(field.context) == field.expected)
    }

    @Test("formattedBy closure receives context with supportsColor")
    func formattedByReceivesContext() throws {
        let capture = BoolBox()
        let formatter = LogFormatter([
            .message(formattedBy: { render, ctx in
                capture.value = ctx.supportsColor
                return render()
            })
        ])
        let context = makeContext(formatter: formatter, supportsColor: true)
        _ = try formatter.format(context)
        #expect(capture.value == true)
    }

    @Test("metadata formattedBy receives namedKeys set and rendered value")
    func metadataFormattedByReceivesNamedKeys() throws {
        let capture = SetBox()
        let formatter = LogFormatter([
            .metadata(
                including: ["a", "b"],
                formattedBy: { render, _, namedKeys in
                    capture.value = namedKeys
                    return render()
                }
            )
        ])
        let event = makeEvent(metadata: ["a": "1", "b": "2"])
        let context = makeContext(formatter: formatter, event: event)
        _ = try formatter.format(context)
        #expect(capture.value == ["a", "b"])
    }

    @Test("metadata key formattedBy receives key and rendered value")
    func metadataKeyFormattedByReceivesKey() throws {
        let capture = StringBox()
        let formatter = LogFormatter([
            .metadata(
                key: "env",
                formattedBy: { render, _, key in
                    capture.value = key
                    return render()
                }
            )
        ])
        let event = makeEvent(metadata: ["env": "prod"])
        let context = makeContext(formatter: formatter, event: event)
        _ = try formatter.format(context)
        #expect(capture.value == "env")
    }
}

private final class StringBox: @unchecked Sendable {
    var value: String = ""
}

private final class BoolBox: @unchecked Sendable {
    var value: Bool = false
}

private final class SetBox: @unchecked Sendable {
    var value: Set<String> = []
}
