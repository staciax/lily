//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Logging

/// A formatter that renders logging contexts from an ordered list of components.
public struct LogFormatter: LogFormatting {
    /// The ordered list of components rendered by this formatter.
    public let components: [LogComponent]

    /// The format used by a handler to prepare timestamps.
    public let dateFormat: DateFormat

    /// The fallback metadata values used while formatting.
    public let defaults: Logger.Metadata?

    /// The fully rendered `"key=value key2=value2"` description of `defaults` alone,
    /// precomputed once at init time.
    ///
    /// This is the `.all`-selection output for the (very common) case where an
    /// event carries no per-call metadata, so the effective metadata is exactly
    /// `defaults`. Since `defaults` never changes after a `LogFormatter` is
    /// created, that rendered string never changes either — so `metadataDescription`
    /// can return it directly instead of re-sorting keys and rebuilding the string
    /// on every log call.
    private let defaultsOnlyMetadataDescription: String

    /// Fixed buffer reserve for the output string, covering the large majority of
    /// single-line logs.
    private static let reservedCapacity = 256

    /// Estimated character capacity per metadata key-value pair (e.g., `"key=value "`),
    /// used to pre-allocate string buffers and prevent reallocations during assembly.
    /// Note for Future Work: For specialized heavy workloads (e.g., JSON blobs or base64 payloads),
    /// this constant can be transitioned to an optional configurable property on `LogFormatter`
    /// via a follow-up ticket, allowing per-instance tuning without modifying default behavior.
    private static let estimatedCapacityPerMetadataKey = 32

    /// Creates a formatter from components, a date format, and fallback
    /// metadata values.
    ///
    /// - Parameters:
    ///   - components: The ordered list of components to render.
    ///   - dateFormat: The timestamp format. Defaults to `.iso8601`.
    ///   - defaults: The default metadata values used as a fallback.
    public init(
        _ components: [LogComponent],
        dateFormat: DateFormat = .iso8601,
        defaults: Logger.Metadata? = nil
    ) {
        self.components = components
        self.dateFormat = dateFormat
        self.defaults = defaults
        let sortedDefaultsKeys = defaults?.keys.sorted() ?? []
        self.defaultsOnlyMetadataDescription = Self.renderDescription(
            sortedKeys: sortedDefaultsKeys
        ) { defaults?[$0] }
    }

    /// Renders `"key=value"` pairs, space-separated, for the given sorted keys using a value provider.
    private static func renderDescription(
        sortedKeys: [String],
        getValue: (String) -> Logger.Metadata.Value?
    ) -> String {
        guard !sortedKeys.isEmpty else { return "" }
        var output = ""
        // Pre-allocate buffer capacity based on estimated key-value token lengths
        // to avoid repeated heap reallocations during string appending.
        output.reserveCapacity(sortedKeys.count * Self.estimatedCapacityPerMetadataKey)
        var needsSeparator = false
        for key in sortedKeys {
            guard let value = getValue(key) else {
                assertionFailure("sortedKeys must only contain keys present in metadata or defaults")
                continue
            }
            if needsSeparator { output.append(" ") }
            output.append(key)
            output.append("=")
            output.append(value.description)
            needsSeparator = true
        }
        return output
    }

    /// Formats the context by interpreting each component in order.
    ///
    /// - Parameter context: The formatting context containing the event and handler values.
    /// - Returns: The fully formatted log line.
    /// - Throws: A `LogFormattingError` if a required metadata value is missing.
    public func format(_ context: LogFormattingContext) throws(LogFormattingError) -> String {
        var output = ""
        output.reserveCapacity(Self.reservedCapacity)
        for component in components {
            output += try format(component, context: context)
        }
        return output
    }

