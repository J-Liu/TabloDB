// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class MainWindowController: NSWindowController {
    private var splitViewController: NSSplitViewController!
    private var sidebarController: SidebarViewController!
    private var contentController: ContentViewController!
    private var sqlEditorController: SQLEditorViewController!
    private var tabViewController: NSTabViewController!
    private var dataTab: NSTabViewItem!
    private var sqlTab: NSTabViewItem!

    init() {
        LLog("MainWindowController.init() - START")

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1024, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        LLog("Window created with contentRect: \(window.contentRect(forFrameRect: NSRect(x: 0, y: 0, width: 1024, height: 800)))")

        window.title = "TabloDB"
        window.minSize = NSSize(width: 600, height: 400)

        super.init(window: window)
        LLog("After super.init - window frame: \(window.frame)")

        setupSplitView()
        LLog("After setupSplitView - window frame: \(window.frame)")

        // Force correct window size after contentViewController is set
        window.setFrame(NSRect(x: 0, y: 0, width: 1024, height: 800), display: true)
        LLog("After forced setFrame - window frame: \(window.frame)")

        window.center()
        LLog("After center() - window frame: \(window.frame)")

        LLog("MainWindowController.init() - END")
        LLog("Final window size: \(window.frame.width) x \(window.frame.height)")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .languageChanged,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSplitView() {
        splitViewController = NSSplitViewController()

        sidebarController = SidebarViewController()

        tabViewController = NSTabViewController()
        tabViewController.tabStyle = .toolbar

        contentController = ContentViewController()
        sqlEditorController = SQLEditorViewController()

        dataTab = NSTabViewItem(viewController: contentController)
        dataTab.label = L("tab.data")
        dataTab.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: nil)

        sqlTab = NSTabViewItem(viewController: sqlEditorController)
        sqlTab.label = L("tab.sql")
        sqlTab.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)

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
            self?.tabViewController.selectedTabViewItemIndex = 0
        }

        sidebarController.onDatabaseSelected = { [weak self] connection in
            self?.contentController.displayDatabaseOverview(connection)
            self?.tabViewController.selectedTabViewItemIndex = 0
        }

        contentController.onTableDoubleClicked = { [weak self] tableInfo in
            self?.contentController.displayTable(tableInfo)
        }
    }

    @objc private func languageDidChange() {
        dataTab.label = L("tab.data")
        sqlTab.label = L("tab.sql")
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
    }

    func refresh() {
        sidebarController.refresh()
        contentController.refresh()
    }

    func exportCurrentTable() {
        guard let result = contentController.getCurrentQueryResult(),
              let tableName = contentController.getCurrentTableName() else {
            let alert = NSAlert()
            alert.messageText = L("error.noData")
            alert.informativeText = L("error.noData.message")
            alert.alertStyle = .informational
            alert.runModal()
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = L("dialog.export")
        savePanel.allowedContentTypes = [.init(filenameExtension: "csv") ?? .data]
        savePanel.nameFieldStringValue = "\(tableName).csv"

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            do {
                try CSVExporter.exportTableData(result: result, to: url)
            } catch {
                let alert = NSAlert()
                alert.messageText = L("error.exportFailed")
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }

    func importCSV() {
        guard sidebarController.currentConnection != nil else {
            let alert = NSAlert()
            alert.messageText = L("error.noDatabase")
            alert.informativeText = L("error.noDatabase.message")
            alert.alertStyle = .informational
            alert.runModal()
            return
        }

        let openPanel = NSOpenPanel()
        openPanel.title = L("dialog.import")
        openPanel.allowedContentTypes = [.init(filenameExtension: "csv") ?? .data]

        openPanel.begin { [weak self] response in
            guard response == .OK, let url = openPanel.url else { return }

            do {
                let result = try CSVImporter.importCSV(from: url, into: self!.sidebarController.currentConnection!)
                self?.sidebarController.refresh()

                let alert = NSAlert()
                alert.messageText = L("success.import")
                alert.informativeText = L("success.import.message", result.rowCount, result.tableName)
                alert.alertStyle = .informational
                alert.runModal()
            } catch {
                let alert = NSAlert()
                alert.messageText = L("error.importFailed")
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }

    func copySelection() {
        contentController.copySelectedCells()
    }
}
