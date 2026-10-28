// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation
import DuckDB

class DuckDBConnection: DatabaseConnection {
    let type: DatabaseType = .duckdb
    let path: String
    var displayName: String { URL(fileURLWithPath: path).lastPathComponent }

    private var database: Database?
    private var connection: Connection?

    init(path: String) {
        self.path = path
    }

    func connect() throws {
        let parentDir = URL(fileURLWithPath: path).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        database = try Database(store: .file(at: URL(fileURLWithPath: path)))
        connection = try Connection(database: database!)
    }

    func disconnect() {
        connection = nil
        database = nil
    }

    func isConnected() -> Bool {
        return connection != nil
    }

    func getTables() throws -> [TableInfo] {
        guard let connection = connection else {
            throw DatabaseError.connectionFailed("Database not connected")
        }

        let query = "SELECT table_name, table_type FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name"
        let result = try connection.query(query)

        var tables: [TableInfo] = []
        for i in 0..<result.rowCount {
            let nameCol = result.column(at: 0).cast(to: String.self)
            let typeCol = result.column(at: 1).cast(to: String.self)

            let name = nameCol[i]
            let typeStr = typeCol[i]

            if let name = name, let typeStr = typeStr {
                let tableType: TableType = typeStr == "VIEW" ? .view : .table
                let columns = try getColumns(for: name)
                tables.append(TableInfo(name: name, type: tableType, columns: columns))
            }
        }

        return tables
    }

    private func getColumns(for tableName: String) throws -> [ColumnInfo] {
        guard let connection = connection else {
            throw DatabaseError.connectionFailed("Database not connected")
        }

        let query = "SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = '\(tableName)' AND table_schema = 'main' ORDER BY ordinal_position"
        let result = try connection.query(query)

        var columns: [ColumnInfo] = []
        for i in 0..<result.rowCount {
            let nameCol = result.column(at: 0).cast(to: String.self)
            let typeCol = result.column(at: 1).cast(to: String.self)
            let nullableCol = result.column(at: 2).cast(to: String.self)

            if let name = nameCol[i], let type = typeCol[i] {
                let isNullable = nullableCol[i] == "YES"
                columns.append(ColumnInfo(name: name, type: type, isNullable: isNullable, isPrimaryKey: false, defaultValue: nil))
            }
        }

        return columns
    }

    func executeQuery(_ sql: String) throws -> QueryResult {
        guard let connection = connection else {
            throw DatabaseError.connectionFailed("Database not connected")
        }

        do {
            let result = try connection.query(sql)

            var columns: [String] = []
            for i in 0..<result.columnCount {
                columns.append(result.columnName(at: i))
            }

            var rows: [[Any?]] = []
            for rowIndex in 0..<result.rowCount {
                var row: [Any?] = []
                for colIndex in 0..<result.columnCount {
                    let value = extractValue(from: result, row: rowIndex, column: colIndex)
                    row.append(value)
                }
                rows.append(row)
            }

            return QueryResult(columns: columns, rows: rows, error: nil)
        } catch {
            let friendlyError = ErrorMessageMapper.mapSQLError(String(describing: error))
            return QueryResult(columns: [], rows: [], error: friendlyError)
        }
    }

    private func extractValue(from result: ResultSet, row: DBInt, column: DBInt) -> Any? {
        let voidCol = result.column(at: column)
        let underlyingType = voidCol.underlyingDatabaseType

        switch underlyingType {
        case .integer, .bigint, .smallint, .tinyint:
            let col = voidCol.cast(to: Int64.self)
            return col[row]
        case .utinyint, .usmallint, .uinteger, .ubigint:
            let col = voidCol.cast(to: UInt64.self)
            return col[row]
        case .float:
            let col = voidCol.cast(to: Float.self)
            return col[row]
        case .double:
            let col = voidCol.cast(to: Double.self)
            return col[row]
        case .varchar:
            let col = voidCol.cast(to: String.self)
            return col[row]
        case .boolean:
            let col = voidCol.cast(to: Bool.self)
            return col[row]
        case .date:
            let col = voidCol.cast(to: Date.self)
            return col[row]
        case .timestamp:
            let col = voidCol.cast(to: Timestamp.self)
            return col[row]
        case .blob:
            let col = voidCol.cast(to: Data.self)
            return col[row]
        case .uuid:
            let col = voidCol.cast(to: UUID.self)
            return col[row]
        default:
            let col = voidCol.cast(to: String.self)
            return col[row]
        }
    }

    func executeUpdate(_ sql: String) throws {
        guard let connection = connection else {
            throw DatabaseError.connectionFailed("Database not connected")
        }

        do {
            _ = try connection.query(sql)
        } catch {
            let friendlyError = ErrorMessageMapper.mapSQLError(String(describing: error))
            throw DatabaseError.queryFailed(friendlyError)
        }
    }

    func getPrimaryKeyColumns(for tableName: String) throws -> [String] {
        guard let connection = connection else {
            throw DatabaseError.connectionFailed("Database not connected")
        }

        let query = "SELECT column_name FROM information_schema.table_constraints tc JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name WHERE tc.table_name = '\(tableName)' AND tc.constraint_type = 'PRIMARY KEY' AND tc.table_schema = 'main'"
        let result = try connection.query(query)

        var columns: [String] = []
        for i in 0..<result.rowCount {
            let col = result.column(at: 0).cast(to: String.self)
            if let name = col[i] {
                columns.append(name)
            }
        }

        return columns
    }

    func canEditTable(_ tableName: String) throws -> Bool {
        guard let connection = connection else {
            throw DatabaseError.connectionFailed("Database not connected")
        }

        let query = "SELECT table_type FROM information_schema.tables WHERE table_name = '\(tableName)' AND table_schema = 'main'"
        let result = try connection.query(query)

        guard result.rowCount > 0 else { return false }

        let col = result.column(at: 0).cast(to: String.self)
        guard let typeStr = col[0] else { return false }

        return typeStr == "BASE TABLE"
    }
}
