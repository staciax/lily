//
// This source file is part of the Swift Logging API open source project
// Copyright (c) 2018-2019 Apple Inc. and the Swift Logging API project authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//
//
// This source file is part of the Lily open source project
// Modifications copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Logging
import Testing

@testable import Lily

#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import WinSDK
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

@Suite("StreamLogHandlerTests", .tags(.handling))
struct StreamLogHandlerTests {

    // MARK: - Upstream parity
    //
    // These mirror swift-log's `StreamLogHandlerTest`. They pass because
    // `LogFormatter.standard` reproduces upstream's default output format.
    // The upstream snapshot is tracked in `Tests/Fixtures/swift-log/` and the
    // drift check (`scripts/check-swift-log-stream-handler.py`) flags changes.

    @Test func streamLogHandlerWritesToAStream() {
        let interceptStream = InterceptStream()
        let log = Logger(
            label: "test",
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)")

        let messageSucceeded = interceptStream.combined.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        .hasSuffix(testString)

        #expect(messageSucceeded)
        #expect(interceptStream.output.count == 1)
    }

    @Test func streamLogHandlerOutputFormat() {
        let interceptStream = InterceptStream()
        let label = "testLabel"
        let source = "testSource"
        let log = Logger(
            label: label,
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)", source: source)

        let pattern =
            "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\+|-)\\d{4}\\s\(Logger.Level.critical)\\s\(label):\\s\\[\(source)\\]\\s\(testString)$"

        let messageSucceeded =
            interceptStream.combined.trimmingCharacters(in: .whitespacesAndNewlines).range(
                of: pattern,
                options: .regularExpression
            ) != nil

        #expect(messageSucceeded)
        #expect(interceptStream.output.count == 1)
    }

    @Test func streamLogHandlerOutputFormatWithEmptyLabel() {
        let interceptStream = InterceptStream()
        let source = "testSource"
        let log = Logger(
            label: "",
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)", source: source)

        let pattern =
            "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\+|-)\\d{4}\\s\(Logger.Level.critical):\\s\\[\(source)\\]\\s\(testString)$"

        let messageSucceeded =
            interceptStream.combined.trimmingCharacters(in: .whitespacesAndNewlines).range(
                of: pattern,
                options: .regularExpression
            ) != nil

        #expect(messageSucceeded)
        #expect(interceptStream.output.count == 1)
    }

    @Test func streamLogHandlerOutputFormatWithMetaData() {
        let interceptStream = InterceptStream()
        let label = "testLabel"
        let source = "testSource"
        let log = Logger(
            label: label,
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)", metadata: ["test": "test"], source: source)

        let pattern =
            "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\+|-)\\d{4}\\s\(Logger.Level.critical)\\s\(label):\\stest=test\\s\\[\(source)\\]\\s\(testString)$"

        let messageSucceeded =
            interceptStream.combined.trimmingCharacters(in: .whitespacesAndNewlines).range(
                of: pattern,
                options: .regularExpression
            ) != nil

        #expect(messageSucceeded)
        #expect(interceptStream.output.count == 1)
    }

