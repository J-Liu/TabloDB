// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class ContentViewController: NSViewController {
    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var toolbarView: NSView!
    private var pageInfoLabel: NSTextField!
    private var prevButton: NSButton!
    private var nextButton: NSButton!

    private var currentTable: TableInfo?
    private var currentConnection: DatabaseConnection?
    private var queryResult: QueryResult?
    private var pageSize = 100
    private var currentOffset = 0
    private var totalRowCount: Int?

    override func loadView() {
        view = NSView()

        let containerStack = NSStackView()
        containerStack.orientation = .vertical
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        containerStack.spacing = 0
        view.addSubview(containerStack)

        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: view.topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Toolbar
        toolbarView = NSView()
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        toolbarView.wantsLayer = true

        let toolbarStack = NSStackView()
        toolbarStack.orientation = .horizontal
        toolbarStack.translatesAutoresizingMaskIntoConstraints = false
        toolbarStack.spacing = 8
        toolbarStack.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        toolbarView.addSubview(toolbarStack)

        NSLayoutConstraint.activate([
            toolbarStack.topAnchor.constraint(equalTo: toolbarView.topAnchor),
            toolbarStack.leadingAnchor.constraint(equalTo: toolbarView.leadingAnchor),
            toolbarStack.trailingAnchor.constraint(equalTo: toolbarView.trailingAnchor),
            toolbarStack.bottomAnchor.constraint(equalTo: toolbarView.bottomAnchor)
        ])

        prevButton = NSButton(title: "Previous", target: self, action: #selector(previousPage))
        prevButton.isEnabled = false

        nextButton = NSButton(title: "Next", target: self, action: #selector(nextPage))
        nextButton.isEnabled = false

        pageInfoLabel = NSTextField(labelWithString: "No data")
        pageInfoLabel.alignment = .center

        toolbarStack.addArrangedSubview(prevButton)
        toolbarStack.addArrangedSubview(pageInfoLabel)
        toolbarStack.addArrangedSubview(nextButton)

        containerStack.addArrangedSubview(toolbarView)

        // Data grid
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder

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
        containerStack.addArrangedSubview(scrollView)

        // Set toolbar height
        NSLayoutConstraint.activate([
            toolbarView.heightAnchor.constraint(equalToConstant: 32)
        ])
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
        loadRowCount(tableInfo: tableInfo)
    }

    func refresh() {
        if let table = currentTable {
            loadTableData(tableInfo: table)
            loadRowCount(tableInfo: table)
        }
    }

    private func loadTableData(tableInfo: TableInfo) {
        if let connection = DatabaseManager.shared.connections.first(where: { $0.isConnected() }) {
            currentConnection = connection

            let sql = "SELECT * FROM \(tableInfo.name) LIMIT \(pageSize) OFFSET \(currentOffset)"
            if let result = try? connection.executeQuery(sql) {
                queryResult = result
                DispatchQueue.main.async {
                    self.updateTableView()
                    self.updatePageInfo()
                }
            }
        }
    }

    private func loadRowCount(tableInfo: TableInfo) {
        guard let connection = currentConnection else { return }

        DispatchQueue.global().async {
            let sql = "SELECT COUNT(*) FROM \(tableInfo.name)"
            if let result = try? connection.executeQuery(sql),
               let count = result.rows.first?.first as? Int64 {
                DispatchQueue.main.async {
                    self.totalRowCount = Int(count)
                    self.updatePageInfo()
                }
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

    private func updatePageInfo() {
        guard queryResult != nil else {
            pageInfoLabel.stringValue = "No data"
            prevButton.isEnabled = false
            nextButton.isEnabled = false
            return
        }

        let startRow = currentOffset + 1
        let endRow = currentOffset + (queryResult?.rows.count ?? 0)

        if let total = totalRowCount {
            pageInfoLabel.stringValue = "\(startRow)-\(endRow) of \(total)"
        } else {
            pageInfoLabel.stringValue = "\(startRow)-\(endRow)"
        }

        prevButton.isEnabled = currentOffset > 0
        nextButton.isEnabled = (totalRowCount == nil) || (endRow < totalRowCount!)
    }

    private func showEmptyState() {
        while tableView.tableColumns.count > 0 {
            tableView.removeTableColumn(tableView.tableColumns[0])
        }
        queryResult = nil
        totalRowCount = nil
        tableView.reloadData()
        updatePageInfo()
    }

    @objc private func previousPage() {
        guard currentOffset > 0 else { return }
        currentOffset = max(0, currentOffset - pageSize)
        if let table = currentTable {
            loadTableData(tableInfo: table)
        }
    }

    @objc private func nextPage() {
        currentOffset += pageSize
        if let table = currentTable {
            loadTableData(tableInfo: table)
        }
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