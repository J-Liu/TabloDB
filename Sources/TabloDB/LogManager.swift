// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

class LogManager {
    static let shared = LogManager()

    private var logFile: FileHandle?
    private var logURL: URL?
    private var enabled = false

    var isEnabled: Bool {
        get { enabled }
        set {
            enabled = newValue
            if newValue {
                setupLogFile()
            } else {
                closeLogFile()
            }
            UserDefaults.standard.set(newValue, forKey: "settings.logEnabled")
        }
    }

    var logPath: String {
        return logURL?.path ?? ""
    }

    private init() {
        // Always setup logURL so path is available even when logging is disabled
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("TabloDB")
        logURL = appDir.appendingPathComponent("tablodb.log")

        enabled = UserDefaults.standard.object(forKey: "settings.logEnabled") as? Bool ?? false
        if enabled {
            setupLogFile()
        }
    }

    private func setupLogFile() {
        guard let logURL = logURL else { return }

        let appDir = logURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        } catch {
            print("Failed to create log directory: \(error)")
            return
        }

        do {
            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil, attributes: nil)
            }
            logFile = try FileHandle(forWritingTo: logURL)
            logFile?.seekToEndOfFile()
            log("=== TabloDB started ===")
        } catch {
            print("Failed to open log file: \(error)")
            logFile = nil
        }
    }

    private func closeLogFile() {
        log("=== TabloDB log disabled ===")
        try? logFile?.close()
        logFile = nil
    }

    func log(_ message: String) {
        guard enabled, let logFile = logFile else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logLine = "[\(timestamp)] \(message)\n"

        if let data = logLine.data(using: .utf8) {
            try? logFile.write(contentsOf: data)
        }
    }

    func log(error: Error, context: String? = nil) {
        let contextStr = context != nil ? " (\(context!))" : ""
        log("ERROR\(contextStr): \(error.localizedDescription)")
    }

    func log(message: String, context: String? = nil) {
        let contextStr = context != nil ? " [\(context!)]" : ""
        log("\(contextStr)\(message)")
    }
}

func LLog(_ message: String) {
    LogManager.shared.log(message)
}

func LLog(error: Error, context: String? = nil) {
    LogManager.shared.log(error: error, context: context)
}

extension String {
    func appendLineToURL(url: URL) throws {
        try (self + "\n").appendToURL(url: url)
    }

    func appendToURL(url: URL) throws {
        let data = self.data(using: .utf8)!
        try data.append(to: url)
    }
}

extension Data {
    func append(to url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            let fileHandle = try FileHandle(forWritingTo: url)
            defer { try? fileHandle.close() }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        } else {
            try write(to: url)
        }
    }
}
