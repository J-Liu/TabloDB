// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class SQLEditorViewController: NSViewController {
    private var textView: NSTextView!
    private var scrollView: NSScrollView!
    private var resultTableView: NSTableView!
    private var resultScrollView: NSScrollView!
    private var executeButton: NSButton!
    private var statusLabel: NSTextField!
    private var resultContainer: NSView!

    private var currentConnection: DatabaseConnection?
    private var queryResult: QueryResult?

    override func loadView() {
        view = NSView()

        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.spacing = 8
        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])

        // SQL Editor
        let editorLabel = NSTextField(labelWithString: "SQL Query:")
        mainStack.addArrangedSubview(editorLabel)

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView = NSTextView()
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.minSize = NSSize(width: 0, height: 100)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView

        let editorHeightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 150)
        editorHeightConstraint.priority = .defaultHigh
        editorHeightConstraint.isActive = true

        mainStack.addArrangedSubview(scrollView)

        // Execute button and status
        let toolbarStack = NSStackView()
        toolbarStack.orientation = .horizontal
        toolbarStack.spacing = 8

        executeButton = NSButton(title: "Execute (⌘+Enter)", target: self, action: #selector(executeSQL))
        executeButton.isEnabled = false

        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.isSelectable = false

        toolbarStack.addArrangedSubview(executeButton)
        toolbarStack.addArrangedSubview(NSView())
        toolbarStack.addArrangedSubview(statusLabel)

        mainStack.addArrangedSubview(toolbarStack)

        // Results
        resultContainer = NSView()
        resultContainer.translatesAutoresizingMaskIntoConstraints = false
        resultContainer.wantsLayer = true

        resultScrollView = NSScrollView()
        resultScrollView.hasVerticalScroller = true
        resultScrollView.hasHorizontalScroller = true
        resultScrollView.borderType = .bezelBorder
        resultScrollView.translatesAutoresizingMaskIntoConstraints = false

        resultTableView = NSTableView()
        resultTableView.style = .fullWidth
        resultTableView.allowsColumnResizing = true
        resultTableView.usesAlternatingRowBackgroundColors = true

        resultTableView.dataSource = self
        resultTableView.delegate = self

        resultScrollView.documentView = resultTableView
        resultContainer.addSubview(resultScrollView)

        NSLayoutConstraint.activate([
            resultScrollView.topAnchor.constraint(equalTo: resultContainer.topAnchor),
            resultScrollView.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor),
            resultScrollView.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor),
            resultScrollView.bottomAnchor.constraint(equalTo: resultContainer.bottomAnchor)
        ])

        mainStack.addArrangedSubview(resultContainer)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true

        // Add keyboard shortcut
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.keyCode == 36 { // Enter key
                self.executeSQL()
                return nil
            }
            return event
        }
    }

    func setConnection(_ connection: DatabaseConnection?) {
        currentConnection = connection
        executeButton.isEnabled = connection != nil
    }

    @objc private func executeSQL() {
        guard let connection = currentConnection else { return }

        let sql = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sql.isEmpty else { return }

        statusLabel.stringValue = "Executing..."

        DispatchQueue.global().async {
            do {
                let result = try connection.executeQuery(sql)
                DispatchQueue.main.async {
                    self.queryResult = result
                    if let error = result.error, !error.isEmpty {
                        self.statusLabel.stringValue = "Error: \(error)"
                        self.clearResults()
                    } else {
                        self.statusLabel.stringValue = "\(result.rows.count) row(s) returned"
                        self.updateResults()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusLabel.stringValue = "Error: \(error.localizedDescription)"
                    self.clearResults()
                }
            }
        }
    }

    private func updateResults() {
        while resultTableView.tableColumns.count > 0 {
            resultTableView.removeTableColumn(resultTableView.tableColumns[0])
        }

        guard let result = queryResult else { return }

        for (index, columnName) in result.columns.enumerated() {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col_\(index)"))
            column.title = columnName
            column.minWidth = 80
            column.width = 150
            resultTableView.addTableColumn(column)
        }

        resultTableView.reloadData()
    }

    private func clearResults() {
        while resultTableView.tableColumns.count > 0 {
            resultTableView.removeTableColumn(resultTableView.tableColumns[0])
        }
        queryResult = nil
        resultTableView.reloadData()
    }
}

extension SQLEditorViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return queryResult?.rows.count ?? 0
    }
}

extension SQLEditorViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let result = queryResult, row < result.rows.count else { return nil }

        let columnIndex = Int(tableColumn?.identifier.rawValue.dropFirst(4) ?? "0") ?? 0
        guard columnIndex < result.columns.count else { return nil }

        let value = result.rows[row][columnIndex]
        let identifier = NSUserInterfaceItemIdentifier("ResultCell")

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
