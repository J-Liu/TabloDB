// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

enum DatabaseError: LocalizedError {
    case connectionFailed(String)
    case queryFailed(String)
    case invalidPath
    case tableNotFound(String)
    case unsupportedOperation(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "Failed to connect to database: \(message)"
        case .queryFailed(let message):
            return "Query failed: \(message)"
        case .invalidPath:
            return "Invalid database file path"
        case .tableNotFound(let name):
            return "Table '\(name)' not found"
        case .unsupportedOperation(let message):
            return "Operation not supported: \(message)"
        }
    }
}

enum DatabaseType: String {
    case sqlite = "sqlite"
    case duckdb = "duckdb"
}

protocol DatabaseConnection {
    var type: DatabaseType { get }
    var path: String { get }
    var displayName: String { get }

    func connect() throws
    func disconnect()
    func isConnected() -> Bool
    func getTables() throws -> [TableInfo]
    func executeQuery(_ sql: String) throws -> QueryResult
}

struct TableInfo {
    let name: String
    let type: TableType
    let columns: [ColumnInfo]
}

enum TableType {
    case table
    case view
}

struct ColumnInfo {
    let name: String
    let type: String
    let isNullable: Bool
    let isPrimaryKey: Bool
    let defaultValue: String?
}

struct QueryResult {
    let columns: [String]
    let rows: [[Any?]]
    let error: String?
}