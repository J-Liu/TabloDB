// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class MainWindowController: NSWindowController {
    private var splitViewController: NSSplitViewController!
    private var sidebarController: SidebarViewController!
    private var contentController: ContentViewController!
    private var sqlEditorController: SQLEditorViewController!
    private var tabViewController: NSTabViewController!

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "TabloDB"
        window.minSize = NSSize(width: 600, height: 400)

        super.init(window: window)

        setupSplitView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSplitView() {
        splitViewController = NSSplitViewController()

        sidebarController = SidebarViewController()

        // Create tab view controller for main content
        tabViewController = NSTabViewController()
        tabViewController.tabStyle = .toolbar

        contentController = ContentViewController()
        sqlEditorController = SQLEditorViewController()

        let dataTab = NSTabViewItem(viewController: contentController)
        dataTab.label = "Data"
        dataTab.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: "Data")

        let sqlTab = NSTabViewItem(viewController: sqlEditorController)
        sqlTab.label = "SQL"
        sqlTab.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "SQL")

        tabViewController.addTabViewItem(dataTab)
        tabViewController.addTabViewItem(sqlTab)

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 200
        sidebarItem.canCollapse = true

        let contentItem = NSSplitViewItem(viewController: tabViewController)

        splitViewController.addSplitViewItem(sidebarItem)
        splitViewController.addSplitViewItem(contentItem)

        window?.contentViewController = splitViewController

        sidebarController.onTableSelected = { [weak self] tableInfo in
            self?.contentController.displayTable(tableInfo)
            // Switch to data tab when table is selected
            self?.tabViewController.selectedTabViewItemIndex = 0
        }
    }

    func setActiveConnection(_ connection: DatabaseConnection) {
        sidebarController.setConnection(connection)
        sqlEditorController.setConnection(connection)
        window?.title = "\(connection.displayName) — TabloDB"
    }

    func closeCurrentDatabase() {
        if let connection = sidebarController.currentConnection {
            DatabaseManager.shared.closeDatabase(connection)
        }
        sidebarController.clearConnection()
        sqlEditorController.setConnection(nil)
        window?.title = "TabloDB"
    }

    func moveSelectedDatabaseToTrash() {
        // TODO: Implement when we have a database list view
    }

    func refresh() {
        sidebarController.refresh()
        contentController.refresh()
    }

    func exportCurrentTable() {
        guard let result = contentController.getCurrentQueryResult(),
              let tableName = contentController.getCurrentTableName() else {
            let alert = NSAlert()
            alert.messageText = "No Data"
            alert.informativeText = "Please select a table to export."
            alert.alertStyle = .informational
            alert.runModal()
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Export as CSV"
        savePanel.allowedContentTypes = [.init(filenameExtension: "csv") ?? .data]
        savePanel.nameFieldStringValue = "\(tableName).csv"

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            do {
                try CSVExporter.exportTableData(result: result, to: url)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }

    func importCSV() {
        guard sidebarController.currentConnection != nil else {
            let alert = NSAlert()
            alert.messageText = "No Database"
            alert.informativeText = "Please open a database first."
            alert.alertStyle = .informational
            alert.runModal()
            return
        }

        let openPanel = NSOpenPanel()
        openPanel.title = "Import CSV"
        openPanel.allowedContentTypes = [.init(filenameExtension: "csv") ?? .data]

        openPanel.begin { [weak self] response in
            guard response == .OK, let url = openPanel.url else { return }

            do {
                let result = try CSVImporter.importCSV(from: url, into: self!.sidebarController.currentConnection!)
                self?.sidebarController.refresh()

                let alert = NSAlert()
                alert.messageText = "Import Successful"
                alert.informativeText = "Imported \(result.rowCount) rows into table '\(result.tableName)'."
                alert.alertStyle = .informational
                alert.runModal()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Import Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }
}