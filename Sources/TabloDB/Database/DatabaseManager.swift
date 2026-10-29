// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

class DatabaseManager {
    static let shared = DatabaseManager()

    private(set) var connections: [DatabaseConnection] = []
    private let recentListKey = "recentDatabases"
    private let maxRecentItems = 10

    private init() {}

    // MARK: - Connection Management

    func openDatabase(at path: String, type: DatabaseType) throws -> DatabaseConnection {
        // Check if already open
        if let existing = connections.first(where: { $0.path == path }) {
            if existing.isConnected() {
                return existing
            }
        }

        let connection: DatabaseConnection
        switch type {
        case .sqlite:
            connection = SQLiteConnection(path: path)
        case .duckdb:
            connection = DuckDBConnection(path: path)
        case .csv:
            let isDirectory = FileManager.default.isReadableFile(atPath: path) && (try? FileManager.default.contentsOfDirectory(atPath: path)) != nil
            connection = CSVConnection(path: path, isDirectory: isDirectory)
        case .parquet:
            let isDirectory = FileManager.default.isReadableFile(atPath: path) && (try? FileManager.default.contentsOfDirectory(atPath: path)) != nil
            connection = ParquetConnection(path: path, isDirectory: isDirectory)
        }

        try connection.connect()
        connections.append(connection)
        addToRecent(path: path, type: type)
        return connection
    }

    func createDatabase(at path: String, type: DatabaseType) throws -> DatabaseConnection {
        return try openDatabase(at: path, type: type)
    }

    func closeDatabase(_ connection: DatabaseConnection) {
        connection.disconnect()
        connections.removeAll { $0.path == connection.path }
    }

    func closeAllDatabases() {
        for connection in connections {
            connection.disconnect()
        }
        connections.removeAll()
    }

    // MARK: - Recent List

    func getRecentDatabases() -> [(path: String, type: DatabaseType)] {
        guard let data = UserDefaults.standard.data(forKey: recentListKey),
              let list = try? JSONDecoder().decode([RecentDatabaseEntry].self, from: data) else {
            return []
        }
        return list.compactMap { entry in
            guard let t = DatabaseType(rawValue: entry.type) else { return nil }
            return (entry.path, t)
        }
    }

    func addToRecent(path: String, type: DatabaseType) {
        var recent = getRecentDatabaseEntries()
        recent.removeAll { $0.path == path }
        recent.insert(RecentDatabaseEntry(path: path, type: type.rawValue), at: 0)
        if recent.count > maxRecentItems {
            recent = Array(recent.prefix(maxRecentItems))
        }
        if let data = try? JSONEncoder().encode(recent) {
            UserDefaults.standard.set(data, forKey: recentListKey)
        }
    }

    func removeFromRecent(path: String) {
        var recent = getRecentDatabaseEntries()
        recent.removeAll { $0.path == path }
        if let data = try? JSONEncoder().encode(recent) {
            UserDefaults.standard.set(data, forKey: recentListKey)
        }
    }

    private func getRecentDatabaseEntries() -> [RecentDatabaseEntry] {
        guard let data = UserDefaults.standard.data(forKey: recentListKey),
              let list = try? JSONDecoder().decode([RecentDatabaseEntry].self, from: data) else {
            return []
        }
        return list
    }
}

private struct RecentDatabaseEntry: Codable {
    let path: String
    let type: String
}
