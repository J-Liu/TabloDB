// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class MainWindowController: NSWindowController {
    private var splitViewController: NSSplitViewController!
    private var sidebarController: SidebarViewController!
    private var contentController: ContentViewController!

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
        contentController = ContentViewController()

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 200
        sidebarItem.canCollapse = true

        let contentItem = NSSplitViewItem(viewController: contentController)

        splitViewController.addSplitViewItem(sidebarItem)
        splitViewController.addSplitViewItem(contentItem)

        window?.contentViewController = splitViewController

        sidebarController.onTableSelected = { [weak self] tableInfo in
            self?.contentController.displayTable(tableInfo)
        }
    }

    func setActiveConnection(_ connection: DatabaseConnection) {
        sidebarController.setConnection(connection)
        window?.title = "\(connection.displayName) — TabloDB"
    }

    func closeCurrentDatabase() {
        if let connection = sidebarController.currentConnection {
            DatabaseManager.shared.closeDatabase(connection)
        }
        sidebarController.clearConnection()
        window?.title = "TabloDB"
    }

    func moveSelectedDatabaseToTrash() {
        // TODO: Implement when we have a database list view
    }

    func refresh() {
        sidebarController.refresh()
        contentController.refresh()
    }
}