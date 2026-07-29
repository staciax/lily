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

import Logging

#if canImport(Darwin)
import Darwin
#elseif os(Windows)
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

/// Stream log handler presents log messages to STDERR or STDOUT.
///
/// This is a Lily implementation of `LogHandler` that directs `Logger`
/// output to either `stderr` or `stdout` via the factory methods, rendering
/// each event through a ``LogFormatting`` formatter after running the configured
/// filter chain.
///
/// Metadata is merged in the following order:
/// 1. Metadata set on the log handler itself is used as the base metadata.
/// 2. The handler's ``metadataProvider`` is invoked, overriding any existing keys.
/// 3. The per-log-statement metadata is merged, overriding any previously set keys.
///
/// When both `Logging` and `Lily` are imported, use the fully qualified
/// `Lily.StreamLogHandler` to disambiguate from `Logging.StreamLogHandler`.
public struct StreamLogHandler: Logging.LogHandler {

    /// Controls whether a stream handler applies ANSI color.
    public enum ColorMode: Sendable {
        /// Always apply ANSI color escape sequences.
        case always
        /// Never apply ANSI color escape sequences.
        case never
        /// Detect color support from the destination stream.
        case auto
    }

    /// The line terminator appended to each rendered log message.
    private static let terminator = "\n"

    /// The formatter used when `formatter` is `nil`, resolved once for the
    /// whole process rather than on every handler instance.
    private static let defaultFormatter: any LogFormatting = LogFormatter.standard

    /// The formatter used to render log events.
    ///
    /// When `nil`, the handler falls back to ``LogFormatter/standard``.
    public var formatter: (any LogFormatting)?

    /// The filters applied before emitting events.
    public private(set) var filters: [any LogFiltering]

    /// Controls whether this handler applies ANSI color.
    public let colorMode: ColorMode

    /// Get the log level configured for this `Logger`.
    ///
    /// > Note: Changing the log level threshold for a logger only affects the instance of the `Logger` where you change it.
    /// > It is acceptable for logging backends to have some form of global log level override
    /// > that affects multiple or even all loggers. This means a change in `logLevel` to one `Logger` might in
    /// > certain cases have no effect.
    public var logLevel: Logger.Level = .info

    /// The metadata provider.
    public var metadataProvider: Logger.MetadataProvider?

    /// Get or set the entire metadata storage as a dictionary.
    public var metadata = Logger.Metadata()

    /// The label identifying the logger instance.
    private let label: String

    /// The text output stream destination.
    private let stream: any TextOutputStream & Sendable

    /// Indicates whether the target stream supports color output.
    private let streamSupportsColor: Bool

    /// Resolves whether ANSI color formatting should be enabled based on `colorMode`.
    private var supportsColor: Bool {
        switch self.colorMode {
        case .always: true
        case .never: false
        case .auto: streamSupportsColor
        }
    }

    /// The resolved non-nil log formatter instance.
    private var resolvedFormatter: any LogFormatting {
        self.formatter ?? Self.defaultFormatter
    }

    /// Creates a stream handler that directs its output to STDOUT.
    ///
    /// - Parameters:
    ///   - label: The label identifying the logger.
    ///   - metadataProvider: The provider to use for metadata defaults.
    ///   - formatter: The log formatter to use.
    ///   - filters: The list of filters to apply.
    ///   - colorMode: The color mode to use.
    /// - Returns: A configured stream log handler writing to standard output.
    public static func standardOutput(
        label: String,
        metadataProvider: Logger.MetadataProvider? = nil,
        formatter: (any LogFormatting)? = nil,
        filters: [any LogFiltering] = [],
        colorMode: ColorMode = .auto
    ) -> Self {
        StreamLogHandler(
            label: label,
            stream: StdioOutputStream.stdout,
            metadataProvider: metadataProvider,
            formatter: formatter,
            filters: filters,
            colorMode: colorMode,
            streamSupportsColor: ColorSupport.stdout
        )
    }

    /// Creates a stream handler that directs its output to STDERR.
    ///
    /// - Parameters:
    ///   - label: The label identifying the logger.
    ///   - metadataProvider: The provider to use for metadata defaults.
    ///   - formatter: The log formatter to use.
    ///   - filters: The list of filters to apply.
    ///   - colorMode: The color mode to use.
    /// - Returns: A configured stream log handler writing to standard error.
    public static func standardError(
        label: String,
        metadataProvider: Logger.MetadataProvider? = nil,
        formatter: (any LogFormatting)? = nil,
        filters: [any LogFiltering] = [],
        colorMode: ColorMode = .auto
    ) -> Self {
        StreamLogHandler(
            label: label,
            stream: StdioOutputStream.stderr,
            metadataProvider: metadataProvider,
            formatter: formatter,
            filters: filters,
            colorMode: colorMode,
            streamSupportsColor: ColorSupport.stderr
        )
    }

