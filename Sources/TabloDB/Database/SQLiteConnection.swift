// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation
import SQLite3

class SQLiteConnection: DatabaseConnection {
    let type: DatabaseType = .sqlite
    let path: String
    var displayName: String { URL(fileURLWithPath: path).lastPathComponent }

    private var db: OpaquePointer?

    init(path: String) {
        self.path = path
    }

    func connect() throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            let errorMessage = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            sqlite3_close(db)
            db = nil
            throw DatabaseError.connectionFailed(errorMessage)
        }
    }

    func disconnect() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    func isConnected() -> Bool {
        return db != nil
    }

    func getTables() throws -> [TableInfo] {
        guard let db = db else {
            throw DatabaseError.connectionFailed("Database not connected")
        }

        var tables: [TableInfo] = []
        var stmt: OpaquePointer?

        let query = "SELECT name, type FROM sqlite_master WHERE type IN ('table', 'view') AND name NOT LIKE 'sqlite_%' ORDER BY name"

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(stmt, 0))
            let typeStr = String(cString: sqlite3_column_text(stmt, 1))
            let tableType: TableType = typeStr == "view" ? .view : .table

            let columns = try getColumns(for: name)
            tables.append(TableInfo(name: name, type: tableType, columns: columns))
        }

        sqlite3_finalize(stmt)
        return tables
    }

    private func getColumns(for tableName: String) throws -> [ColumnInfo] {
        guard let db = db else {
            throw DatabaseError.connectionFailed("Database not connected")
        }

        var columns: [ColumnInfo] = []
        var stmt: OpaquePointer?

        let query = "PRAGMA table_info(\(tableName))"

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let type = String(cString: sqlite3_column_text(stmt, 2))
            let notNull = sqlite3_column_int(stmt, 3) != 0
            let pk = sqlite3_column_int(stmt, 5) != 0
            let defaultValue: String? = sqlite3_column_type(stmt, 4) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(stmt, 4))
                : nil

            columns.append(ColumnInfo(name: name, type: type, isNullable: !notNull, isPrimaryKey: pk, defaultValue: defaultValue))
        }

        sqlite3_finalize(stmt)
        return columns
    }

    func executeQuery(_ sql: String) throws -> QueryResult {
        guard let db = db else {
            throw DatabaseError.connectionFailed("Database not connected")
        }

        var stmt: OpaquePointer?
        var columns: [String] = []
        var rows: [[Any?]] = []

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let rawError = String(cString: sqlite3_errmsg(db))
            let friendlyError = ErrorMessageMapper.mapSQLError(rawError)
            return QueryResult(columns: [], rows: [], error: friendlyError)
        }

        guard let statement = stmt else {
            return QueryResult(columns: [], rows: [], error: "Failed to prepare SQL statement. Please check your query syntax.")
        }

        let columnCount = sqlite3_column_count(statement)
        for i in 0..<columnCount {
            columns.append(String(cString: sqlite3_column_name(statement, i)))
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [Any?] = []
            for i in 0..<columnCount {
                let value = getColumnValue(stmt: statement, index: i)
                row.append(value)
            }
            rows.append(row)
        }

        sqlite3_finalize(statement)
        return QueryResult(columns: columns, rows: rows, error: nil)
    }

    private func getColumnValue(stmt: OpaquePointer, index: Int32) -> Any? {
        let type = sqlite3_column_type(stmt, index)
        switch type {
        case SQLITE_INTEGER:
            return sqlite3_column_int64(stmt, index)
        case SQLITE_FLOAT:
            return sqlite3_column_double(stmt, index)
        case SQLITE_TEXT:
            return String(cString: sqlite3_column_text(stmt, index))
        case SQLITE_BLOB:
            if let bytes = sqlite3_column_blob(stmt, index) {
                let size = sqlite3_column_bytes(stmt, index)
                return Data(bytes: bytes, count: Int(size))
            }
            return nil
        case SQLITE_NULL:
            return nil
        default:
            return nil
        }
    }

    func executeUpdate(_ sql: String) throws {
        guard let db = db else {
            throw DatabaseError.connectionFailed("Database not connected")
        }

        var errMsg: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if result != SQLITE_OK {
            let rawError = errMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errMsg)
            let friendlyError = ErrorMessageMapper.mapSQLError(rawError)
            throw DatabaseError.queryFailed(friendlyError)
        }
    }

    func getPrimaryKeyColumns(for tableName: String) throws -> [String] {
        let columns = try getColumns(for: tableName)
        let pkColumns = columns.filter { $0.isPrimaryKey }.map { $0.name }
        return pkColumns
    }

    func canEditTable(_ tableName: String) throws -> Bool {
        // Check if table is a view
        guard let db = db else {
            throw DatabaseError.connectionFailed("Database not connected")
        }

        var stmt: OpaquePointer?
        let query = "SELECT type FROM sqlite_master WHERE name = ?"

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(stmt, 1, (tableName as NSString).utf8String, -1, nil)

        var isView = false
        if sqlite3_step(stmt) == SQLITE_ROW {
            let typeStr = String(cString: sqlite3_column_text(stmt, 0))
            isView = (typeStr == "view")
        }
        sqlite3_finalize(stmt)

        if isView {
            return false
        }

        // Check if table has primary key
        let pkColumns = try getPrimaryKeyColumns(for: tableName)
        if !pkColumns.isEmpty {
            return true
        }

        // Check if table uses rowid (not WITHOUT ROWID)
        var withoutRowidStmt: OpaquePointer?
        let withoutRowidQuery = "SELECT COUNT(*) FROM sqlite_master WHERE name = ? AND sql LIKE '%WITHOUT ROWID%'"

        guard sqlite3_prepare_v2(db, withoutRowidQuery, -1, &withoutRowidStmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(withoutRowidStmt, 1, (tableName as NSString).utf8String, -1, nil)

        var usesRowid = true
        if sqlite3_step(withoutRowidStmt) == SQLITE_ROW {
            usesRowid = sqlite3_column_int(withoutRowidStmt, 0) == 0
        }
        sqlite3_finalize(withoutRowidStmt)

        return usesRowid
    }
}
