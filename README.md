# TabloDB

A lightweight native macOS GUI for browsing, editing, and managing SQLite, DuckDB, CSV, and Parquet data sources.

## Features

- **SQLite**: Create, open, edit, and manage SQLite databases
- **DuckDB**: Create, open, edit, and manage DuckDB databases
- **CSV**: Open single CSV files as read-only databases, or open directories to work with multiple CSV files as tables
- **Parquet**: Open single Parquet files as read-only databases, or open directories to work with multiple Parquet files as tables
- **Multi-language Support**: English, Simplified Chinese, Traditional Chinese
- **Auto Update**: Silent background update checks with Sparkle

## Requirements

- macOS 13.0 or later
- Xcode Command Line Tools

## Building

```bash
swift build -c release
./build.sh
```

## Running

```bash
open TabloDB.app
```

## Data Sources

| Format | Single File | Directory |
|--------|-------------|-----------|
| SQLite | One database, multiple tables | N/A |
| DuckDB | One database, multiple tables | N/A |
| CSV | One table (filename = table name) | One database, each CSV file = one table |
| Parquet | One table (filename = table name) | One database, each Parquet file = one table |

## Design Decisions

- **Commit Model**: Immediate commit - each edit is saved to the database immediately
- **Delete Database**: Moves to Trash (user can recover if needed)
- **Minimum macOS Version**: macOS 13.0
- **Native UI**: Pure AppKit, no SwiftUI

## License

AGPL-3.0-or-later
