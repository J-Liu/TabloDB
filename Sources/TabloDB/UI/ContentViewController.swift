// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class ContentViewController: NSViewController {
    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var currentTable: TableInfo?
    private var currentConnection: DatabaseConnection?
    private var queryResult: QueryResult?
    private var pageSize = 100
    private var currentOffset = 0

    override func loadView() {
        view = NSView()

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .bezelBorder
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        tableView = NSTableView()
        tableView.style = .fullWidth
        tableView.allowsColumnReordering = true
        tableView.allowsColumnResizing = true
        tableView.allowsColumnSelection = false
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = true
        tableView.usesAlternatingRowBackgroundColors = true

        tableView.dataSource = self
        tableView.delegate = self

        scrollView.documentView = tableView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        showEmptyState()
    }

    func displayTable(_ tableInfo: TableInfo?) {
        currentTable = tableInfo
        currentOffset = 0

        guard let tableInfo = tableInfo else {
            showEmptyState()
            return
        }

        loadTableData(tableInfo: tableInfo)
    }

    func refresh() {
        if let table = currentTable {
            loadTableData(tableInfo: table)
        }
    }

    private func loadTableData(tableInfo: TableInfo) {
        // Find connection for this table
        if let connection = DatabaseManager.shared.connections.first(where: { $0.isConnected() }) {
            currentConnection = connection

            let sql = "SELECT * FROM \(tableInfo.name) LIMIT \(pageSize) OFFSET \(currentOffset)"
            if let result = try? connection.executeQuery(sql) {
                queryResult = result
                updateTableView()
            }
        }
    }

    private func updateTableView() {
        while tableView.tableColumns.count > 0 {
            tableView.removeTableColumn(tableView.tableColumns[0])
        }

        guard let result = queryResult else { return }

        for (index, columnName) in result.columns.enumerated() {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_\(index)"))
            column.title = columnName
            column.minWidth = 80
            column.width = 150
            tableView.addTableColumn(column)
        }

        tableView.reloadData()
    }

    private func showEmptyState() {
        while tableView.tableColumns.count > 0 {
            tableView.removeTableColumn(tableView.tableColumns[0])
        }
        queryResult = nil
        tableView.reloadData()
    }
}

extension ContentViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return queryResult?.rows.count ?? 0
    }
}

extension ContentViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let result = queryResult, row < result.rows.count else { return nil }

        let columnIndex = Int(tableColumn?.identifier.rawValue.dropFirst(4) ?? "0") ?? 0
        guard columnIndex < result.columns.count else { return nil }

        let value = result.rows[row][columnIndex]
        let identifier = NSUserInterfaceItemIdentifier("DataCell")

        var cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier

            let textField = NSTextField()
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.isEditable = false
            textField.isSelectable = true
            cell?.textField = textField
            cell?.addSubview(textField)

            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }

        if let value = value {
            cell?.textField?.stringValue = String(describing: value)
            cell?.textField?.textColor = .labelColor
        } else {
            cell?.textField?.stringValue = "NULL"
            cell?.textField?.textColor = .systemGray
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 24
    }
}