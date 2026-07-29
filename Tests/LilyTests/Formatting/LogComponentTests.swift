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

@Suite("LogComponentTests", .tags(.formatting))
struct LogComponentTests {

    @Test("string literal creates a literal component")
    func stringLiteralCreatesLiteral() throws {
        let component: LogComponent = "hello"
        let formatter = LogFormatter([component])
        let context = makeContext(formatter: formatter)
        let result = try formatter.format(context)
        #expect(result == "hello")
    }

    @Test(".literal() creates a literal component")
    func literalFactoryCreatesLiteral() throws {
        let component = LogComponent.literal("world")
        let formatter = LogFormatter([component])
        let context = makeContext(formatter: formatter)
        let result = try formatter.format(context)
        #expect(result == "world")
    }

    @Test("string literal inference works inside .group")
    func stringLiteralInferenceInGroup() throws {
        let group = LogComponent.group(["[", .source, "]"])
        let formatter = LogFormatter([group])
        let event = makeEvent(source: "MyModule")
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == "[MyModule]")
    }

    @Test("all built-in field static vars compile and render")
    func allBuiltInFieldVarsCompile() throws {
        let components: [LogComponent] = [
            .timestamp, .level, .label, .message,
            .metadata, .source, .file, .function, .line,
        ]
        let formatter = LogFormatter(components)
        let event = makeEvent(level: .debug, message: "msg", source: "src")
        let context = makeContext(formatter: formatter, label: "lbl", event: event, timestamp: "T")
        let result = try formatter.format(context)
        #expect(result.contains("T"))
        #expect(result.contains("debug"))
        #expect(result.contains("lbl"))
        #expect(result.contains("msg"))
        #expect(result.contains("src"))
    }

    @Test("all formattedBy factories compile")
    func allFormattedByFactoriesCompile() {
        let _ = LogComponent.timestamp(formattedBy: { r, _ in r() })
        let _ = LogComponent.level(formattedBy: { r, _ in r() })
        let _ = LogComponent.label(formattedBy: { r, _ in r() })
        let _ = LogComponent.message(formattedBy: { r, _ in r() })
        let _ = LogComponent.metadata(formattedBy: { r, _, _ in r() })
        let _ = LogComponent.metadata(including: ["k"], formattedBy: { r, _, _ in r() })
        let _ = LogComponent.metadata(excluding: ["k"], formattedBy: { r, _, _ in r() })
        let _ = LogComponent.metadata(key: "k", formattedBy: { r, _, _ in r() })
        let _ = LogComponent.source(formattedBy: { r, _ in r() })
        let _ = LogComponent.file(formattedBy: { r, _ in r() })
        let _ = LogComponent.function(formattedBy: { r, _ in r() })
        let _ = LogComponent.line(formattedBy: { r, _ in r() })
    }
}
