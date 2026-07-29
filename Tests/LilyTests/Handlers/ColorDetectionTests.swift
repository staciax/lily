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

@Suite("ColorDetectionTests", .tags(.coloring))
struct ColorDetectionTests {

    struct ColorCase: CustomTestStringConvertible {
        let mode: ColorMode
        let streamSupportsColor: Bool
        let expected: Bool
        var testDescription: String { "\(mode) stream=\(streamSupportsColor) -> \(expected)" }
    }

    @Test(
        "ColorMode resolves supportsColor from mode and stream capability",
        arguments: [
            ColorCase(mode: .always, streamSupportsColor: false, expected: true),
            ColorCase(mode: .always, streamSupportsColor: true, expected: true),
            ColorCase(mode: .never, streamSupportsColor: false, expected: false),
            ColorCase(mode: .never, streamSupportsColor: true, expected: false),
            ColorCase(mode: .auto, streamSupportsColor: true, expected: true),
            ColorCase(mode: .auto, streamSupportsColor: false, expected: false),
        ]
    )
    func colorModeResolution(_ c: ColorCase) {
        let capture = CaptureBox()
        let formatter = LogFormatter([
            .message(formattedBy: { render, ctx in
                capture.value = ctx.supportsColor
                return render()
            })
        ])
        var handler = StreamLogHandler(
            label: "test",
            stream: InterceptStream(),
            formatter: formatter,
            colorMode: c.mode,
            streamSupportsColor: c.streamSupportsColor
        )
        handler.logLevel = .trace
        handler.log(event: makeEvent())
        #expect(capture.value == c.expected)
    }

    @Test("supportsColor on LogFormattingContext reflects passed value")
    func formattingContextSupportsColor() {
        let ctx = makeContext(supportsColor: true)
        #expect(ctx.supportsColor == true)
        let ctxFalse = makeContext(supportsColor: false)
        #expect(ctxFalse.supportsColor == false)
    }
}

/// Simple class box used to capture values from @Sendable closures without data-race warnings.
private final class CaptureBox: @unchecked Sendable {
    var value: Bool
    init(_ initial: Bool = false) { self.value = initial }
}
