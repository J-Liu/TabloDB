// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?
    private var menuController: MenuController?
    private var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuController = MenuController(appDelegate: self)
        windowController = MainWindowController()
        windowController?.showWindow(nil)
        mainWindow = windowController?.window
        menuController?.updateRecentMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let type: DatabaseType = filename.hasSuffix(".duckdb") ? .duckdb : .sqlite
        do {
            let connection = try DatabaseManager.shared.openDatabase(at: filename, type: type)
            windowController?.setActiveConnection(connection)
            menuController?.updateRecentMenu()
            return true
        } catch {
            showError(message: error.localizedDescription)
            return false
        }
    }

    // MARK: - Database Actions

    func createNewDatabase(type: DatabaseType) {
        let savePanel = NSSavePanel()
        savePanel.title = "New \(type == .sqlite ? "SQLite" : "DuckDB") Database"
        savePanel.allowedContentTypes = [.init(filenameExtension: type == .sqlite ? "sqlite" : "duckdb") ?? .data]
        savePanel.nameFieldStringValue = "Untitled.\(type == .sqlite ? "sqlite" : "duckdb")"

        savePanel.begin { [weak self] response in
            guard response == .OK, let url = savePanel.url else { return }
            do {
                let connection = try DatabaseManager.shared.createDatabase(at: url.path, type: type)
                self?.windowController?.setActiveConnection(connection)
                self?.menuController?.updateRecentMenu()
            } catch {
                self?.showError(message: error.localizedDescription)
            }
        }
    }

    func openDatabase() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Open Database"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.allowedContentTypes = [
            .init(filenameExtension: "sqlite") ?? .data,
            .init(filenameExtension: "db") ?? .data,
            .init(filenameExtension: "duckdb") ?? .data
        ]

        openPanel.begin { [weak self] response in
            guard response == .OK, let url = openPanel.url else { return }
            let type: DatabaseType = url.pathExtension == "duckdb" ? .duckdb : .sqlite
            self?.openDatabase(at: url.path, type: type)
        }
    }

    func openDatabase(at path: String, type: DatabaseType) {
        do {
            let connection = try DatabaseManager.shared.openDatabase(at: path, type: type)
            windowController?.setActiveConnection(connection)
            menuController?.updateRecentMenu()
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    func closeCurrentDatabase() {
        windowController?.closeCurrentDatabase()
    }

    func moveToTrash() {
        windowController?.moveSelectedDatabaseToTrash()
    }

    func refresh() {
        windowController?.refresh()
    }

    func exportCSV() {
        windowController?.exportCurrentTable()
    }

    func importCSV() {
        windowController?.importCSV()
    }

    func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
}