    /// Creates a stream log handler writing to a custom text output stream.
    ///
    /// - Parameters:
    ///   - label: The label identifying the logger.
    ///   - stream: The text output stream where formatted log output will be written.
    ///   - metadataProvider: The provider to use for metadata defaults.
    ///   - formatter: The log formatter to use. When `nil`, defaults to ``LogFormatter/standard``.
    ///   - filters: The list of filters to apply before emitting events.
    ///   - colorMode: The color mode controlling ANSI escape sequences.
    ///   - streamSupportsColor: Indicates whether the output stream supports color formatting when `colorMode` is `.auto`.
    public init(
        label: String,
        stream: any TextOutputStream & Sendable,
        metadataProvider: Logger.MetadataProvider? = LoggingSystem.metadataProvider,
        formatter: (any LogFormatting)? = nil,
        filters: [any LogFiltering] = [],
        colorMode: ColorMode = .auto,
        streamSupportsColor: Bool = false
    ) {
        self.label = label
        self.stream = stream
        self.metadataProvider = metadataProvider
        self.formatter = formatter
        self.filters = filters
        self.colorMode = colorMode
        self.streamSupportsColor = streamSupportsColor
    }

    /// Appends the filter to the chain, unless one with the same ``LogFiltering/name``
    /// is already present.
    ///
    /// - Parameter filter: The filter to add to the handler's chain.
    /// - Returns: `true` if the filter was appended, `false` if a filter with the
    ///   same `name` already existed and this call was a no-op.
    @discardableResult
    public mutating func addFilter(_ filter: any LogFiltering) -> Bool {
        guard !self.filters.contains(where: { $0.name == filter.name }) else {
            return false
        }
        self.filters.append(filter)
        return true
    }

    /// Removes the first filter whose ``LogFiltering/name`` matches the given
    /// filter's `name`.
    ///
    /// Matching is by `name`, not by instance identity, so this can remove a
    /// *different* filter that shares the same `name`.
    ///
    /// - Parameter filter: The filter whose `name` identifies the entry to remove.
    public mutating func removeFilter(_ filter: any LogFiltering) {
        if let index = self.filters.firstIndex(where: { $0.name == filter.name }) {
            self.filters.remove(at: index)
        }
    }

    /// Filters the given log event through the handler's filter chain.
    ///
    /// The event is passed sequentially through each filter in ``filters`` in
    /// insertion order. If any filter returns `nil`, the event is immediately
    /// dropped and this method returns `nil`. Otherwise, the (potentially modified)
    /// event is passed to the next filter.
    ///
    /// - Parameter event: The log event to filter.
    /// - Returns: The final filtered log event, or `nil` if the event is dropped.
    public func filter(_ event: LogEvent) -> LogEvent? {
        guard !self.filters.isEmpty else { return event }
        var event = event
        for filter in self.filters {
            guard let result = filter.filter(event) else { return nil }
            event = result
        }
        return event
    }

    /// Add, change, or remove a logging metadata item.
    ///
    /// > Note: Changing the logging metadata only affects the instance of the `Logger` where you change it.
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            self.metadata[metadataKey]
        }
        set {
            self.metadata[metadataKey] = newValue
        }
    }

    /// Log a message using the log level and source that you provide.
    ///
    /// The event is first passed through the configured ``filters``. If any filter
    /// drops it, the handler returns without writing. The surviving event is then
    /// rendered by the selected formatter and written to the stream once.
    ///
    /// - parameters:
    ///    - event: The log event containing the level, message, metadata, and source location.
    public func log(event: LogEvent) {
        guard var filteredEvent = self.filter(event) else { return }

        let effectiveMetadata = StreamLogHandler.prepareMetadata(
            base: self.metadata,
            provider: self.metadataProvider,
            explicit: filteredEvent.metadata,
            error: filteredEvent.error
        )
        filteredEvent.metadata = effectiveMetadata ?? (self.metadata.isEmpty ? nil : self.metadata)

        let formatter = self.resolvedFormatter
        let timestamp = self.timestamp(format: formatter.dateFormat.rawValue)
        let context = LogFormattingContext(
            formatter: formatter,
            label: self.label,
            event: filteredEvent,
            timestamp: timestamp,
            supportsColor: self.supportsColor
        )

        do {
            let output = try formatter.format(context)
            var stream = self.stream
            stream.write(output + Self.terminator)
        } catch {
            return
        }
    }

    @available(*, deprecated, renamed: "log(event:)")
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        self.log(
            event: LogEvent(
                level: level,
                message: message,
                metadata: metadata,
                source: source,
                file: file,
                function: function,
                line: line
            )
        )
    }

    internal static func prepareMetadata(
        base: Logger.Metadata,
        provider: Logger.MetadataProvider?,
        explicit: Logger.Metadata?,
        error: (any Error)?
    ) -> Logger.Metadata? {
        var metadata = base

        let provided = provider?.get() ?? [:]

        guard !provided.isEmpty || !((explicit ?? [:]).isEmpty) || error != nil else {
            // all per-log-statement values are empty
            return nil
        }

        if !provided.isEmpty {
            metadata.merge(provided, uniquingKeysWith: { _, provided in provided })
        }

        if let explicit = explicit, !explicit.isEmpty {
            metadata.merge(explicit, uniquingKeysWith: { _, explicit in explicit })
        }

        if let error {
            metadata["error.message"] = "\(error)"
            metadata["error.type"] = "\(String(reflecting: type(of: error)))"
        }

        return metadata
    }

    private func timestamp(format: String) -> String {
        var buffer = [Int8](repeating: 0, count: 255)
        #if os(Windows)
        var timestamp = __time64_t()
        _ = _time64(&timestamp)

        var localTime = tm()
        _ = _localtime64_s(&localTime, &timestamp)

        _ = strftime(&buffer, buffer.count, format, &localTime)
        #else
        var timestamp = time(nil)
        guard let localTime = localtime(&timestamp) else {
            return "<unknown>"
        }
        strftime(&buffer, buffer.count, format, localTime)
        #endif
        return buffer.withUnsafeBufferPointer {
            $0.withMemoryRebound(to: CChar.self) {
                String(cString: $0.baseAddress!)
            }
        }
    }
}

