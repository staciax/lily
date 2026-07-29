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

@Suite("LogFormatterTests", .tags(.formatting))
struct LogFormatterTests {

    // 1. initialization

    @Test("dateFormat defaults to .iso8601")
    func dateFormatDefaultsToISO8601() {
        let formatter = LogFormatter([])
        #expect(formatter.dateFormat.rawValue == DateFormat.iso8601.rawValue)
    }

    @Test("explicit dateFormat is stored")
    func explicitDateFormatStored() {
        let custom: DateFormat = "%d/%m/%Y"
        let formatter = LogFormatter([], dateFormat: custom)
        #expect(formatter.dateFormat.rawValue == "%d/%m/%Y")
    }

    @Test("defaults is nil when not provided")
    func defaultsNilWhenOmitted() {
        let formatter = LogFormatter([])
        #expect(formatter.defaults == nil)
    }

    @Test("defaults property is exposed")
    func defaultsPropertyExposed() {
        let meta: Logger.Metadata = ["env": "test"]
        let formatter = LogFormatter([], defaults: meta)
        #expect(formatter.defaults == meta)
    }

    @Test("components count is accessible")
    func componentsCountAccessible() {
        let formatter = LogFormatter([.timestamp, " ", .message])
        #expect(formatter.components.count == 3)
    }

    // MARK: - Protocol

