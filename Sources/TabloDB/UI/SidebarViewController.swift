// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

enum SidebarItem {
    case database(name: String, connection: DatabaseConnection)
    case table(TableInfo)

    var isDatabase: Bool {
        if case .database = self { return true }
        return false
    }

    var name: String {
        switch self {
        case .database(let name, _): return name
        case .table(let tableInfo): return tableInfo.name
        }
    }
}

class SidebarViewController: NSViewController {
    var onTableSelected: ((TableInfo) -> Void)?
    var onDatabaseSelected: ((DatabaseConnection) -> Void)?

    private var outlineView: NSOutlineView!
    private var searchField: NSSearchField!
    private var addButton: NSButton!
    private var rootItem: SidebarItem?
    private var tables: [TableInfo] = []
    private var filteredTables: [TableInfo] = []
    private(set) var currentConnection: DatabaseConnection?
    private var tableColumn: NSTableColumn!

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

        let searchContainer = NSView()
        searchContainer.translatesAutoresizingMaskIntoConstraints = false

        searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = L("sidebar.search.placeholder")
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

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        outlineView = NSOutlineView()
        outlineView.style = .sourceList
        outlineView.headerView = nil
        outlineView.allowsEmptySelection = true
        outlineView.allowsMultipleSelection = false
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.doubleAction = #selector(itemDoubleClicked)
        outlineView.menu = createTableMenu()

        tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        tableColumn.title = L("sidebar.tables")
        outlineView.addTableColumn(tableColumn)

        scrollView.documentView = outlineView
        stackView.addArrangedSubview(scrollView)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .languageChanged,
            object: nil
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
    }

    @objc private func languageDidChange() {
        searchField.placeholderString = L("sidebar.search.placeholder")
        tableColumn.title = L("sidebar.tables")
    }

    func setConnection(_ connection: DatabaseConnection) {
        currentConnection = connection
        if isViewLoaded {
            addButton.isEnabled = true
        }
        loadTables()
    }

    func clearConnection() {
        currentConnection = nil
        rootItem = nil
        tables = []
        filteredTables = []
        if isViewLoaded {
            addButton.isEnabled = false
            outlineView.reloadData()
        }
    }

    func refresh() {
        loadTables()
    }

    private func loadTables() {
        guard let connection = currentConnection else {
            rootItem = nil
            tables = []
            filteredTables = []
            outlineView.reloadData()
            return
        }

        do {
            tables = try connection.getTables()
            filterTables()

            rootItem = .database(name: connection.displayName, connection: connection)
            outlineView.reloadData()

            // Expand the database item by default
            if let root = rootItem {
                let index = outlineView.row(forItem: root)
                if index >= 0 {
                    outlineView.expandItem(root)
                }
            }
        } catch {
            rootItem = nil
            tables = []
            filteredTables = []
            outlineView.reloadData()
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
    }

    @objc private func searchTextChanged() {
        filterTables()
        outlineView.reloadData()
    }

    @objc private func itemDoubleClicked() {
        let row = outlineView.clickedRow
        guard let item = outlineView.item(atRow: row) as? SidebarItem else { return }

        switch item {
        case .database:
            // Double click on database - show all tables in grid
            if case .database(_, let connection) = item {
                onDatabaseSelected?(connection)
            }
        case .table(let tableInfo):
            // Double click on table - open table
            onTableSelected?(tableInfo)
        }
    }

    private func createTableMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: L("sidebar.menu.rename"), action: #selector(renameTable), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L("sidebar.menu.empty"), action: #selector(emptyTable), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L("sidebar.menu.delete"), action: #selector(deleteTable), keyEquivalent: ""))
        return menu
    }

    @objc private func addTable() {
        guard let connection = currentConnection else { return }

        let alert = NSAlert()
        alert.messageText = L("sidebar.newTable.title")
        alert.informativeText = L("sidebar.newTable.message")
        alert.addButton(withTitle: L("sidebar.newTable.create"))
        alert.addButton(withTitle: L("sidebar.newTable.cancel"))

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
        let row = outlineView.clickedRow
        guard let item = outlineView.item(atRow: row) as? SidebarItem,
              case .table(let tableInfo) = item else { return }

        guard tableInfo.type == .table else {
            showError(message: L("sidebar.error.cannotRenameView"))
            return
        }

        let alert = NSAlert()
        alert.messageText = L("sidebar.renameTable.title")
        alert.informativeText = L("sidebar.renameTable.message", tableInfo.name)
        alert.addButton(withTitle: L("sidebar.renameTable.rename"))
        alert.addButton(withTitle: L("sidebar.renameTable.cancel"))

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
        let row = outlineView.clickedRow
        guard let item = outlineView.item(atRow: row) as? SidebarItem,
              case .table(let tableInfo) = item else { return }

        guard tableInfo.type == .table else {
            showError(message: L("sidebar.error.cannotEmptyView"))
            return
        }

        let alert = NSAlert()
        alert.messageText = L("sidebar.emptyTable.title")
        alert.informativeText = L("sidebar.emptyTable.message", tableInfo.name)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("sidebar.emptyTable.empty"))
        alert.addButton(withTitle: L("sidebar.emptyTable.cancel"))

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
        let row = outlineView.clickedRow
        guard let item = outlineView.item(atRow: row) as? SidebarItem,
              case .table(let tableInfo) = item else { return }

        let alert = NSAlert()
        alert.messageText = L("sidebar.deleteTable.title", tableInfo.type == .view ? "View" : "Table")
        alert.informativeText = L("sidebar.deleteTable.message", tableInfo.name)
        alert.alertStyle = .critical
        alert.addButton(withTitle: L("sidebar.deleteTable.delete"))
        alert.addButton(withTitle: L("sidebar.deleteTable.cancel"))

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
            alert.messageText = L("table.error")
            alert.informativeText = message
            alert.alertStyle = .critical
            alert.beginSheetModal(for: window)
        }
    }
}