/// A wrapper to facilitate `print`-ing to stderr and stdio that
/// ensures access to the underlying `FILE` is locked to prevent
/// cross-thread interleaving of output.
internal struct StdioOutputStream: TextOutputStream, @unchecked Sendable {
    internal let flushMode: FlushMode
    private let _writeBytes: (UnsafeBufferPointer<UInt8>) -> Void
    private let _flush: () -> Void

    // Using a generic initializer lets Swift infer the concrete file-pointer type
    // at each call site from the values passed. This avoids a CFilePointer typealias
    // that cannot vary by Android API level (API 23 exposes FILE as
    // UnsafeMutablePointer<FILE>; API 24+ makes it OpaquePointer).
    internal init<F>(
        file: F,
        flushMode: FlushMode,
        lock: ((F) -> Void)?,
        unlock: ((F) -> Void)?,
        write: @escaping (UnsafeRawPointer, Int, Int, F) -> Int,
        flush: @escaping (F) -> Int32
    ) {
        self.flushMode = flushMode
        self._writeBytes = { bytes in
            lock?(file)
            defer { unlock?(file) }
            if let base = bytes.baseAddress, bytes.count > 0 {
                _ = write(base, 1, bytes.count, file)
            }
        }
        self._flush = { _ = flush(file) }
    }

    internal func write(_ string: String) {
        self.contiguousUTF8(string).withContiguousStorageIfAvailable { utf8Bytes in
            self._writeBytes(utf8Bytes)
            if case .always = self.flushMode {
                self.flush()
            }
        }!
    }

    /// Flush the underlying stream.
    internal func flush() {
        self._flush()
    }

    internal func contiguousUTF8(_ string: String) -> String.UTF8View {
        var contiguousString = string
        contiguousString.makeContiguousUTF8()
        return contiguousString.utf8
    }

    internal static let stderr: StdioOutputStream = {
        #if canImport(Darwin)
        return StdioOutputStream(
            file: Darwin.stderr,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #elseif os(Windows)
        return StdioOutputStream(
            file: CRT.stderr,
            flushMode: .always,
            lock: _lock_file,
            unlock: _unlock_file,
            write: fwrite,
            flush: fflush
        )
        #elseif canImport(Glibc)
        #if os(FreeBSD) || os(OpenBSD)
        return StdioOutputStream(
            file: Glibc.stderr,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #else
        return StdioOutputStream(
            file: Glibc.stderr!,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #endif
        #elseif canImport(Android)
        return StdioOutputStream(
            file: Android.stderr,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #elseif canImport(Musl)
        return StdioOutputStream(
            file: Musl.stderr!,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #elseif canImport(WASILibc)
        // no file locking on WASI
        return StdioOutputStream(
            file: WASILibc.stderr!,
            flushMode: .always,
            lock: nil,
            unlock: nil,
            write: fwrite,
            flush: fflush
        )
        #else
        #error("Unsupported runtime")
        #endif
    }()

    internal static let stdout: StdioOutputStream = {
        #if canImport(Darwin)
        return StdioOutputStream(
            file: Darwin.stdout,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #elseif os(Windows)
        return StdioOutputStream(
            file: CRT.stdout,
            flushMode: .always,
            lock: _lock_file,
            unlock: _unlock_file,
            write: fwrite,
            flush: fflush
        )
        #elseif canImport(Glibc)
        #if os(FreeBSD) || os(OpenBSD)
        return StdioOutputStream(
            file: Glibc.stdout,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #else
        return StdioOutputStream(
            file: Glibc.stdout!,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #endif
        #elseif canImport(Android)
        return StdioOutputStream(
            file: Android.stdout,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #elseif canImport(Musl)
        return StdioOutputStream(
            file: Musl.stdout!,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #elseif canImport(WASILibc)
        // no file locking on WASI
        return StdioOutputStream(
            file: WASILibc.stdout!,
            flushMode: .always,
            lock: nil,
            unlock: nil,
            write: fwrite,
            flush: fflush
        )
        #else
        #error("Unsupported runtime")
        #endif
    }()

    /// Defines the flushing strategy for the underlying stream.
    internal enum FlushMode {
        case undefined
        case always
    }
}

/// Typealias providing top-level access to ``StreamLogHandler/ColorMode``.
public typealias ColorMode = StreamLogHandler.ColorMode