    @Test("formats through any LogFormatting protocol")
    func formatsThroughProtocol() throws {
        let formatter: any LogFormatting = LogFormatter([.message])
        let event = makeEvent(message: "hello protocol")
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == "hello protocol")
    }

    @Test("LogFormatting protocol extension default properties return expected fallbacks")
    func logFormattingProtocolExtensionDefaults() {
        struct Formatter: LogFormatting {
            func format(_ context: LogFormattingContext) throws(LogFormattingError) -> String { "" }
        }
        let formatter = Formatter()
        #expect(formatter.dateFormat == .iso8601)
        #expect(formatter.defaults == nil)
    }

    // 2. error

    @Test("LogFormattingError.missingMetadataValue is Equatable")
    func formattingErrorIsEquatable() {
        let e1 = LogFormattingError.missingMetadataValue(key: "a")
        let e2 = LogFormattingError.missingMetadataValue(key: "a")
        let e3 = LogFormattingError.missingMetadataValue(key: "b")
        #expect(e1 == e2)
        #expect(e1 != e3)
    }

    // 3. standard

    @Test("empty formatter renders empty string")
    func emptyFormatterRendersEmpty() throws {
        let formatter = LogFormatter([])
        let context = makeContext(formatter: formatter)
        let result = try formatter.format(context)
        #expect(result == "")
    }

    @Test("components render in order")
    func componentsRenderInOrder() throws {
        let formatter = LogFormatter(["a", "b", "c"])
        let context = makeContext(formatter: formatter)
        let result = try formatter.format(context)
        #expect(result == "abc")
    }

    @Test("LogFormatter.standard exists and contains expected fields")
    func standardFormatterExists() throws {
        let formatter = LogFormatter.standard
        let event = makeEvent(level: .info, message: "hello", source: "MySource")
        let context = makeContext(
            formatter: formatter,
            label: "my.label",
            event: event,
            timestamp: "2026-01-01T00:00:00+0000",
        )
        let result = try formatter.format(context)
        #expect(result.contains("2026-01-01T00:00:00+0000"))
        #expect(result.contains("info"))
        #expect(result.contains("my.label"))
        #expect(result.contains("[MySource]"))
        #expect(result.contains("hello"))
    }

    @Test("LogFormatter.standard does not include a trailing newline")
    func standardFormatterNoNewline() throws {
        let formatter = LogFormatter.standard
        let event = makeEvent(level: .info, message: "msg", source: "S")
        let context = makeContext(formatter: formatter, label: "", event: event, timestamp: "T")
        let result = try formatter.format(context)
        #expect(!result.hasSuffix("\n"))
    }

    @Test("LogFormatter.standard with empty message preserves trailing space after source")
    func standardFormatterEmptyMessageTrailingSpace() throws {
        let formatter = LogFormatter.standard
        let event = makeEvent(level: .info, message: "", source: "Src")
        let context = makeContext(formatter: formatter, label: "", event: event, timestamp: "T")
        let result = try formatter.format(context)
        #expect(result == "T info: [Src] ")
    }

    struct StandardCase: CustomTestStringConvertible {
        let label: String
        let metadata: Logger.Metadata?
        let expected: String
        var testDescription: String { "label='\(label)' metadata=\(metadata.map { "\($0)" } ?? "nil")" }
    }

    @Test(
        "LogFormatter.standard label/metadata combinations",
        arguments: [
            StandardCase(label: "", metadata: nil, expected: "T info: [Src] msg"),
            StandardCase(label: "", metadata: [:], expected: "T info: [Src] msg"),
            StandardCase(label: "com.example", metadata: nil, expected: "T info com.example: [Src] msg"),
            StandardCase(label: "", metadata: ["k": "v"], expected: "T info: k=v [Src] msg"),
            StandardCase(label: "com.example", metadata: ["k": "v"], expected: "T info com.example: k=v [Src] msg"),
        ]
    )
    func standardFormatterCombinations(_ c: StandardCase) throws {
        let formatter = LogFormatter.standard
        let event = makeEvent(level: .info, message: "msg", metadata: c.metadata, source: "Src")
        let context = makeContext(formatter: formatter, label: c.label, event: event, timestamp: "T")
        let result = try formatter.format(context)
        #expect(result == c.expected)
    }

    // 3. composition

    @Test(".group renders all children in sequence")
    func groupRendersAllChildren() throws {
        let formatter = LogFormatter([.group(["[", .source, "]"])])
        let event = makeEvent(source: "MyModule")
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == "[MyModule]")
    }

    @Test(".group with empty array renders empty string")
    func groupEmptyRendersEmpty() throws {
        let formatter = LogFormatter([.group([])])
        let context = makeContext(formatter: formatter)
        let result = try formatter.format(context)
        #expect(result == "")
    }

    @Test(".joined skips empty components")
    func joinedSkipsEmpty() throws {
        let formatter = LogFormatter([
            .joined([.metadata, .message], separator: " | ")
        ])
        // no metadata → metadata component renders empty → only message
        let event = makeEvent(message: "hello", metadata: nil)
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == "hello")
    }

    @Test(".joined separates non-empty components")
    func joinedSeparatesNonEmpty() throws {
        let formatter = LogFormatter([
            .joined(["a", "b", "c"], separator: "-")
        ])
        let context = makeContext(formatter: formatter)
        let result = try formatter.format(context)
        #expect(result == "a-b-c")
    }

    @Test(".joined with all empty renders empty string")
    func joinedAllEmptyRendersEmpty() throws {
        let formatter = LogFormatter([.joined([.metadata], separator: ", ")])
        let event = makeEvent(metadata: nil)
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == "")
    }

    @Test(".when renders children when predicate is true")
    func whenPredicateTrueRenders() throws {
        let formatter = LogFormatter([.when({ _ in true }, then: ["visible"])])
        let context = makeContext(formatter: formatter)
        let result = try formatter.format(context)
        #expect(result == "visible")
    }

    @Test(".when renders empty string when predicate is false")
    func whenPredicateFalseRendersEmpty() throws {
        let formatter = LogFormatter([.when({ _ in false }, then: ["invisible"])])
        let context = makeContext(formatter: formatter)
        let result = try formatter.format(context)
        #expect(result == "")
    }

    @Test(".when predicate receives correct context")
    func whenPredicateReceivesContext() throws {
        let capture = LabelCapture()
        let formatter = LogFormatter([
            .when(
                { context in
                    capture.label = context.label
                    return true
                },
                then: ["x"]
            )
        ])
        let context = makeContext(formatter: formatter, label: "my.label")
        _ = try formatter.format(context)
        #expect(capture.label == "my.label")
    }

    @Test(".when with non-empty label renders label suffix")
    func whenNonEmptyLabelRendersLabelSuffix() throws {
        let formatter = LogFormatter([
            .level,
            .when({ !$0.label.isEmpty }, then: [" ", .label]),
        ])
        let event = makeEvent(level: .info)
        let context = makeContext(formatter: formatter, label: "svc", event: event)
        let result = try formatter.format(context)
        #expect(result == "info svc")
    }

    @Test(".when with empty label skips label suffix")
    func whenEmptyLabelSkipsLabelSuffix() throws {
        let formatter = LogFormatter([
            .level,
            .when({ !$0.label.isEmpty }, then: [" ", .label]),
        ])
        let event = makeEvent(level: .info)
        let context = makeContext(formatter: formatter, label: "", event: event)
        let result = try formatter.format(context)
        #expect(result == "info")
    }

    @Test(".when with empty then renders empty string when predicate is true")
    func whenTrueEmptyChildrenRendersEmpty() throws {
        let formatter = LogFormatter([.when({ _ in true }, then: [])])
        let context = makeContext(formatter: formatter)
        let result = try formatter.format(context)
        #expect(result == "")
    }

    @Test(".when with false predicate and missing metadata key does not throw")
    func whenFalsePredicateSkipsMissingKey() throws {
        let formatter = LogFormatter([.when({ _ in false }, then: [.metadata(key: "missing")])])
        let event = makeEvent(metadata: nil)
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == "")
    }

    @Test(".when with true predicate propagates missing metadata key error")
    func whenTruePredicatePropagatesError() {
        let formatter = LogFormatter([.when({ _ in true }, then: [.metadata(key: "missing")])])
        let event = makeEvent(metadata: nil)
        let context = makeContext(formatter: formatter, event: event)
        #expect(throws: LogFormattingError.missingMetadataValue(key: "missing")) {
            try formatter.format(context)
        }
    }

    @Test(".joined treats a nested .group as a single child")
    func joinedTreatsNestedGroupAsSingleChild() throws {
        let formatter = LogFormatter([
            .joined([.group(["[", .level, "]"]), .message], separator: " | ")
        ])
        let event = makeEvent(level: .info, message: "msg")
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == "[info] | msg")
    }

    @Test(".joined skips a nested .group whose rendered output is empty")
    func joinedSkipsNestedGroupWithEmptyOutput() throws {
        let formatter = LogFormatter([
            .joined([.group([.metadata]), .message], separator: " | ")
        ])
        let event = makeEvent(message: "message", metadata: nil)
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == "message")
    }

    @Test(".joined keeps a nested .group whose rendered output is non-empty")
    func joinedKeepsNestedGroupWithNonEmptyOutput() throws {
        let formatter = LogFormatter([
            .joined([.group(["[", .level, "] "]), .message], separator: " | ")
        ])
        let event = makeEvent(level: .info, message: "message")
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == "[info]  | message")
    }

    // 4. metadata

    @Test("metadata key renders single value")
    func metadataKeyRendersSingleValue() throws {
        let formatter = LogFormatter([.metadata(key: "env")])
        let event = makeEvent(metadata: ["env": "production"])
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == "production")
    }

    @Test("defaults are used when event metadata has no value for key")
    func defaultsUsedWhenEventMetadataMissingKey() throws {
        let defaults: Logger.Metadata = ["env": "staging"]
        let formatter = LogFormatter([.metadata(key: "env")], defaults: defaults)
        let event = makeEvent(metadata: nil)
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == "staging")
    }

    @Test("event metadata takes precedence over defaults")
    func eventMetadataOverridesDefaults() throws {
        let defaults: Logger.Metadata = ["env": "staging"]
        let formatter = LogFormatter([.metadata(key: "env")], defaults: defaults)
        let event = makeEvent(metadata: ["env": "production"])
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == "production")
    }

    @Test("metadata key throws when missing")
    func metadataKeyThrowsWhenMissing() {
        let formatter = LogFormatter([.metadata(key: "missing")])
        let event = makeEvent(metadata: nil)
        let context = makeContext(formatter: formatter, event: event)
        #expect(throws: LogFormattingError.missingMetadataValue(key: "missing")) {
            try formatter.format(context)
        }
    }

    @Test("metadata key formattedBy throws when key is missing and closure is not called")
    func metadataKeyFormattedByThrowsWhenMissing() {
        let closureCalled = ClosureCalledBox()
        let formatter = LogFormatter([
            .metadata(
                key: "missing",
                formattedBy: { render, _, _ in
                    closureCalled.value = true
                    return render()
                }
            )
        ])
        let event = makeEvent(metadata: nil)
        let context = makeContext(formatter: formatter, event: event)
        #expect(throws: LogFormattingError.missingMetadataValue(key: "missing")) {
            try formatter.format(context)
        }
        #expect(closureCalled.value == false)
    }

    @Test("rendering one metadata key does not remove it from a later .metadata component")
    func metadataKeyDoesNotConsumeFromFullMetadata() throws {
        let formatter = LogFormatter([
            .metadata(key: "env"),
            " | ",
            .metadata,
        ])
        let event = makeEvent(metadata: ["env": "production"])
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == "production | env=production")
    }

    @Test("formatter defaults do not affect non-metadata fields")
    func defaultsDoNotAffectNonMetadataFields() throws {
        let defaults: Logger.Metadata = ["level": "default"]
        let formatter = LogFormatter([.level, " ", .message], defaults: defaults)
        let event = makeEvent(level: .warning, message: "message")
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == "warning message")
    }

    @Test(
        "metadata .all selection merges and sorts keys across defaults and event metadata",
        arguments: [
            (nil as Logger.Metadata?, nil as Logger.Metadata?, ""),
            ([:], [:], ""),
            ([:], ["b": "2", "a": "1", "c": "3"], "a=1 b=2 c=3"),
            (["a": "1", "b": "2"], nil, "a=1 b=2"),
            (["a": "1", "b": "2"], [:], "a=1 b=2"),
            (
                ["default_key": "default_value", "a": "1"], ["event_key": "event_value", "b": "2"],
                "a=1 b=2 default_key=default_value event_key=event_value"
            ),
            (
                ["a": "default_value", "b": "2", "c": "3"], ["a": "event_value", "b": "20", "d": "4"],
                "a=event_value b=20 c=3 d=4"
            ),
        ] as [(Logger.Metadata?, Logger.Metadata?, String)]
    )
    func allSelectionFormatting(
        defaults: Logger.Metadata?,
        eventMetadata: Logger.Metadata?,
        expected: String
    ) throws {
        let formatter = LogFormatter([.metadata], defaults: defaults)
        let event = makeEvent(metadata: eventMetadata)
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == expected)
    }

    @Test(
        "metadata .including selection resolves specified keys from defaults and event metadata",
        arguments: [
            (
                ["b", "a"], nil as Logger.Metadata?, ["a": "1", "b": "2", "c": "3"] as Logger.Metadata?,
                "a=1 b=2"
            ),
            (["a", "c"], ["a": "1", "b": "2", "c": "3"], nil, "a=1 c=3"),
            (["b", "a"], ["b": "1", "c": "3"], ["a": "2"], "a=2 b=1"),
            ([], nil, ["a": "1", "b": "2"], ""),
            (["a"], ["a": "default_value"], ["a": "event_value"], "a=event_value"),
            (["a"], ["a": "1", "b": "2"], ["c": "3"], "a=1"),
        ] as [([String], Logger.Metadata?, Logger.Metadata?, String)]
    )
    func includingSelectionFormatting(
        includingKeys: [String],
        defaults: Logger.Metadata?,
        eventMetadata: Logger.Metadata?,
        expected: String
    ) throws {
        let formatter = LogFormatter([.metadata(including: includingKeys)], defaults: defaults)
        let event = makeEvent(metadata: eventMetadata)
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == expected)
    }

    @Test("metadata including throws when key missing")
    func metadataIncludingThrowsWhenKeyMissing() {
        let formatter = LogFormatter([.metadata(including: ["missing"])])
        let event = makeEvent(metadata: ["a": "1"])
        let context = makeContext(formatter: formatter, event: event)
        #expect(throws: LogFormattingError.missingMetadataValue(key: "missing")) {
            try formatter.format(context)
        }
    }

    @Test("metadata including reports first missing key in sorted order")
    func metadataIncludingReportsFirstMissingKeySorted() {
        let formatter = LogFormatter([.metadata(including: ["z", "a", "m"])])
        let event = makeEvent(metadata: nil)
        let context = makeContext(formatter: formatter, event: event)
        #expect(throws: LogFormattingError.missingMetadataValue(key: "a")) {
            try formatter.format(context)
        }
    }

    @Test(
        "metadata .excluding selection filters keys from merged defaults and event metadata",
        arguments: [
            (["b"], nil as Logger.Metadata?, ["a": "1", "b": "2", "c": "3"] as Logger.Metadata?, "a=1 c=3"),
            (["a", "b"], nil, ["a": "1", "b": "2"], ""),
            ([], nil, ["a": "1", "b": "2"], "a=1 b=2"),
            (["c"], nil, ["a": "1", "b": "2"], "a=1 b=2"),
            (["b", "c"], ["a": "1", "b": "2", "c": "3"], nil, "a=1"),
            (["b", "c"], ["a": "1", "b": "2"], ["c": "3", "d": "4"], "a=1 d=4"),
            (["c"], ["a": "default_value", "c": "3"], ["a": "event_value"], "a=event_value"),
            (["z"], ["a": "1"], ["b": "2"], "a=1 b=2"),
            (["b"], nil, nil, ""),
        ] as [([String], Logger.Metadata?, Logger.Metadata?, String)]
    )
    func excludingSelectionFormatting(
        excludingKeys: [String],
        defaults: Logger.Metadata?,
        eventMetadata: Logger.Metadata?,
        expected: String
    ) throws {
        let formatter = LogFormatter([.metadata(excluding: excludingKeys)], defaults: defaults)
        let event = makeEvent(metadata: eventMetadata)
        let context = makeContext(formatter: formatter, event: event)
        let result = try formatter.format(context)
        #expect(result == expected)
    }

    // 5. custom formatting

    @Test("metadata custom formattedBy closure with .all selection receives empty namedKeys")
    func customFormattedByWithAllSelection() throws {
        let defaults: Logger.Metadata = ["a": "1", "default_key": "default_value"]
        let eventMetadata: Logger.Metadata = ["b": "2", "default_key": "event_value"]

        let formatter = LogFormatter(
            [
                .metadata(formattedBy: { render, _, namedKeys in
                    "all(namedKeys=\(namedKeys.count)):[\(render())]"
                })
            ],
            defaults: defaults
        )
        let result = try formatter.format(
            makeContext(formatter: formatter, event: makeEvent(metadata: eventMetadata))
        )
        #expect(result == "all(namedKeys=0):[a=1 b=2 default_key=event_value]")
    }

    @Test("metadata custom formattedBy with .all selection calls custom formatter")
    func metadataFormattedByAllSelection() throws {
        let formatter = LogFormatter([
            .metadata(formattedBy: { render, _, namedKeys in
                #expect(namedKeys.isEmpty)
                return "all:\(render())"
            })
        ])
        let ctx = makeContext(formatter: formatter, event: makeEvent(metadata: ["a": "1"]))
        let result = try formatter.format(ctx)
        #expect(result == "all:a=1")
    }

    @Test("metadata custom formattedBy closure with .including selection receives specified filter keys")
    func customFormattedByWithIncludingSelection() throws {
        let defaults: Logger.Metadata = ["a": "1", "default_key": "default_value"]
        let eventMetadata: Logger.Metadata = ["b": "2", "default_key": "event_value"]

        let formatter = LogFormatter(
            [
                .metadata(
                    including: ["default_key", "a"],
                    formattedBy: { render, _, namedKeys in
                        "including(namedKeys=\(namedKeys.sorted().joined(separator: ","))):[\(render())]"
                    }
                )
            ],
            defaults: defaults
        )
        let result = try formatter.format(
            makeContext(formatter: formatter, event: makeEvent(metadata: eventMetadata))
        )
        #expect(result == "including(namedKeys=a,default_key):[a=1 default_key=event_value]")
    }

    @Test("metadata custom formattedBy closure with .excluding selection receives specified filter keys")
    func customFormattedByWithExcludingSelection() throws {
        let defaults: Logger.Metadata = ["a": "1", "default_key": "default_value"]
        let eventMetadata: Logger.Metadata = ["b": "2", "default_key": "event_value"]

        let formatter = LogFormatter(
            [
                .metadata(
                    excluding: ["a"],
                    formattedBy: { render, _, namedKeys in
                        "excluding(namedKeys=\(namedKeys.sorted().joined(separator: ","))):[\(render())]"
                    }
                )
            ],
            defaults: defaults
        )
        let result = try formatter.format(
            makeContext(formatter: formatter, event: makeEvent(metadata: eventMetadata))
        )
        #expect(result == "excluding(namedKeys=a):[b=2 default_key=event_value]")
    }

    @Test("metadata custom formattedBy with .excluding selection passes named keys")
    func metadataFormattedByExcludingSelection() throws {
        let formatter = LogFormatter([
            .metadata(
                excluding: ["b"],
                formattedBy: { render, _, namedKeys in
                    #expect(namedKeys == ["b"])
                    return "excluding:\(render())"
                }
            )
        ])
        let ctx = makeContext(formatter: formatter, event: makeEvent(metadata: ["a": "1", "b": "2"]))
        let result = try formatter.format(ctx)
        #expect(result == "excluding:a=1")
    }

    @Test("metadata formattedBy with including selection resolves key from defaults")
    func metadataFormattedByIncludingResolvesDefaults() throws {
        let formatter = LogFormatter(
            [.metadata(including: ["k"], formattedBy: { render, _, _ in render() })],
            defaults: ["k": "v"]
        )
        let ctx = makeContext(formatter: formatter, event: makeEvent(metadata: nil))
        let result = try formatter.format(ctx)
        #expect(result == "k=v")
    }

    @Test(
        "randomized metadata merging produces unique, alphabetically sorted key=value output",
        arguments: 0..<20
    )
    func randomizedMetadataMergingEquivalence(seed: Int) throws {
        var defaults: Logger.Metadata = [:]
        var eventMeta: Logger.Metadata = [:]
        for i in 0..<Int.random(in: 1...15) {
            defaults["key_\(i)"] = .string("default_\(i)")
        }
        for i in 0..<Int.random(in: 5...20) {
            eventMeta["key_\(i)"] = .string("event_\(i)")
        }
        let formatter = LogFormatter([.metadata], defaults: defaults)
        let context = makeContext(formatter: formatter, event: makeEvent(metadata: eventMeta))
        let output = try formatter.format(context)

        var expectedMap = defaults
        for (key, value) in eventMeta { expectedMap[key] = value }
        let expectedOutput = expectedMap.keys.sorted().map { "\($0)=\(expectedMap[$0]!)" }.joined(
            separator: " "
        )
        #expect(output == expectedOutput)
    }

    @Test("repeating strings exceeding buffer reserve format with zero data corruption")
    func formatsLongRepeatingStringsWithoutCorruption() throws {
        let value200 = String(repeating: "Z", count: 200)
        let formatter = LogFormatter([.metadata(key: "long_key")])
        let context = makeContext(
            formatter: formatter,
            event: makeEvent(metadata: ["long_key": .string(value200)])
        )
        #expect(try formatter.format(context) == value200)
    }

    @Test("many metadata keys format with deterministic alphabetical ordering and completeness")
    func formatsManyKeysWithAlphabeticalOrdering() throws {
        var meta: Logger.Metadata = [:]
        for i in 1...25 { meta[String(format: "k_%02d", i)] = .string("\(i)") }
        let formatter = LogFormatter([.metadata])
        let manyKeysContext = makeContext(formatter: formatter, event: makeEvent(metadata: meta))
        let expected = (1...25).map { String(format: "k_%02d=%d", $0, $0) }.joined(separator: " ")
        #expect(try formatter.format(manyKeysContext) == expected)
    }

    @Test("excluding metadata selection on large key collections maintains alphabetical sorting and filtering")
    func formatsExcludingSelectionWithAlphabeticalOrdering() throws {
        var meta: Logger.Metadata = [:]
        for i in 1...25 { meta[String(format: "k_%02d", i)] = .string("\(i)") }
        let formatter = LogFormatter([.metadata(excluding: ["k_01", "k_02", "k_25"])])
        let excludingContext = makeContext(formatter: formatter, event: makeEvent(metadata: meta))
        let expected = (3...24).map { String(format: "k_%02d=%d", $0, $0) }.joined(separator: " ")
        #expect(try formatter.format(excludingContext) == expected)
    }
}

private final class LabelCapture: @unchecked Sendable {
    var label: String = ""
}

private final class ClosureCalledBox: @unchecked Sendable {
    var value: Bool = false
}
