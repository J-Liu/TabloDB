// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?
    private var menuController: MenuController?
    private var windowController: MainWindowController?
    private var settingsWindowController: SettingsWindowController?

    lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: self
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureUpdateCheck()
        menuController = MenuController(appDelegate: self)
        windowController = MainWindowController()
        windowController?.showWindow(nil)
        mainWindow = windowController?.window
        menuController?.updateRecentMenu()
    }

    private func configureUpdateCheck() {
        let savedInterval = UserDefaults.standard.double(forKey: "settings.updateCheckInterval")
        let interval: TimeInterval
        if !UserDefaults.standard.bool(forKey: "settings.updateCheckIntervalSet") {
            interval = 604800
        } else {
            interval = savedInterval
        }

        let updater = updaterController.updater
        if interval < 0 {
            updater.automaticallyChecksForUpdates = false
        } else if interval == 0 {
            updater.automaticallyChecksForUpdates = false
            updater.checkForUpdatesInBackground()
        } else {
            updater.automaticallyChecksForUpdates = true
            updater.updateCheckInterval = interval
        }

        if !UserDefaults.standard.bool(forKey: "settings.updateCheckIntervalSet") {
            UserDefaults.standard.set(true, forKey: "settings.updateCheckIntervalSet")
            UserDefaults.standard.set(interval, forKey: "settings.updateCheckInterval")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let keepRunning = UserDefaults.standard.object(forKey: "quitOnClose") as? Bool ?? true
        return !keepRunning
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
        savePanel.title = L("dialog.new\(type == .sqlite ? "SQLite" : "DuckDB")")
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
        openPanel.title = L("dialog.open")
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

    func openCSVFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = L("dialog.openCSV")
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.allowedContentTypes = [
            .init(filenameExtension: "csv") ?? .data,
            .init(filenameExtension: "tsv") ?? .data
        ]

        openPanel.begin { [weak self] response in
            guard response == .OK, let url = openPanel.url else { return }
            self?.openDatabase(at: url.path, type: .csv)
        }
    }

    func openCSVDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.title = L("dialog.openCSVDir")
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false

        openPanel.begin { [weak self] response in
            guard response == .OK, let url = openPanel.url else { return }
            self?.openDatabase(at: url.path, type: .csv)
        }
    }

    func openParquetFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = L("dialog.openParquet")
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.allowedContentTypes = [
            .init(filenameExtension: "parquet") ?? .data,
            .init(filenameExtension: "parq") ?? .data
        ]

        openPanel.begin { [weak self] response in
            guard response == .OK, let url = openPanel.url else { return }
            self?.openDatabase(at: url.path, type: .parquet)
        }
    }

    func openParquetDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.title = L("dialog.openParquetDir")
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false

        openPanel.begin { [weak self] response in
            guard response == .OK, let url = openPanel.url else { return }
            self?.openDatabase(at: url.path, type: .parquet)
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

    func copySelection() {
        windowController?.copySelection()
    }

    func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = L("table.error")
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
}

extension AppDelegate: SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool {
        return true
    }
}
