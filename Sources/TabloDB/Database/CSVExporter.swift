// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import Foundation

class CSVExporter {
    static func exportTableData(result: QueryResult, to url: URL) throws {
        var csvContent = ""

        // Header row
        csvContent += result.columns.map { escapeCSVField($0) }.joined(separator: ",")
        csvContent += "\n"

        // Data rows
        for row in result.rows {
            let rowString = row.map { value -> String in
                if let v = value {
                    return escapeCSVField(String(describing: v))
                } else {
                    return ""
                }
            }.joined(separator: ",")
            csvContent += rowString + "\n"
        }

        try csvContent.write(to: url, atomically: true, encoding: .utf8)
    }

    static func exportQueryResult(connection: DatabaseConnection, sql: String, to url: URL) throws {
        let result = try connection.executeQuery(sql)
        if let error = result.error, !error.isEmpty {
            throw DatabaseError.queryFailed(error)
        }
        try exportTableData(result: result, to: url)
    }

    private static func escapeCSVField(_ field: String) -> String {
        let needsQuote = field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r")
        if needsQuote {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}