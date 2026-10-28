// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

struct ErrorMessageMapper {
    static func mapSQLiteError(_ errorCode: Int32, message: String) -> String {
        switch errorCode {
        case 1:
            return "The database file is not a valid SQLite database."
        case 5:
            return "The database file is locked by another application. Please close other programs using this database."
        case 6:
            return "The database table is currently locked. Please try again."
        case 7:
            return "Failed to open the database file. Check if the file exists and you have permission to access it."
        case 8:
            return "The operation was cancelled."
        case 11:
            return "The database file appears to be corrupted."
        case 12:
            return "The database schema has changed. Please refresh the view."
        case 13:
            return "The database is too large or has run out of resources."
        case 14:
            return "Failed to open the database file. Check the file permissions."
        case 16:
            return "The database string format is not recognized."
        case 17:
            return "The operation was interrupted."
        case 18:
            return "The data type is not supported."
        case 19:
            return "Constraint violation: \(extractConstraintInfo(message))"
        case 20:
            return "Data type mismatch. Please check your input."
        case 21:
            return "Invalid database operation."
        case 22:
            return "The operation is trying to access memory that is no longer available."
        case 23:
            return "Database authorization check failed."
        case 24:
            return "Database format is not supported."
        case 25:
            return "An internal error occurred. Please report this issue."
        case 26:
            return "The file is not a valid SQLite database."
        case 27:
            return "File system error. Check if the disk has enough space."
        case 28:
            return "Failed to write to the database. Check file permissions."
        case 30:
            return "Error reading from database. The file might be corrupted."
        case 31:
            return "Failed to write to the database. Check disk space and permissions."
        case 33:
            return "Cannot modify a read-only database."
        case 35:
            return "The operation was interrupted."
        default:
            return "Database error: \(message)"
        }
    }

    static func extractConstraintInfo(_ message: String) -> String {
        let lowercased = message.lowercased()

        if lowercased.contains("unique") {
            return "A record with this value already exists."
        } else if lowercased.contains("not null") || lowercased.contains("notnull") {
            return "This field cannot be empty."
        } else if lowercased.contains("foreign key") {
            return "This record is referenced by other records and cannot be modified."
        } else if lowercased.contains("primary key") {
            return "The primary key must be unique and cannot be empty."
        } else if lowercased.contains("check") {
            return "The value does not meet the required criteria."
        }

        return message
    }

    static func mapSQLError(_ message: String) -> String {
        let lowercased = message.lowercased()

        if lowercased.contains("no such table") {
            if let tableName = extractTableName(from: message, pattern: "no such table: ") {
                return "Table '\(tableName)' does not exist."
            }
            return "The specified table does not exist."
        }

        if lowercased.contains("no such column") {
            if let columnName = extractTableName(from: message, pattern: "no such column: ") {
                return "Column '\(columnName)' does not exist."
            }
            return "The specified column does not exist."
        }

        if lowercased.contains("table already exists") {
            if let tableName = extractTableName(from: message, pattern: "table ") {
                return "Table '\(tableName)' already exists."
            }
            return "A table with this name already exists."
        }

        if lowercased.contains("syntax error") {
            return "SQL syntax error. Please check your query syntax."
        }

        if lowercased.contains("near") {
            return "SQL syntax error near '\(extractNearToken(from: message))'. Please check your query."
        }

        return message
    }

    private static func extractTableName(from message: String, pattern: String) -> String? {
        guard let range = message.range(of: pattern, options: .caseInsensitive) else {
            return nil
        }
        let rest = message[range.upperBound...]
        return rest.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractNearToken(from message: String) -> String {
        guard let range = message.range(of: "near \"", options: .caseInsensitive) else {
            return "unknown"
        }
        let rest = message[range.upperBound...]
        if let endQuote = rest.firstIndex(of: "\"") {
            return String(rest[..<endQuote])
        }
        return "unknown"
    }
}