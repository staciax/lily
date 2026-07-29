//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Logging

/// A closure that formats a single log field, receiving a lazy `render` closure
/// that produces the component's default output and the full `LogFormattingContext`.
public typealias LogFieldFormatter =
    @Sendable (
        _ render: () -> String,
        _ context: LogFormattingContext
    ) -> String

/// A closure that formats collection metadata fields, with access to the
/// component's explicitly named keys.
public typealias LogMetadataFormatter =
    @Sendable (
        _ render: () -> String,
        _ context: LogFormattingContext,
        _ namedKeys: Set<String>
    ) -> String

/// A closure that formats a single metadata key, with access to the targeted key.
public typealias LogMetadataKeyFormatter =
    @Sendable (
        _ render: () -> String,
        _ context: LogFormattingContext,
        _ key: String
    ) -> String

/// A predicate used to conditionally render log components.
public typealias LogPredicate = @Sendable (LogFormattingContext) -> Bool

/// One piece of a log format template.
public struct LogComponent: Sendable, ExpressibleByStringLiteral {
    /// The selection of metadata keys to format.
    enum MetadataSelection: Sendable {
        case all
        /// Selected metadata keys with their precomputed sorted array.
        ///
        /// - Note: `sortedKeys` is precomputed once at component-creation time
        ///   from `keys`, since the selected key set never changes after that.
        ///   This avoids re-sorting the same keys on every single log call.
        case including(keys: Set<String>, sortedKeys: [String])
        case excluding(Set<String>)
    }

    /// The storage backing a log component.
    enum Storage: Sendable {
        case literal(String)
        case timestamp(LogFieldFormatter?)
        case level(LogFieldFormatter?)
        case label(LogFieldFormatter?)
        case message(LogFieldFormatter?)
        case metadata(MetadataSelection, LogMetadataFormatter?)
        case metadataKey(key: String, formatter: LogMetadataKeyFormatter?)
        case source(LogFieldFormatter?)
        case file(LogFieldFormatter?)
        case function(LogFieldFormatter?)
        case line(LogFieldFormatter?)
        case group([LogComponent])
        case joined([LogComponent], separator: String)
        case when(LogPredicate, [LogComponent])
    }

    /// The backing storage representation for this log component.
    let storage: Storage

    /// Creates a log component with explicit storage.
    private init(storage: Storage) { self.storage = storage }

    /// Creates literal text from a string literal.
    public init(stringLiteral value: String) { self = .literal(value) }

    /// Creates literal text.
    ///
    /// - Parameter value: The literal text string.
    /// - Returns: A literal log component.
    public static func literal(_ value: String) -> LogComponent {
        LogComponent(storage: .literal(value))
    }

    /// The prepared timestamp string.
    public static var timestamp: LogComponent { LogComponent(storage: .timestamp(nil)) }
    /// The log level.
    public static var level: LogComponent { LogComponent(storage: .level(nil)) }
    /// The logger label.
    public static var label: LogComponent { LogComponent(storage: .label(nil)) }
    /// The log message.
    public static var message: LogComponent { LogComponent(storage: .message(nil)) }
    /// All metadata.
    public static var metadata: LogComponent { LogComponent(storage: .metadata(.all, nil)) }
    /// The swift-log event source.
    public static var source: LogComponent { LogComponent(storage: .source(nil)) }
    /// The swift-log call-site file.
    public static var file: LogComponent { LogComponent(storage: .file(nil)) }
    /// The swift-log call-site function.
    public static var function: LogComponent { LogComponent(storage: .function(nil)) }
    /// The swift-log call-site line.
    public static var line: LogComponent { LogComponent(storage: .line(nil)) }

    /// Selected metadata keys. Every included key is required.
    ///
    /// - Parameter keys: The keys to include in the metadata formatting.
    /// - Returns: A metadata log component.
    public static func metadata(including keys: [String]) -> LogComponent {
        let keySet = Set(keys)
        return LogComponent(storage: .metadata(.including(keys: keySet, sortedKeys: keySet.sorted()), nil))
    }

    /// All metadata except selected keys.
    ///
    /// - Parameter keys: The keys to exclude from the metadata formatting.
    /// - Returns: A metadata log component.
    public static func metadata(excluding keys: [String]) -> LogComponent {
        LogComponent(storage: .metadata(.excluding(Set(keys)), nil))
    }

    /// One required metadata value.
    ///
    /// - Parameter key: The key of the metadata value to extract.
    /// - Returns: A metadata value log component.
    public static func metadata(key: String) -> LogComponent {
        LogComponent(storage: .metadataKey(key: key, formatter: nil))
    }

    /// Child components formatted consecutively.
    ///
    /// - Parameter components: The child components to group.
    /// - Returns: A grouped log component.
    public static func group(_ components: [LogComponent]) -> LogComponent {
        LogComponent(storage: .group(components))
    }

