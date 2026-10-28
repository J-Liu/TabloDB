// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class SidebarViewController: NSViewController {
    var onTableSelected: ((TableInfo) -> Void)?

    private var tableView: NSTableView!
    private var searchField: NSSearchField!
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

        // Search field
        searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search tables..."
        searchField.target = self
        searchField.action = #selector(searchTextChanged)
        searchField.bezelStyle = .roundedBezel

        let searchContainer = NSView()
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchField)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: searchContainer.topAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -8),
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
        loadTables()
    }

    func clearConnection() {
        currentConnection = nil
        tables = []
        filteredTables = []
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