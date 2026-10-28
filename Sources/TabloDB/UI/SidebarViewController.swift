// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class SidebarViewController: NSViewController {
    var onTableSelected: ((TableInfo) -> Void)?

    private var tableView: NSTableView!
    private var searchField: NSSearchField!
    private var addButton: NSButton!
    private var tables: [TableInfo] = []
    private var filteredTables: [TableInfo] = []
    private(set) var currentConnection: DatabaseConnection?

    override func loadView() {
        view = NSView()

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Search field and add button
        let searchContainer = NSView()
        searchContainer.translatesAutoresizingMaskIntoConstraints = false

        searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search tables..."
        searchField.target = self
        searchField.action = #selector(searchTextChanged)
        searchField.bezelStyle = .roundedBezel

        addButton = NSButton(title: "+", target: self, action: #selector(addTable))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.bezelStyle = .rounded
        addButton.isEnabled = false

        searchContainer.addSubview(searchField)
        searchContainer.addSubview(addButton)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: searchContainer.topAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 8),
            addButton.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 4),
            addButton.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -8),
            addButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            searchField.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: -8)
        ])
        stackView.addArrangedSubview(searchContainer)

        // Table list
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        tableView = NSTableView()
        tableView.style = .sourceList
        tableView.headerView = nil
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false
        tableView.target = self
        tableView.doubleAction = #selector(tableDoubleClicked)
        tableView.menu = createTableMenu()

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = "Tables"
        tableView.addTableColumn(column)

        tableView.dataSource = self
        tableView.delegate = self

        scrollView.documentView = tableView
        stackView.addArrangedSubview(scrollView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
    }

    func setConnection(_ connection: DatabaseConnection) {
        currentConnection = connection
        addButton.isEnabled = true
        loadTables()
    }

    func clearConnection() {
        currentConnection = nil
        tables = []
        filteredTables = []
        addButton.isEnabled = false
        tableView.reloadData()
    }

    func refresh() {
        loadTables()
    }

    private func loadTables() {
        guard let connection = currentConnection else {
            tables = []
            filteredTables = []
            tableView.reloadData()
            return
        }

        do {
            tables = try connection.getTables()
            filterTables()
        } catch {
            tables = []
            filteredTables = []
            tableView.reloadData()
            showError(message: error.localizedDescription)
        }
    }

    private func filterTables() {
        let searchText = searchField.stringValue.lowercased()
        if searchText.isEmpty {
            filteredTables = tables
        } else {
            filteredTables = tables.filter { $0.name.lowercased().contains(searchText) }
        }
        tableView.reloadData()
    }

    @objc private func searchTextChanged() {
        filterTables()
    }

    @objc private func tableDoubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0 && row < filteredTables.count else { return }
        onTableSelected?(filteredTables[row])
    }

    // MARK: - Table Operations

    private func createTableMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Rename Table", action: #selector(renameTable), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Empty Table", action: #selector(emptyTable), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Delete Table", action: #selector(deleteTable), keyEquivalent: ""))
        return menu
    }

    @objc private func addTable() {
        guard let connection = currentConnection else { return }

        let alert = NSAlert()
        alert.messageText = "Create New Table"
        alert.informativeText = "Enter table name:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = "new_table"
        alert.accessoryView = textField

        alert.beginSheetModal(for: view.window!) { response in
            if response == .alertFirstButtonReturn {
                let name = textField.stringValue.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }

                let sql = "CREATE TABLE \(name) (id INTEGER PRIMARY KEY)"
                do {
                    try connection.executeUpdate(sql)
                    self.loadTables()
                } catch {
                    self.showError(message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func renameTable() {
        guard let connection = currentConnection else { return }
        let row = tableView.clickedRow
        guard row >= 0 && row < filteredTables.count else { return }
        let tableInfo = filteredTables[row]

        guard tableInfo.type == .table else {
            showError(message: "Cannot rename views")
            return
        }

        let alert = NSAlert()
        alert.messageText = "Rename Table"
        alert.informativeText = "Enter new name for '\(tableInfo.name)':"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = tableInfo.name
        alert.accessoryView = textField

        alert.beginSheetModal(for: view.window!) { response in
            if response == .alertFirstButtonReturn {
                let newName = textField.stringValue.trimmingCharacters(in: .whitespaces)
                guard !newName.isEmpty, newName != tableInfo.name else { return }

                let sql = "ALTER TABLE \(tableInfo.name) RENAME TO \(newName)"
                do {
                    try connection.executeUpdate(sql)
                    self.loadTables()
                } catch {
                    self.showError(message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func emptyTable() {
        guard let connection = currentConnection else { return }
        let row = tableView.clickedRow
        guard row >= 0 && row < filteredTables.count else { return }
        let tableInfo = filteredTables[row]

        guard tableInfo.type == .table else {
            showError(message: "Cannot empty views")
            return
        }

        let alert = NSAlert()
        alert.messageText = "Empty Table"
        alert.informativeText = "Are you sure you want to delete all rows from '\(tableInfo.name)'? This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Empty")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: view.window!) { response in
            if response == .alertFirstButtonReturn {
                let sql = "DELETE FROM \(tableInfo.name)"
                do {
                    try connection.executeUpdate(sql)
                    self.loadTables()
                } catch {
                    self.showError(message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func deleteTable() {
        guard let connection = currentConnection else { return }
        let row = tableView.clickedRow
        guard row >= 0 && row < filteredTables.count else { return }
        let tableInfo = filteredTables[row]

        let alert = NSAlert()
        alert.messageText = "Delete \(tableInfo.type == .view ? "View" : "Table")"
        alert.informativeText = "Are you sure you want to delete '\(tableInfo.name)'? This cannot be undone."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: view.window!) { response in
            if response == .alertFirstButtonReturn {
                let sql = "DROP \(tableInfo.type == .view ? "VIEW" : "TABLE") \(tableInfo.name)"
                do {
                    try connection.executeUpdate(sql)
                    self.loadTables()
                } catch {
                    self.showError(message: error.localizedDescription)
                }
            }
        }
    }

    private func showError(message: String) {
        if let window = view.window {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = message
            alert.alertStyle = .critical
            alert.beginSheetModal(for: window)
        }
    }
}

extension SidebarViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredTables.count
    }
}

extension SidebarViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredTables.count else { return nil }

        let tableInfo = filteredTables[row]
        let identifier = NSUserInterfaceItemIdentifier("TableCell")

        var cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier

            let textField = NSTextField()
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.isEditable = false
            textField.isSelectable = false
            cell?.textField = textField
            cell?.addSubview(textField)

            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }

        cell?.textField?.stringValue = tableInfo.name
        cell?.imageView?.image = tableInfo.type == .view
            ? NSImage(systemSymbolName: "eye", accessibilityDescription: "View")
            : NSImage(systemSymbolName: "tablecells", accessibilityDescription: "Table")

        return cell
    }
}