    /// Non-empty child outputs joined by a separator.
    ///
    /// - Parameters:
    ///   - components: The child components to join.
    ///   - separator: The separator string inserted between components.
    /// - Returns: A joined log component.
    public static func joined(_ components: [LogComponent], separator: String) -> LogComponent {
        LogComponent(storage: .joined(components, separator: separator))
    }

    /// Child components rendered only when the predicate returns `true`.
    ///
    /// - Parameters:
    ///   - predicate: The condition to evaluate.
    ///   - components: The components to render when the condition is met.
    /// - Returns: A conditional log component.
    public static func when(_ predicate: @escaping LogPredicate, then components: [LogComponent]) -> LogComponent {
        LogComponent(storage: .when(predicate, components))
    }

    /// The prepared timestamp field with a custom formatter.
    ///
    /// - Parameter formatter: The closure to format the timestamp.
    /// - Returns: A timestamp log component with custom formatting.
    public static func timestamp(formattedBy formatter: @escaping LogFieldFormatter) -> LogComponent {
        LogComponent(storage: .timestamp(formatter))
    }

    /// The log level field with a custom formatter.
    ///
    /// - Parameter formatter: The closure to format the level.
    /// - Returns: A level log component with custom formatting.
    public static func level(formattedBy formatter: @escaping LogFieldFormatter) -> LogComponent {
        LogComponent(storage: .level(formatter))
    }

    /// The logger label field with a custom formatter.
    ///
    /// - Parameter formatter: The closure to format the label.
    /// - Returns: A label log component with custom formatting.
    public static func label(formattedBy formatter: @escaping LogFieldFormatter) -> LogComponent {
        LogComponent(storage: .label(formatter))
    }

    /// The log message field with a custom formatter.
    ///
    /// - Parameter formatter: The closure to format the message.
    /// - Returns: A message log component with custom formatting.
    public static func message(formattedBy formatter: @escaping LogFieldFormatter) -> LogComponent {
        LogComponent(storage: .message(formatter))
    }

    /// All metadata with a custom formatter.
    ///
    /// - Parameter formatter: The closure to format the metadata.
    /// - Returns: A metadata log component with custom formatting.
    public static func metadata(formattedBy formatter: @escaping LogMetadataFormatter) -> LogComponent {
        LogComponent(storage: .metadata(.all, formatter))
    }

    /// Selected metadata with a custom formatter.
    ///
    /// - Parameters:
    ///   - keys: The keys to include in the metadata formatting.
    ///   - formatter: The closure to format the selected metadata.
    /// - Returns: A metadata log component with custom formatting.
    public static func metadata(
        including keys: [String],
        formattedBy formatter: @escaping LogMetadataFormatter
    )
        -> LogComponent
    {
        let keySet = Set(keys)
        return LogComponent(storage: .metadata(.including(keys: keySet, sortedKeys: keySet.sorted()), formatter))
    }

    /// Metadata except selected keys with a custom formatter.
    ///
    /// - Parameters:
    ///   - keys: The keys to exclude from the metadata formatting.
    ///   - formatter: The closure to format the excluded metadata.
    /// - Returns: A metadata log component with custom formatting.
    public static func metadata(
        excluding keys: [String],
        formattedBy formatter: @escaping LogMetadataFormatter
    )
        -> LogComponent
    {
        LogComponent(storage: .metadata(.excluding(Set(keys)), formatter))
    }

    /// One required metadata value with a custom formatter.
    ///
    /// - Parameters:
    ///   - key: The key of the metadata value to extract.
    ///   - formatter: The closure to format the metadata value.
    /// - Returns: A metadata value log component with custom formatting.
    public static func metadata(key: String, formattedBy formatter: @escaping LogMetadataKeyFormatter) -> LogComponent {
        LogComponent(storage: .metadataKey(key: key, formatter: formatter))
    }

    /// The swift-log event source with a custom formatter.
    ///
    /// - Parameter formatter: The closure to format the source.
    /// - Returns: A source log component with custom formatting.
    public static func source(formattedBy formatter: @escaping LogFieldFormatter) -> LogComponent {
        LogComponent(storage: .source(formatter))
    }

    /// The swift-log call-site file with a custom formatter.
    ///
    /// - Parameter formatter: The closure to format the file path.
    /// - Returns: A file log component with custom formatting.
    public static func file(formattedBy formatter: @escaping LogFieldFormatter) -> LogComponent {
        LogComponent(storage: .file(formatter))
    }

    /// The swift-log call-site function with a custom formatter.
    ///
    /// - Parameter formatter: The closure to format the function name.
    /// - Returns: A function log component with custom formatting.
    public static func function(formattedBy formatter: @escaping LogFieldFormatter) -> LogComponent {
        LogComponent(storage: .function(formatter))
    }

    /// The swift-log call-site line with a custom formatter.
    ///
    /// - Parameter formatter: The closure to format the line number.
    /// - Returns: A line log component with custom formatting.
    public static func line(formattedBy formatter: @escaping LogFieldFormatter) -> LogComponent {
        LogComponent(storage: .line(formatter))
    }
}
