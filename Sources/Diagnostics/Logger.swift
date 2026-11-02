// Diagnostics/Logger.swift
// Structured, redacted logging for MacKit.
// SECURITY: Never log clipboard text, images, URLs or secrets.

import Foundation
import os.log

/// Log level for MacKit diagnostic output.
public enum LogLevel: Int, Sendable, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case fault = 4

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .fault: return .fault
        }
    }
}

/// A diagnostic category isolating log output by subsystem.
public struct LogCategory: Sendable, Hashable {
    public let name: String
    public init(_ name: String) { self.name = name }

    public static let appCore = LogCategory("AppCore")
    public static let clipboard = LogCategory("Clipboard")
    public static let window = LogCategory("Window")
    public static let switcher = LogCategory("Switcher")
    public static let storage = LogCategory("Storage")
    public static let crypto = LogCategory("Crypto")
    public static let shortcuts = LogCategory("Shortcuts")
    public static let permissions = LogCategory("Permissions")
}

/// Thread-safe structured logger.
/// Messages are written to the unified logging system (Console.app visible).
/// Sensitive content MUST NOT be passed to any log method.
public final class Logger: Sendable {
    private let osLog: OSLog
    public let category: LogCategory
    private static let subsystem = "com.mackit.app"

    public init(category: LogCategory) {
        self.category = category
        self.osLog = OSLog(subsystem: Self.subsystem, category: category.name)
    }

    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }

    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }

    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }

    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, file: file, function: function, line: line)
    }

    public func fault(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .fault, message: message, file: file, function: function, line: line)
    }

    private func log(level: LogLevel, message: String, file: String, function: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent
        os_log("%{public}s [%{public}s:%d]", log: osLog, type: level.osLogType, message, fileName, line)
    }
}

