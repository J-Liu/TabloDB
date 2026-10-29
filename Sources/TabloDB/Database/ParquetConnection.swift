// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation
import DuckDB

class ParquetConnection: DatabaseConnection {
    let type: DatabaseType = .parquet
    let path: String
    let isDirectory: Bool
    var displayName: String {
        let url = URL(fileURLWithPath: path)
        return isDirectory ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent
    }

    private var database: Database?
    private var connection: Connection?
    private var parquetFiles: [String] = []

    init(path: String, isDirectory: Bool) {
        self.path = path
        self.isDirectory = isDirectory
    }

    func connect() throws {
        database = try Database(store: .inMemory)
        connection = try Connection(database: database!)

        if isDirectory {
            try loadDirectoryParquets()
        } else {
            try loadSingleParquet()
        }
    }

    private func loadSingleParquet() throws {
        let url = URL(fileURLWithPath: path)
        let tableName = url.deletingPathExtension().lastPathComponent
        let safeName = sanitizeTableName(tableName)

        guard let connection = connection else {
            throw DatabaseError.connectionFailed("Database not connected")
        }

        let query = "CREATE VIEW \(safeName) AS SELECT * FROM read_parquet('\(path)')"
        _ = try connection.query(query)
        parquetFiles = [safeName]
    }

    private func loadDirectoryParquets() throws {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: path) else {
            throw DatabaseError.connectionFailed("Cannot read directory")
        }

        guard let connection = connection else {
            throw DatabaseError.connectionFailed("Database not connected")
        }

        for file in files {
            let lowercased = file.lowercased()
            if lowercased.hasSuffix(".parquet") || lowercased.hasSuffix(".parq") {
                let filePath = (path as NSString).appendingPathComponent(file)
                let tableName = (file as NSString).deletingPathExtension
                let safeName = sanitizeTableName(tableName)

                let query = "CREATE VIEW \(safeName) AS SELECT * FROM read_parquet('\(filePath)')"
                do {
                    _ = try connection.query(query)
                    parquetFiles.append(safeName)
                } catch {
                    print("Failed to load Parquet file \(file): \(error)")
                }
            }
        }

        if parquetFiles.isEmpty {
            throw DatabaseError.connectionFailed("No Parquet files found in directory")
        }
    }

    private func sanitizeTableName(_ name: String) -> String {
        var safeName = name.replacingOccurrences(of: " ", with: "_")
        safeName = safeName.replacingOccurrences(of: "-", with: "_")
        safeName = safeName.replacingOccurrences(of: ".", with: "_")
        if let first = safeName.first, !first.isLetter && first != "_" {
            safeName = "_" + safeName
        }
        return safeName
    }

    func disconnect() {
        connection = nil
        database = nil
        parquetFiles = []
    }

    func isConnected() -> Bool {
        return connection != nil
    }

    func getTables() throws -> [TableInfo] {
        guard connection != nil else {
            throw DatabaseError.connectionFailed("Database not connected")
        }

        var tables: [TableInfo] = []
        for tableName in parquetFiles {
            let columns = try getColumns(for: tableName)
            tables.append(TableInfo(name: tableName, type: .view, columns: columns))
        }

        return tables
    }

    private func getColumns(for tableName: String) throws -> [ColumnInfo] {
        guard let connection = connection else {
            throw DatabaseError.connectionFailed("Database not connected")
        }

        let query = "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '\(tableName)' ORDER BY ordinal_position"
        let result = try connection.query(query)

        var columns: [ColumnInfo] = []
        for i in 0..<result.rowCount {
            let nameCol = result.column(at: 0).cast(to: String.self)
            let typeCol = result.column(at: 1).cast(to: String.self)

            if let name = nameCol[i], let type = typeCol[i] {
                columns.append(ColumnInfo(name: name, type: type, isNullable: true, isPrimaryKey: false, defaultValue: nil))
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
        throw DatabaseError.unsupportedOperation("Parquet files are read-only")
    }

    func getPrimaryKeyColumns(for tableName: String) throws -> [String] {
        return []
    }

    func canEditTable(_ tableName: String) throws -> Bool {
        return false
    }
}