    @Test func streamLogHandlerOutputFormatWithOrderedMetadata() {
        let interceptStream = InterceptStream()
        let log = Logger(
            label: "testLabel",
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)", metadata: ["a": "a0", "b": "b0"])
        log.critical("\(testString)", metadata: ["b": "b1", "a": "a1"])

        #expect(interceptStream.output.count == 2)
        guard interceptStream.output.count == 2 else {
            Issue.record("Intercepted \(interceptStream.output.count) logs, expected 2")
            return
        }

        #expect(
            interceptStream.output[0].contains("a=a0 b=b0"),
            "LINES: \(interceptStream.output[0])"
        )
        #expect(
            interceptStream.output[1].contains("a=a1 b=b1"),
            "LINES: \(interceptStream.output[1])"
        )
    }

    @Test func streamLogHandlerWritesIncludeMetadataProviderMetadata() {
        let interceptStream = InterceptStream()
        let log = Logger(
            label: "test",
            factory: {
                StreamLogHandler(
                    label: $0,
                    stream: interceptStream,
                    metadataProvider: .exampleProvider
                )
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)")

        let messageSucceeded = interceptStream.combined.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        .hasSuffix(testString)

        #expect(messageSucceeded)
        #expect(interceptStream.output.count == 1)
        let message = interceptStream.output.first!
        #expect(
            message.contains("example=example-value"),
            "message must contain metadata, was: \(message)"
        )
    }

    @Test("metadataProvider metadata overrides handler metadata when keys collide")
    func metadataProviderOverridesHandlerMetadataOnCollision() {
        let interceptStream = InterceptStream()
        var handler = StreamLogHandler(
            label: "test",
            stream: interceptStream,
            metadataProvider: Logger.MetadataProvider { ["key": "provider-value"] }
        )
        handler.metadata = ["key": "handler-value"]
        let log = Logger(label: "test", factory: { _ in handler })

        log.info("test message")

        let output = interceptStream.combined
        #expect(output.contains("key=provider-value"))
    }

    @Test func stdioOutputStreamWrite() {
        self.withWriteReadFDsAndReadBuffer(flushMode: .always) { logStream, readFD, readBuffer in
            let log = Logger(
                label: "test",
                factory: {
                    StreamLogHandler(label: $0, stream: logStream)
                }
            )
            let testString = "hello\u{0} world"
            log.critical("\(testString)")

            #if os(Windows)
            let size = _read(readFD, readBuffer, 256)
            #else
            let size = read(readFD, readBuffer, 256)
            #endif

            let output = String(
                decoding: UnsafeRawBufferPointer(
                    start: UnsafeRawPointer(readBuffer),
                    count: numericCast(size)
                ),
                as: UTF8.self
            )
            let messageSucceeded = output.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(
                testString
            )
            #expect(messageSucceeded)
        }
    }

    @Test func stdioOutputStreamFlush() {
        // flush on every statement
        self.withWriteReadFDsAndReadBuffer(flushMode: .always) { logStream, readFD, readBuffer in
            Logger(
                label: "test",
                factory: {
                    StreamLogHandler(label: $0, stream: logStream)
                }
            ).critical("test")

            #if os(Windows)
            let size = _read(readFD, readBuffer, 256)
            #else
            let size = read(readFD, readBuffer, 256)
            #endif
            #expect(size > -1, "expected flush")

            logStream.flush()

            #if os(Windows)
            let size2 = _read(readFD, readBuffer, 256)
            #else
            let size2 = read(readFD, readBuffer, 256)
            #endif
            #expect(size2 == -1, "expected no flush")
        }
        // default flushing
        self.withWriteReadFDsAndReadBuffer(flushMode: .undefined) { logStream, readFD, readBuffer in
            Logger(
                label: "test",
                factory: {
                    StreamLogHandler(label: $0, stream: logStream)
                }
            ).critical("test")

            #if os(Windows)
            let size = _read(readFD, readBuffer, 256)
            #else
            let size = read(readFD, readBuffer, 256)
            #endif
            #expect(size == -1, "expected no flush")

            logStream.flush()

            #if os(Windows)
            let size2 = _read(readFD, readBuffer, 256)
            #else
            let size2 = read(readFD, readBuffer, 256)
            #endif
            #expect(size2 > -1, "expected flush")
        }
    }

    func withWriteReadFDsAndReadBuffer(
        flushMode: StdioOutputStream.FlushMode,
        _ body: (StdioOutputStream, CInt, UnsafeMutablePointer<Int8>) -> Void
    ) {
        var fds: [Int32] = [-1, -1]
        #if os(Windows)
        fds.withUnsafeMutableBufferPointer {
            let err = _pipe($0.baseAddress, 256, _O_BINARY)
            #expect(err == 0, "_pipe failed \(err)")
        }
        guard let writeFD = _fdopen(fds[1], "w") else {
            Issue.record("Failed to open file")
            return
        }
        #else
        fds.withUnsafeMutableBufferPointer { ptr in
            let err = pipe(ptr.baseAddress!)
            #expect(err == 0, "pipe failed \(err)")
        }
        guard let writeFD = fdopen(fds[1], "w") else {
            Issue.record("Failed to open file")
            return
        }
        #endif

        let writeBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: 256)
        defer {
            writeBuffer.deinitialize(count: 256)
            writeBuffer.deallocate()
        }

        var err = setvbuf(writeFD, writeBuffer, _IOFBF, 256)
        #expect(err == 0, "setvbuf failed \(err)")

        // Create the stream here while writeFD's concrete type is in scope.
        // Type inference in the generic StdioOutputStream init picks the right
        // C functions for whatever FILE representation this platform/API level uses.
        #if os(Windows)
        let stream = StdioOutputStream(
            file: writeFD,
            flushMode: flushMode,
            lock: _lock_file,
            unlock: _unlock_file,
            write: fwrite,
            flush: fflush
        )
        #else
        let stream = StdioOutputStream(
            file: writeFD,
            flushMode: flushMode,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #endif

        let readFD = fds[0]
        #if os(Windows)
        let hPipe: HANDLE = HANDLE(bitPattern: _get_osfhandle(readFD))!
        #expect(hPipe != INVALID_HANDLE_VALUE)

        var dwMode: DWORD = DWORD(PIPE_NOWAIT)
        let bSucceeded = SetNamedPipeHandleState(hPipe, &dwMode, nil, nil)
        #expect(bSucceeded)
        #else
        err = fcntl(readFD, F_SETFL, fcntl(readFD, F_GETFL) | O_NONBLOCK)
        #expect(err == 0, "fcntl failed \(err)")
        #endif

        let readBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: 256)
        defer {
            readBuffer.deinitialize(count: 256)
            readBuffer.deallocate()
        }

        // the actual test
        body(stream, readFD, readBuffer)

        for fd in fds {
            #if os(Windows)
            _close(fd)
            #else
            close(fd)
            #endif
        }
    }

    // MARK: - Lily extensions
    //
    // Behavior unique to Lily's handler: the filter chain, formatter override and
    // error handling, error-metadata enrichment, value semantics, and the
    // deprecated `log(level:)` migration shim.

    @Test("handler drops event when filter returns nil")
    func handlerDropsEventWhenFiltered() {
        let stream = InterceptStream()
        let handler = StreamLogHandler(
            label: "test",
            stream: stream,
            formatter: FixedFormatter("should-not-appear"),
            filters: [DropFilter(name: "drop")]
        )
        handler.log(event: makeEvent())
        #expect(stream.combined.isEmpty)
    }

    @Test("handler silently swallows formatter errors")
    func handlerSwallowsFormatterErrors() {
        let stream = InterceptStream()
        let handler = StreamLogHandler(
            label: "test",
            stream: stream,
            formatter: ThrowingFormatter(),
            filters: []
        )
        handler.log(event: makeEvent())
        #expect(stream.combined.isEmpty)
    }

    @Test("handler merges handler metadata with event metadata")
    func handlerMergesMetadata() {
        let stream = InterceptStream()
        var handler = StreamLogHandler(
            label: "test",
            stream: stream,
            formatter: LogFormatter([.metadata]),
            filters: []
        )
        handler.metadata = ["handler_key": "handler_val"]
        let event = makeEvent(metadata: ["event_key": "event_val"])
        handler.log(event: event)
        let output = stream.combined
        #expect(output.contains("handler_key=handler_val"))
        #expect(output.contains("event_key=event_val"))
    }

    @Test("event metadata takes precedence over handler metadata")
    func eventMetadataOverridesHandlerMetadata() {
        let stream = InterceptStream()
        var handler = StreamLogHandler(
            label: "test",
            stream: stream,
            formatter: LogFormatter([.metadata(key: "shared")]),
            filters: []
        )
        handler.metadata = ["shared": "handler_val"]
        let event = makeEvent(metadata: ["shared": "event_val"])
        handler.log(event: event)
        #expect(stream.combined.contains("event_val"))
        #expect(!stream.combined.contains("handler_val"))
    }

    @Test("subscript sets and gets metadata")
    func subscriptSetsAndGetsMetadata() {
        var handler = StreamLogHandler(
            label: "test",
            stream: InterceptStream(),
            filters: []
        )
        handler[metadataKey: "key"] = "value"
        #expect(handler[metadataKey: "key"] == "value")
    }

    @Test("subscript returns nil for unset key")
    func subscriptReturnsNilForUnsetKey() {
        let handler = StreamLogHandler(
            label: "test",
            stream: InterceptStream(),
            filters: []
        )
        #expect(handler[metadataKey: "nonexistent"] == nil)
    }

    @Test("deprecated log(level:...) forwards to log(event:) for migration")
    @available(*, deprecated)
    func deprecatedLogForwardsToEvent() {
        let stream = InterceptStream()
        let handler = StreamLogHandler(
            label: "test",
            stream: stream,
            formatter: LogFormatter([.level, " ", .message, " ", .group(["[", .source, "]"])]),
            filters: []
        )
        handler.log(
            level: .warning,
            message: "legacy call",
            metadata: nil,
            source: "LegacySource",
            file: #fileID,
            function: #function,
            line: #line
        )
        let output = stream.combined
        #expect(output.contains("warning"))
        #expect(output.contains("legacy call"))
        #expect(output.contains("[LegacySource]"))
    }

    @Test("error metadata is attached when event has error")
    func errorMetadataAttachedWhenEventHasError() {
        let stream = InterceptStream()
        let handler = StreamLogHandler(
            label: "test",
            stream: stream,
            formatter: LogFormatter([.metadata]),
            filters: []
        )
        struct TestError: Error { var message: String }
        let event = makeEvent(error: TestError(message: "boom"))
        handler.log(event: event)
        let output = stream.combined
        #expect(output.contains("error.message"))
        #expect(output.contains("error.type"))
    }

    @Test("error.message uses string interpolation not localizedDescription")
    func errorMessageUsesStringInterpolation() {
        let stream = InterceptStream()
        let handler = StreamLogHandler(
            label: "test",
            stream: stream,
            formatter: LogFormatter([.metadata(key: "error.message")]),
            filters: []
        )
        struct MyError: Error, CustomStringConvertible {
            var description: String { "interpolated-value" }
        }
        let event = makeEvent(error: MyError())
        handler.log(event: event)
        #expect(stream.combined.contains("interpolated-value"))
    }

    @Test("error.type is the fully qualified type name via String(reflecting:)")
    func errorTypeIsFullyQualified() {
        let stream = InterceptStream()
        let handler = StreamLogHandler(
            label: "test",
            stream: stream,
            formatter: LogFormatter([.metadata(key: "error.type")]),
            filters: []
        )
        struct MyUniqueError: Error {}
        let event = makeEvent(error: MyUniqueError())
        handler.log(event: event)
        #expect(stream.combined.contains("MyUniqueError"))
    }

    @Test("error metadata overrides preexisting error.message and error.type")
    func errorMetadataOverridesPreexisting() {
        let stream = InterceptStream()
        let handler = StreamLogHandler(
            label: "test",
            stream: stream,
            formatter: LogFormatter([.metadata]),
            filters: []
        )
        struct OverrideError: Error, CustomStringConvertible {
            var description: String { "override-error" }
        }
        let event = makeEvent(
            metadata: ["error.message": "original", "error.type": "original"],
            error: OverrideError()
        )
        handler.log(event: event)
        let output = stream.combined
        #expect(output.contains("override-error"))
        #expect(!output.contains("\"original\"") && !output.contains("=original"))
    }

    @Test("replacing filter changes the event seen by the formatter")
    func replacingFilterChangesEvent() {
        let stream = InterceptStream()
        let replacer = LogFilter(name: "replace") { event in
            var e = event
            e.metadata = ["replaced": "true"]
            return e
        }
        let handler = StreamLogHandler(
            label: "test",
            stream: stream,
            formatter: LogFormatter([.metadata(key: "replaced")]),
            filters: [replacer]
        )
        let event = makeEvent(metadata: ["original": "yes"])
        handler.log(event: event)
        #expect(stream.combined.contains("true"))
    }

    @Test("handler appends exactly one newline per event")
    func handlerAppendsExactlyOneNewline() {
        let stream = InterceptStream()
        let handler = StreamLogHandler(
            label: "test",
            stream: stream,
            formatter: FixedFormatter("line"),
            filters: []
        )
        handler.log(event: makeEvent())
        #expect(stream.combined == "line\n")
        #expect(stream.output.count == 1)
    }

    @Test("log level changes on a copied handler do not affect the original")
    func logLevelValueSemantics() {
        var original = StreamLogHandler(label: "orig", stream: InterceptStream(), filters: [])
        original.logLevel = .info
        var copy = original
        copy.logLevel = .error
        #expect(original.logLevel == .info)
        #expect(copy.logLevel == .error)
    }

    @Test("metadata changes on a copied handler do not affect the original")
    func metadataValueSemantics() {
        var original = StreamLogHandler(label: "orig", stream: InterceptStream(), filters: [])
        original.metadata = ["key": "original"]
        var copy = original
        copy.metadata["key"] = "modified"
        #expect(original.metadata["key"] == "original")
        #expect(copy.metadata["key"] == "modified")
    }

    @Test("filter changes on a copied handler do not affect the original")
    func filterValueSemantics() {
        let original = StreamLogHandler(label: "orig", stream: InterceptStream(), filters: [])
        var copy = original
        copy.addFilter(KeepFilter(name: "extra"))
        #expect(original.filters.isEmpty)
        #expect(copy.filters.count == 1)
    }

    @Test("formatter changes on a copied handler do not affect the original")
    func formatterValueSemantics() {
        var original = StreamLogHandler(label: "orig", stream: InterceptStream(), filters: [])
        original.formatter = nil
        var copy = original
        copy.formatter = FixedFormatter("custom")
        #expect(original.formatter == nil)
        #expect(copy.formatter != nil)
    }

    @Test("when all metadata absent formatter receives nil event metadata")
    func allMetadataAbsentYieldsNilEventMetadata() {
        let stream = InterceptStream()
        let capture = MetadataCapture()
        let formatter = LogFormatter([
            .message(formattedBy: { render, ctx in
                capture.metadata = ctx.event.metadata
                return render()
            })
        ])
        let handler = StreamLogHandler(
            label: "test",
            stream: stream,
            formatter: formatter,
            filters: []
        )
        let event = makeEvent(metadata: nil)
        handler.log(event: event)
        #expect(capture.metadata == nil)
    }

    @Test("standardOutput factory method configures handler properties")
    func standardOutputFactoryConfiguresHandler() {
        let handler = StreamLogHandler.standardOutput(
            label: "stdout.test",
            colorMode: .always
        )
        #expect(handler.logLevel == .info)
        #expect(handler.colorMode == .always)
    }

    @Test("standardError factory method configures handler properties")
    func standardErrorFactoryConfiguresHandler() {
        let handler = StreamLogHandler.standardError(
            label: "stderr.test",
            colorMode: .never
        )
        #expect(handler.logLevel == .info)
        #expect(handler.colorMode == .never)
    }
}

extension Logger.MetadataProvider {
    /// Mirrors swift-log's test `exampleProvider`.
    fileprivate static var exampleProvider: Self {
        .init { ["example": .string("example-value")] }
    }
}

private final class MetadataCapture: @unchecked Sendable {
    var metadata: Logger.Metadata? = .some([:])
}
