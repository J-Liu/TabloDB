# TabloDB

A lightweight native macOS GUI for browsing, editing, and managing SQLite, DuckDB, and other databases.

## Requirements

- macOS 14.0 or later
- Xcode Command Line Tools

## Building

```bash
swift build
```

## Running

```bash
swift run TabloDB
```

## Design Decisions

- **Commit Model**: Immediate commit - each edit is saved to the database immediately.
- **Delete Database**: Moves to Trash (user can recover if needed).
- **Minimum macOS Version**: macOS 14.0

## License

AGPL-3.0-or-later