//
// This source file is part of the Lily open source project
// Copyright (c) 2026 STACiA and the Lily project authors
//
// See LICENSE for license information
// SPDX-License-Identifier: Apache-2.0
//

import Logging

func makeEvent(
    level: Logger.Level = .info,
    message: Logger.Message = "test message",
    metadata: Logger.Metadata? = nil,
    source: String = "TestSource",
    file: String = "TestFile.swift",
    function: String = "testFunction()",
    line: UInt = 1,
    error: (any Error)? = nil
) -> LogEvent {
    LogEvent(
        level: level,
        message: message,
        error: error,
        metadata: metadata,
        source: source,
        file: file,
        function: function,
        line: line
    )
}
