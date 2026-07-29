//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import WinSDK
import CRT
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Android)
@preconcurrency import Android
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#else
#error("Unsupported runtime")
#endif

/// A namespace for cross-platform terminal ANSI color detection.
internal enum ColorSupport {

    // TODO: Add support for detecting Apple's Container Environment.
    // Reference: https://github.com/apple/container/issues/140

    /// Globally cached Docker detection result
    private static let isRunningInContainer: Bool = {
        #if os(Linux)
        // 1. check for /.dockerenv file (most reliable indicator)
        if let file = fopen("/.dockerenv", "r") {
            fclose(file)
            return true
        }

        // 2. check for /run/.containerenv file (Podman indicator)
        if let file = fopen("/run/.containerenv", "r") {
            fclose(file)
            return true
        }

        // 3. check /proc/1/cgroup for container runtime signatures
        if let file = fopen("/proc/1/cgroup", "r") {
            defer { fclose(file) }

            let bufferSize = 1024
            var buffer = [CChar](repeating: 0, count: bufferSize)

            let signatures = [
                "/docker",
                "/libpod",
                "/kubepods",
                "/lxc",
                "/containerd",
            ]

            // read file line by line and search for known signatures
            while fgets(&buffer, Int32(bufferSize), file) != nil {
                let nullIndex = buffer.firstIndex(of: 0) ?? buffer.count
                let bytes = buffer[..<nullIndex].map { UInt8(bitPattern: $0) }
                let line = String(decoding: bytes, as: UTF8.self)
                for signature in signatures where line.contains(signature) {
                    return true
                }
            }
        }
        #endif
        return false
    }()

    /// Returns whether the given file descriptor's destination supports ANSI
    /// color escape sequences.
    ///
    /// - Parameter fileDescriptor: A file descriptor (e.g. `fileno(stdout)`).
    /// - Returns: `true` if color escape sequences should be emitted.
    internal static func evaluate(fileDescriptor: Int32) -> Bool {
        if getenv("NO_COLOR") != nil { return false }
        if getenv("FORCE_COLOR") != nil { return true }

        #if os(Windows)
        let isAtty = CRT._isatty(fileDescriptor) != 0
        if !isAtty { return false }

        // resolve the standard handle based on the file descriptor
        let handle: HANDLE
        switch fileDescriptor {
        case 1: handle = GetStdHandle(STD_OUTPUT_HANDLE)
        case 2: handle = GetStdHandle(STD_ERROR_HANDLE)
        default: return false
        }

        if handle == INVALID_HANDLE_VALUE { return false }

        var mode: DWORD = 0
        if GetConsoleMode(handle, &mode) {
            let enableVT = DWORD(ENABLE_VIRTUAL_TERMINAL_PROCESSING)

            // if it's already enabled, color is supported
            if (mode & enableVT) != 0 { return true }

            // attempt to enable virtual terminal processing explicitly
            if SetConsoleMode(handle, mode | enableVT) { return true }
        }

        // fallback for older Windows systems utilizing ANSI wrappers like ANSICON
        return getenv("ANSICON") != nil
        #else
        let isAtty = isatty(fileDescriptor) == 1

        // not a TTY and not inside a container (no color support)
        if !isAtty && !isRunningInContainer {
            return false
        }

        // passed the TTY/container check — still reject dumb terminals
        if let term = getenv("TERM"), String(cString: term).lowercased() == "dumb" {
            return false
        }

        return true
        #endif
    }
}

extension ColorSupport {
    /// Whether stdout supports ANSI color. Evaluated once at process start.
    internal static let stdout: Bool = {
        // Resolve the descriptor from libc's own `stdout` via `fileno`/`_fileno`,
        // not `STDOUT_FILENO` (a POSIX `<unistd.h>` constant undefined on Windows).
        #if canImport(Darwin)
        return ColorSupport.evaluate(fileDescriptor: fileno(Darwin.stdout))
        #elseif os(Windows)
        return ColorSupport.evaluate(fileDescriptor: CRT._fileno(CRT.stdout))
        #elseif canImport(Glibc)
        #if os(FreeBSD) || os(OpenBSD)
        return ColorSupport.evaluate(fileDescriptor: fileno(Glibc.stdout))
        #else
        return ColorSupport.evaluate(fileDescriptor: fileno(Glibc.stdout!))
        #endif
        #elseif canImport(Android)
        return ColorSupport.evaluate(fileDescriptor: fileno(Android.stdout))
        #elseif canImport(Musl)
        return ColorSupport.evaluate(fileDescriptor: fileno(Musl.stdout!))
        #elseif canImport(WASILibc)
        return ColorSupport.evaluate(fileDescriptor: fileno(WASILibc.stdout!))
        #else
        #error("Unsupported runtime")
        #endif
    }()

    /// Whether stderr supports ANSI color. Evaluated once at process start.
    internal static let stderr: Bool = {
        #if canImport(Darwin)
        return ColorSupport.evaluate(fileDescriptor: fileno(Darwin.stderr))
        #elseif os(Windows)
        return ColorSupport.evaluate(fileDescriptor: CRT._fileno(CRT.stderr))
        #elseif canImport(Glibc)
        #if os(FreeBSD) || os(OpenBSD)
        return ColorSupport.evaluate(fileDescriptor: fileno(Glibc.stderr))
        #else
        return ColorSupport.evaluate(fileDescriptor: fileno(Glibc.stderr!))
        #endif
        #elseif canImport(Android)
        return ColorSupport.evaluate(fileDescriptor: fileno(Android.stderr))
        #elseif canImport(Musl)
        return ColorSupport.evaluate(fileDescriptor: fileno(Musl.stderr!))
        #elseif canImport(WASILibc)
        return ColorSupport.evaluate(fileDescriptor: fileno(WASILibc.stderr!))
        #else
        #error("Unsupported runtime")
        #endif
    }()
}
