//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Testing

@testable import Lily

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

// Serialized because these tests mutate process-global environment state via
// `setenv`/`unsetenv`. Running them in parallel would let one test's environment
// changes leak into another's `evaluate(fileDescriptor:)` call.
@Suite("ColorSupportTests", .tags(.coloring), .serialized)
struct ColorSupportTests {

    @Test("evaluate returns false when NO_COLOR is set")
    func evaluateReturnsFalseWhenNoColorSet() {
        setenv("NO_COLOR", "1", 1)
        defer { unsetenv("NO_COLOR") }
        #expect(ColorSupport.evaluate(fileDescriptor: 1) == false)
    }

    @Test("evaluate returns true when FORCE_COLOR is set and no NO_COLOR")
    func evaluateReturnsTrueWhenForceColorSet() {
        unsetenv("NO_COLOR")
        setenv("FORCE_COLOR", "1", 1)
        defer { unsetenv("FORCE_COLOR") }
        #expect(ColorSupport.evaluate(fileDescriptor: 1) == true)
    }

    @Test("NO_COLOR takes precedence over FORCE_COLOR")
    func noColorTakesPrecedenceOverForceColor() {
        setenv("NO_COLOR", "1", 1)
        setenv("FORCE_COLOR", "1", 1)
        defer {
            unsetenv("NO_COLOR")
            unsetenv("FORCE_COLOR")
        }
        #expect(ColorSupport.evaluate(fileDescriptor: 1) == false)
    }

    @Test(
        "ColorSupport resolves ANSI capability for TERM values on PTY",
        arguments: [
            ("dumb", false),
            ("xterm-256color", true),
            ("vt100", true),
        ]
    )
    func evaluateTermOnPty(term: String, expected: Bool) throws {
        unsetenv("NO_COLOR")
        unsetenv("FORCE_COLOR")
        setenv("TERM", term, 1)
        defer { unsetenv("TERM") }

        #if canImport(Darwin) || canImport(Glibc)
        var master: Int32 = 0
        var slave: Int32 = 0
        let status = openpty(&master, &slave, nil, nil, nil)
        try #require(status == 0, "openpty should succeed in creating pseudo-terminal")
        defer {
            close(master)
            close(slave)
        }

        let result = ColorSupport.evaluate(fileDescriptor: slave)
        #expect(result == expected)
        #else
        #expect(ColorSupport.evaluate(fileDescriptor: 1) == false)
        #endif
    }

    @Test("ColorSupport.stdout and .stderr are Bool values")
    func stdoutAndStderrAreBool() {
        let _ = ColorSupport.stdout as Bool
        let _ = ColorSupport.stderr as Bool
    }
}