    private func format(_ component: LogComponent, context: LogFormattingContext) throws(LogFormattingError) -> String {
        switch component.storage {
        case .literal(let value):
            return value

        case .timestamp(let formatter):
            if let formatter { return formatter({ context.timestamp }, context) }
            return context.timestamp

        case .level(let formatter):
            if let formatter { return formatter({ context.event.level.rawValue }, context) }
            return context.event.level.rawValue

        case .label(let formatter):
            if let formatter { return formatter({ context.label }, context) }
            return context.label

        case .message(let formatter):
            if let formatter { return formatter({ context.event.message.description }, context) }
            return context.event.message.description

        case .metadata(let selection, let formatter):
            if let formatter {
                if case .including(_, let sortedKeys) = selection {
                    for key in sortedKeys
                    where context.event.metadata?[key] == nil && self.defaults?[key] == nil {
                        throw LogFormattingError.missingMetadataValue(key: key)
                    }
                }
                return formatter(
                    { [self] in
                        do {
                            return try metadataDescription(matching: selection, in: context)
                        } catch {
                            assertionFailure(
                                "metadataDescription threw unexpectedly for pre-validated .including keys: \(error)"
                            )
                            return ""
                        }
                    },
                    context,
                    namedKeys(matching: selection)
                )
            }
            return try metadataDescription(matching: selection, in: context)

        case .metadataKey(let key, let formatter):
            guard let value = context.event.metadata?[key] ?? self.defaults?[key] else {
                throw LogFormattingError.missingMetadataValue(key: key)
            }
            if let formatter { return formatter({ value.description }, context, key) }
            return value.description

        case .source(let formatter):
            if let formatter { return formatter({ context.event.source }, context) }
            return context.event.source

        case .file(let formatter):
            if let formatter { return formatter({ context.event.file }, context) }
            return context.event.file

        case .function(let formatter):
            if let formatter { return formatter({ context.event.function }, context) }
            return context.event.function

        case .line(let formatter):
            if let formatter { return formatter({ String(context.event.line) }, context) }
            return String(context.event.line)

        case .group(let components):
            var output = ""
            for component in components {
                output += try format(component, context: context)
            }
            return output

        case .joined(let components, let separator):
            var output = ""
            var needsSeparator = false
            for component in components {
                let rendered = try format(component, context: context)
                guard !rendered.isEmpty else { continue }
                if needsSeparator { output += separator }
                output += rendered
                needsSeparator = true
            }
            return output

        case .when(let predicate, let components):
            guard predicate(context) else { return "" }
            var output = ""
            for component in components {
                output += try format(component, context: context)
            }
            return output
        }
    }

    private func selectedMetadataKeys(
        matching selection: LogComponent.MetadataSelection,
        in context: LogFormattingContext
    ) throws(LogFormattingError) -> [String] {
        switch selection {
        case .all:
            let defaults = self.defaults ?? [:]
            if defaults.isEmpty {
                guard let metadata = context.event.metadata else {
                    assertionFailure("event.metadata must be non-nil when reached via the .all fast path")
                    return []
                }
                return metadata.keys.sorted()
            }
            var keys = [String]()
            keys.reserveCapacity(defaults.count + (context.event.metadata?.count ?? 0))
            keys.append(contentsOf: defaults.keys)
            if let eventMetadata = context.event.metadata {
                for key in eventMetadata.keys where defaults[key] == nil {
                    keys.append(key)
                }
            }
            keys.sort()
            return keys

        case .including(_, let sortedKeys):
            for key in sortedKeys where context.event.metadata?[key] == nil && self.defaults?[key] == nil {
                throw LogFormattingError.missingMetadataValue(key: key)
            }
            return sortedKeys

        case .excluding(let keys):
            let defaults = self.defaults ?? [:]
            let eventMetadata = context.event.metadata ?? [:]
            if defaults.isEmpty && eventMetadata.isEmpty {
                return []
            }
            var selectedKeys = [String]()
            selectedKeys.reserveCapacity(defaults.count + eventMetadata.count)
            for key in defaults.keys where !keys.contains(key) {
                selectedKeys.append(key)
            }
            for key in eventMetadata.keys where defaults[key] == nil && !keys.contains(key) {
                selectedKeys.append(key)
            }
            selectedKeys.sort()
            return selectedKeys
        }
    }

    private func namedKeys(matching selection: LogComponent.MetadataSelection) -> Set<String> {
        switch selection {
        case .all: return []
        case .including(let keys, _), .excluding(let keys): return keys
        }
    }

    private func metadataDescription(
        matching selection: LogComponent.MetadataSelection,
        in context: LogFormattingContext
    ) throws(LogFormattingError) -> String {
        // Fast path: `.all` with no per-event metadata renders to exactly the
        // formatter's precomputed defaults-only description.
        // Skips sorting keys and rebuilding the string entirely.
        if case .all = selection, context.event.metadata?.isEmpty ?? true {
            return defaultsOnlyMetadataDescription
        }

        let keys = try selectedMetadataKeys(matching: selection, in: context)
        return Self.renderDescription(sortedKeys: keys) {
            context.event.metadata?[$0] ?? self.defaults?[$0]
        }
    }
}

extension LogFormatter {
    /// The standard stream formatter, matching `Logging.StreamLogHandler`'s
    /// default output.
    ///
    /// Renders the timestamp, level, optional label, optional metadata, the
    /// bracketed source, and the message. The label and metadata fields are
    /// emitted only when non-empty, matching upstream's conditional spacing and
    /// lowercase level:
    ///
    ///     timestamp info: [source] message
    ///     timestamp info com.example: key=value [source] message
    public static let standard = LogFormatter([
        .timestamp,
        " ",
        .level,
        .when({ !$0.label.isEmpty }, then: [" ", .label]),
        ":",
        .when({ $0.event.metadata?.isEmpty == false }, then: [" ", .metadata]),
        " ",
        .group(["[", .source, "]"]),
        " ",
        .message,
    ])
}
