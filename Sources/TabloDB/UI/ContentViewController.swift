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
    private var canEdit: Bool = false
    private var primaryKeyColumns: [String] = []
    private var rowIdentifiers: [[String: Any]] = []

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

        checkEditability(tableInfo: tableInfo)
        loadTableData(tableInfo: tableInfo)
        loadRowCount(tableInfo: tableInfo)
    }

    func refresh() {
        if let table = currentTable {
            loadTableData(tableInfo: table)
            loadRowCount(tableInfo: table)
        }
    }

    private func checkEditability(tableInfo: TableInfo) {
        guard let connection = DatabaseManager.shared.connections.first(where: { $0.isConnected() }) else {
            canEdit = false
            return
        }

        do {
            canEdit = try connection.canEditTable(tableInfo.name)
            if canEdit {
                primaryKeyColumns = try connection.getPrimaryKeyColumns(for: tableInfo.name)
            }
        } catch {
            canEdit = false
            primaryKeyColumns = []
        }
    }

    private func loadTableData(tableInfo: TableInfo) {
        if let connection = DatabaseManager.shared.connections.first(where: { $0.isConnected() }) {
            currentConnection = connection

            // Build query with rowid if available
            var sql: String
            if primaryKeyColumns.isEmpty {
                sql = "SELECT rowid, * FROM \(tableInfo.name) LIMIT \(pageSize) OFFSET \(currentOffset)"
            } else {
                sql = "SELECT * FROM \(tableInfo.name) LIMIT \(pageSize) OFFSET \(currentOffset)"
            }

            if let result = try? connection.executeQuery(sql) {
                queryResult = result
                extractRowIdentifiers(result: result)
                DispatchQueue.main.async {
                    self.updateTableView()
                    self.updatePageInfo()
                }
            }
        }
    }

    private func extractRowIdentifiers(result: QueryResult) {
        rowIdentifiers = []

        if primaryKeyColumns.isEmpty {
            // Use rowid from first column
            for row in result.rows {
                if let rowid = row.first {
                    rowIdentifiers.append(["rowid": rowid ?? 0])
                }
            }
        } else {
            // Extract primary key values
            for row in result.rows {
                var identifier: [String: Any] = [:]
                for (index, col) in result.columns.enumerated() {
                    if primaryKeyColumns.contains(col) {
                        identifier[col] = row[index] ?? ""
                    }
                }
                rowIdentifiers.append(identifier)
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

        let startColumn = primaryKeyColumns.isEmpty ? 1 : 0

        for index in startColumn..<result.columns.count {
            let columnName = result.columns[index]
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
        canEdit = false
        primaryKeyColumns = []
        rowIdentifiers = []
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

    private func saveEdit(row: Int, column: Int, newValue: Any?) {
        guard let connection = currentConnection,
              let tableInfo = currentTable,
              let result = queryResult,
              row < rowIdentifiers.count,
              column < result.columns.count else { return }

        let columnName = result.columns[column]

        // Build UPDATE statement
        var setClause: String
        if let value = newValue {
            if let strValue = value as? String {
                let escaped = strValue.replacingOccurrences(of: "'", with: "''")
                setClause = "\(columnName) = '\(escaped)'"
            } else {
                setClause = "\(columnName) = \(value)"
            }
        } else {
            setClause = "\(columnName) = NULL"
        }

        var whereClause = ""
        if primaryKeyColumns.isEmpty {
            if let rowid = rowIdentifiers[row]["rowid"] {
                whereClause = "rowid = \(rowid)"
            }
        } else {
            var conditions: [String] = []
            for (col, val) in rowIdentifiers[row] {
                if let strVal = val as? String {
                    let escaped = strVal.replacingOccurrences(of: "'", with: "''")
                    conditions.append("\(col) = '\(escaped)'")
                } else {
                    conditions.append("\(col) = \(val)")
                }
            }
            whereClause = conditions.joined(separator: " AND ")
        }

        let sql = "UPDATE \(tableInfo.name) SET \(setClause) WHERE \(whereClause)"

        do {
            try connection.executeUpdate(sql)
            // Update local data
            var updatedRows = result.rows
            updatedRows[row][column] = newValue
            queryResult = QueryResult(columns: result.columns, rows: updatedRows, error: nil)
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    private func showError(message: String) {
        if let window = view.window {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.beginSheetModal(for: window)
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

        var cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? EditableCellView
        if cell == nil {
            cell = EditableCellView()
            cell?.identifier = identifier
        }

        cell?.configure(value: value, isEditable: canEdit)
        cell?.onEdit = { [weak self] newValue in
            self?.saveEdit(row: row, column: columnIndex, newValue: newValue)
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 24
    }
}

class EditableCellView: NSTableCellView {
    private var valueLabel: NSTextField!
    private var editField: NSTextField!
    var onEdit: ((Any?) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        valueLabel = NSTextField()
        valueLabel.isBezeled = false
        valueLabel.drawsBackground = false
        valueLabel.isEditable = false
        valueLabel.isSelectable = true
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(valueLabel)

        editField = NSTextField()
        editField.isBezeled = true
        editField.bezelStyle = .roundedBezel
        editField.isHidden = true
        editField.translatesAutoresizingMaskIntoConstraints = false
        editField.target = self
        editField.action = #selector(editEnded)
        addSubview(editField)

        NSLayoutConstraint.activate([
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            editField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            editField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            editField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(value: Any?, isEditable: Bool) {
        if let value = value {
            valueLabel.stringValue = String(describing: value)
            valueLabel.textColor = .labelColor
            editField.stringValue = String(describing: value)
        } else {
            valueLabel.stringValue = "NULL"
            valueLabel.textColor = .systemGray
            editField.stringValue = ""
        }

        if isEditable {
            valueLabel.allowsEditingTextAttributes = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        if editField.isHidden && event.clickCount == 2 {
            startEditing()
        } else {
            super.mouseDown(with: event)
        }
    }

    private func startEditing() {
        valueLabel.isHidden = true
        editField.isHidden = false
        window?.makeFirstResponder(editField)
    }

    @objc private func editEnded() {
        valueLabel.isHidden = false
        editField.isHidden = true

        let newString = editField.stringValue
        if newString.isEmpty {
            onEdit?(nil)
            valueLabel.stringValue = "NULL"
            valueLabel.textColor = .systemGray
        } else {
            onEdit?(newString)
            valueLabel.stringValue = newString
            valueLabel.textColor = .labelColor
        }
    }
}