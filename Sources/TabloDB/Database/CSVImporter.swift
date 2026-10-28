// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

struct CSVImportResult {
    let tableName: String
    let rowCount: Int
    let columnCount: Int
}

class CSVImporter {
    static func importCSV(from url: URL, into connection: DatabaseConnection, tableName: String? = nil) throws -> CSVImportResult {
        let content = try String(contentsOf: url, encoding: .utf8)
        let rows = parseCSV(content: content)

        guard !rows.isEmpty else {
            throw DatabaseError.queryFailed("CSV file is empty")
        }

        let headerRow = rows[0]
        let dataRows = Array(rows.dropFirst())

        // Determine table name
        let finalTableName = tableName ?? url.deletingPathExtension().lastPathComponent

        // Infer column types from data
        let columnTypes = inferColumnTypes(rows: dataRows, columnCount: headerRow.count)

        // Create table
        let createSQL = generateCreateTableSQL(tableName: finalTableName, columns: headerRow, types: columnTypes)
        try connection.executeUpdate(createSQL)

        // Insert data
        for row in dataRows {
            let insertSQL = generateInsertSQL(tableName: finalTableName, columns: headerRow, values: row)
            try connection.executeUpdate(insertSQL)
        }

        return CSVImportResult(tableName: finalTableName, rowCount: dataRows.count, columnCount: headerRow.count)
    }

    private static func parseCSV(content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        for char in content {
            if inQuotes {
                if char == "\"" {
                    inQuotes = false
                } else {
                    currentField.append(char)
                }
            } else {
                switch char {
                case "\"":
                    inQuotes = true
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                case "\n", "\r":
                    if !currentField.isEmpty || !currentRow.isEmpty {
                        currentRow.append(currentField)
                        currentField = ""
                        rows.append(currentRow)
                        currentRow = []
                    }
                default:
                    currentField.append(char)
                }
            }
        }

        // Handle last field/row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }

    private static func inferColumnTypes(rows: [[String]], columnCount: Int) -> [String] {
        var types: [String] = Array(repeating: "TEXT", count: columnCount)

        for i in 0..<columnCount {
            var isInteger = true
            var isReal = true

            for row in rows where i < row.count {
                let value = row[i].trimmingCharacters(in: .whitespaces)
                if value.isEmpty { continue }

                if Int64(value) == nil {
                    isInteger = false
                }
                if Double(value) == nil {
                    isReal = false
                }
            }

            if isInteger {
                types[i] = "INTEGER"
            } else if isReal {
                types[i] = "REAL"
            }
        }

        return types
    }

    private static func generateCreateTableSQL(tableName: String, columns: [String], types: [String]) -> String {
        let columnDefs = columns.enumerated().map { index, column in
            let sanitizedColumn = sanitizeIdentifier(column)
            let type = index < types.count ? types[index] : "TEXT"
            return "\(sanitizedColumn) \(type)"
        }.joined(separator: ", ")

        return "CREATE TABLE \(sanitizeIdentifier(tableName)) (\(columnDefs))"
    }

    private static func generateInsertSQL(tableName: String, columns: [String], values: [String]) -> String {
        let sanitizedColumns = columns.map { sanitizeIdentifier($0) }
        let escapedValues = values.map { value in
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                return "NULL"
            }
            return "'\(trimmed.replacingOccurrences(of: "'", with: "''"))'"
        }

        // Pad values array if needed
        var finalValues = escapedValues
        while finalValues.count < columns.count {
            finalValues.append("NULL")
        }

        return "INSERT INTO \(sanitizeIdentifier(tableName)) (\(sanitizedColumns.joined(separator: ", "))) VALUES (\(finalValues.joined(separator: ", ")))"
    }

    private static func sanitizeIdentifier(_ identifier: String) -> String {
        let sanitized = identifier
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }

        if sanitized.isEmpty || sanitized.first?.isNumber == true {
            return "_\(sanitized)"
        }
        return sanitized
    }
}