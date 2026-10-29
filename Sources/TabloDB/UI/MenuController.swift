// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class MenuController {
    private let appDelegate: AppDelegate
    private var recentMenu: NSMenu!

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        setupMenus()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .languageChanged,
            object: nil
        )
    }

    private func setupMenus() {
        let mainMenu = NSMenu()

        let appName = ProcessInfo.processInfo.processName

        // App Menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu

        let aboutItem = NSMenuItem(title: L("menu.about", appName), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)

        appMenu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(title: L("menu.preferences"), action: #selector(showPreferences), keyEquivalent: ",")
        prefsItem.target = self
        appMenu.addItem(prefsItem)

        appMenu.addItem(NSMenuItem.separator())

        let checkUpdatesItem = NSMenuItem(title: L("menu.checkForUpdates"), action: #selector(checkForUpdates), keyEquivalent: "")
        checkUpdatesItem.target = self
        appMenu.addItem(checkUpdatesItem)

        appMenu.addItem(NSMenuItem.separator())

        appMenu.addItem(NSMenuItem(title: L("menu.hide", appName), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: L("menu.hideOthers"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").withKeyModifier(.option))
        appMenu.addItem(NSMenuItem(title: L("menu.showAll"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: L("menu.quit", appName), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        mainMenu.addItem(appMenuItem)

        // File Menu
        let fileMenu = NSMenu(title: L("menu.file"))
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu

        let newSQLiteItem = NSMenuItem(title: L("menu.newSQLite"), action: #selector(newSQLiteDatabase), keyEquivalent: "n")
        newSQLiteItem.target = self
        fileMenu.addItem(newSQLiteItem)

        let newDuckDBItem = NSMenuItem(title: L("menu.newDuckDB"), action: #selector(newDuckDBDatabase), keyEquivalent: "n")
        newDuckDBItem.target = self
        newDuckDBItem.keyEquivalentModifierMask = [.command, .option]
        fileMenu.addItem(newDuckDBItem)

        fileMenu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: L("menu.open"), action: #selector(openDatabase), keyEquivalent: "o")
        openItem.target = self
        fileMenu.addItem(openItem)

        let openCSVItem = NSMenuItem(title: L("menu.openCSV"), action: #selector(openCSVFile), keyEquivalent: "o")
        openCSVItem.target = self
        openCSVItem.keyEquivalentModifierMask = [.command, .option]
        fileMenu.addItem(openCSVItem)

        let openCSVDirItem = NSMenuItem(title: L("menu.openCSVDir"), action: #selector(openCSVDirectory), keyEquivalent: "")
        openCSVDirItem.target = self
        fileMenu.addItem(openCSVDirItem)

        let openParquetItem = NSMenuItem(title: L("menu.openParquet"), action: #selector(openParquetFile), keyEquivalent: "")
        openParquetItem.target = self
        fileMenu.addItem(openParquetItem)

        let openParquetDirItem = NSMenuItem(title: L("menu.openParquetDir"), action: #selector(openParquetDirectory), keyEquivalent: "")
        openParquetDirItem.target = self
        fileMenu.addItem(openParquetDirItem)

        let closeItem = NSMenuItem(title: L("menu.close"), action: #selector(closeDatabase), keyEquivalent: "")
        closeItem.target = self
        fileMenu.addItem(closeItem)

        fileMenu.addItem(NSMenuItem.separator())

        recentMenu = NSMenu(title: L("menu.recent"))
        let recentMenuItem = NSMenuItem(title: L("menu.recent"), action: nil, keyEquivalent: "")
        recentMenuItem.submenu = recentMenu
        fileMenu.addItem(recentMenuItem)

        fileMenu.addItem(NSMenuItem.separator())

        let exportItem = NSMenuItem(title: L("menu.export"), action: #selector(exportCSV), keyEquivalent: "e")
        exportItem.target = self
        fileMenu.addItem(exportItem)

        let importItem = NSMenuItem(title: L("menu.import"), action: #selector(importCSV), keyEquivalent: "i")
        importItem.target = self
        fileMenu.addItem(importItem)

        fileMenu.addItem(NSMenuItem.separator())

        let trashItem = NSMenuItem(title: L("menu.moveToTrash"), action: #selector(moveToTrash), keyEquivalent: "")
        trashItem.target = self
        fileMenu.addItem(trashItem)

        mainMenu.addItem(fileMenuItem)

        // Edit Menu
        let editMenu = NSMenu(title: L("menu.edit"))
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu

        editMenu.addItem(NSMenuItem(title: L("menu.undo"), action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: L("menu.redo"), action: Selector(("redo:")), keyEquivalent: "z").withKeyModifier(.shift))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: L("menu.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: L("menu.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: L("menu.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: L("menu.selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        mainMenu.addItem(editMenuItem)

        // View Menu
        let viewMenu = NSMenu(title: L("menu.view"))
        let viewMenuItem = NSMenuItem()
        viewMenuItem.submenu = viewMenu

        let refreshItem = NSMenuItem(title: L("menu.refresh"), action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        viewMenu.addItem(refreshItem)

        mainMenu.addItem(viewMenuItem)

        // Window Menu
        let windowMenu = NSMenu(title: L("menu.window"))
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu

        windowMenu.addItem(NSMenuItem(title: L("menu.minimize"), action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: L("menu.zoom"), action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(NSMenuItem(title: L("menu.bringAllToFront"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))

        mainMenu.addItem(windowMenuItem)

        NSApplication.shared.mainMenu = mainMenu
    }

    @objc private func languageDidChange() {
        setupMenus()
        updateRecentMenu()
    }

    func updateRecentMenu() {
        recentMenu.removeAllItems()

        let recent = DatabaseManager.shared.getRecentDatabases()
        if recent.isEmpty {
            recentMenu.addItem(NSMenuItem(title: L("menu.recent.none"), action: nil, keyEquivalent: ""))
        } else {
            for (path, type) in recent {
                let typeLabel = type == .sqlite ? "SQLite" : type == .duckdb ? "DuckDB" : type == .csv ? "CSV" : "Parquet"
                let item = NSMenuItem(title: "\(URL(fileURLWithPath: path).lastPathComponent) (\(typeLabel))", action: #selector(openRecentDatabase(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = ["path": path, "type": type.rawValue]
                recentMenu.addItem(item)
            }
            recentMenu.addItem(NSMenuItem.separator())
            let clearItem = NSMenuItem(title: L("menu.recent.clear"), action: #selector(clearRecentList), keyEquivalent: "")
            clearItem.target = self
            recentMenu.addItem(clearItem)
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

    @objc func openCSVFile() {
        appDelegate.openCSVFile()
    }

    @objc func openCSVDirectory() {
        appDelegate.openCSVDirectory()
    }

    @objc func openParquetFile() {
        appDelegate.openParquetFile()
    }

    @objc func openParquetDirectory() {
        appDelegate.openParquetDirectory()
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

    @objc func showAbout() {
        appDelegate.showSettings()
    }

    @objc func showPreferences() {
        appDelegate.showSettings()
    }

    @objc func checkForUpdates() {
        appDelegate.checkForUpdates()
    }
}

private extension NSMenuItem {
    func withKeyModifier(_ modifier: NSEvent.ModifierFlags) -> NSMenuItem {
        self.keyEquivalentModifierMask = modifier
        return self
    }
}
