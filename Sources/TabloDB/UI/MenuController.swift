// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class MenuController {
    private let appDelegate: AppDelegate

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        setupMenus()
    }

    private func setupMenus() {
        let mainMenu = NSMenu()

        // App Menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu

        let appName = ProcessInfo.processInfo.processName
        appMenu.addItem(NSMenuItem(title: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").withKeyModifier(.option))
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        mainMenu.addItem(appMenuItem)

        // File Menu
        let fileMenu = NSMenu(title: "File")
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu

        fileMenu.addItem(NSMenuItem(title: "New SQLite Database...", action: #selector(newSQLiteDatabase), keyEquivalent: "n"))
        fileMenu.addItem(NSMenuItem(title: "New DuckDB Database...", action: #selector(newDuckDBDatabase), keyEquivalent: "n").withKeyModifier(.option))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(NSMenuItem(title: "Open Database...", action: #selector(openDatabase), keyEquivalent: "o"))
        fileMenu.addItem(NSMenuItem(title: "Close Database", action: #selector(closeDatabase), keyEquivalent: "w"))
        fileMenu.addItem(NSMenuItem.separator())

        // Recent Databases submenu
        let recentMenu = NSMenu(title: "Recent Databases")
        let recentMenuItem = NSMenuItem(title: "Recent Databases", action: nil, keyEquivalent: "")
        recentMenuItem.submenu = recentMenu
        fileMenu.addItem(recentMenuItem)

        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(NSMenuItem(title: "Export as CSV...", action: #selector(exportCSV), keyEquivalent: "e"))
        fileMenu.addItem(NSMenuItem(title: "Import CSV...", action: #selector(importCSV), keyEquivalent: "i"))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(NSMenuItem(title: "Move to Trash", action: #selector(moveToTrash), keyEquivalent: ""))

        mainMenu.addItem(fileMenuItem)

        // Edit Menu
        let editMenu = NSMenu(title: "Edit")
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu

        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z").withKeyModifier(.shift))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(copySelection), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        mainMenu.addItem(editMenuItem)

        // View Menu
        let viewMenu = NSMenu(title: "View")
        let viewMenuItem = NSMenuItem()
        viewMenuItem.submenu = viewMenu

        viewMenu.addItem(NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r"))

        mainMenu.addItem(viewMenuItem)

        // Window Menu
        let windowMenu = NSMenu(title: "Window")
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu

        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))

        mainMenu.addItem(windowMenuItem)

        NSApplication.shared.mainMenu = mainMenu
    }

    func updateRecentMenu() {
        guard let fileMenu = NSApplication.shared.mainMenu?.item(withTitle: "File")?.submenu,
              let recentMenu = fileMenu.item(withTitle: "Recent Databases")?.submenu else {
            return
        }

        recentMenu.removeAllItems()

        let recent = DatabaseManager.shared.getRecentDatabases()
        if recent.isEmpty {
            recentMenu.addItem(NSMenuItem(title: "No Recent Databases", action: nil, keyEquivalent: ""))
        } else {
            for (path, type) in recent {
                let item = NSMenuItem(title: "\(URL(fileURLWithPath: path).lastPathComponent) (\(type == .sqlite ? "SQLite" : "DuckDB"))", action: #selector(openRecentDatabase(_:)), keyEquivalent: "")
                item.representedObject = ["path": path, "type": type == .sqlite ? "sqlite" : "duckdb"]
                recentMenu.addItem(item)
            }
            recentMenu.addItem(NSMenuItem.separator())
            recentMenu.addItem(NSMenuItem(title: "Clear Recent List", action: #selector(clearRecentList), keyEquivalent: ""))
        }
    }

    // MARK: - Actions

    @objc func newSQLiteDatabase() {
        appDelegate.createNewDatabase(type: .sqlite)
    }

    @objc func newDuckDBDatabase() {
        appDelegate.createNewDatabase(type: .duckdb)
    }

    @objc func openDatabase() {
        appDelegate.openDatabase()
    }

    @objc func closeDatabase() {
        appDelegate.closeCurrentDatabase()
    }

    @objc func openRecentDatabase(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String],
              let path = info["path"],
              let typeStr = info["type"],
              let type = DatabaseType(rawValue: typeStr) else {
            return
        }
        appDelegate.openDatabase(at: path, type: type)
    }

    @objc func clearRecentList() {
        UserDefaults.standard.removeObject(forKey: "recentDatabases")
        updateRecentMenu()
    }

    @objc func moveToTrash() {
        appDelegate.moveToTrash()
    }

    @objc func refresh() {
        appDelegate.refresh()
    }

    @objc func exportCSV() {
        appDelegate.exportCSV()
    }

    @objc func importCSV() {
        appDelegate.importCSV()
    }

    @objc func copySelection() {
        appDelegate.copySelection()
    }
}

private extension NSMenuItem {
    func withKeyModifier(_ modifier: NSEvent.ModifierFlags) -> NSMenuItem {
        self.keyEquivalentModifierMask = modifier
        return self
    }
}