extension SidebarViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return rootItem != nil ? 1 : 0
        }
        if let sidebarItem = item as? SidebarItem, sidebarItem.isDatabase {
            return filteredTables.count
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return rootItem as Any
        }
        if let sidebarItem = item as? SidebarItem, sidebarItem.isDatabase {
            return SidebarItem.table(filteredTables[index])
        }
        return SidebarItem.table(filteredTables[index])
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let sidebarItem = item as? SidebarItem {
            return sidebarItem.isDatabase
        }
        return false
    }
}

extension SidebarViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let sidebarItem = item as? SidebarItem else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("TreeCell")

        var cell = outlineView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            cell?.imageView = imageView
            cell?.addSubview(imageView)

            let textField = NSTextField()
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.isEditable = false
            textField.isSelectable = false
            textField.lineBreakMode = .byTruncatingTail
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell?.textField = textField
            cell?.addSubview(textField)

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                imageView.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4),
                textField.topAnchor.constraint(equalTo: cell!.topAnchor),
                textField.bottomAnchor.constraint(equalTo: cell!.bottomAnchor)
            ])
        }

        switch sidebarItem {
        case .database(let name, _):
            cell?.textField?.stringValue = name
            cell?.imageView?.image = NSImage(systemSymbolName: "externaldrive.fill", accessibilityDescription: nil)
        case .table(let tableInfo):
            cell?.textField?.stringValue = tableInfo.name
            cell?.imageView?.image = tableInfo.type == .view
                ? NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
                : NSImage(systemSymbolName: "tablecells", accessibilityDescription: nil)
        }

        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView else { return }
        let row = outlineView.selectedRow
        guard row >= 0, let item = outlineView.item(atRow: row) as? SidebarItem else { return }

        switch item {
        case .database(_, let connection):
            // Single click on database - show all tables in grid
            onDatabaseSelected?(connection)
        case .table(let tableInfo):
            // Single click on table - open table
            onTableSelected?(tableInfo)
        }
    }
}
