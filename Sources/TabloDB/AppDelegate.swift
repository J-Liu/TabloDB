// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import Sparkle

private var pathInputKey: UInt8 = 0
private var manualPathKey: UInt8 = 0

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
        LLog("AppDelegate.applicationDidFinishLaunching - START")

        configureUpdateCheck()
        menuController = MenuController(appDelegate: self)

        LLog("Creating MainWindowController")
        windowController = MainWindowController()

        LLog("Calling showWindow")
        windowController?.showWindow(nil)

        LLog("Window frame after showWindow: \(windowController?.window?.frame ?? .zero)")

        mainWindow = windowController?.window
        menuController?.updateRecentMenu()

        LLog("AppDelegate.applicationDidFinishLaunching - END")
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        LLog("applicationShouldHandleReopen - hasVisibleWindows: \(flag)")

        if !flag {
            // If windowController is nil or window is nil, create new
            if windowController == nil || windowController?.window == nil {
                LLog("Creating new MainWindowController")
                windowController = MainWindowController()
            }
            windowController?.showWindow(nil)
            windowController?.window?.makeKeyAndOrderFront(nil)
            LLog("Window shown - frame: \(windowController?.window?.frame ?? .zero)")
        }
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
        openPanel.accessoryView = createPathInputAccessoryView(for: openPanel)

        openPanel.begin { [weak self] response in
            guard response == .OK else { return }
            let url = objc_getAssociatedObject(openPanel, &manualPathKey) as? URL ?? openPanel.url
            guard let url = url else { return }
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
        openPanel.accessoryView = createPathInputAccessoryView(for: openPanel)

        openPanel.begin { [weak self] response in
            guard response == .OK else { return }
            let url = objc_getAssociatedObject(openPanel, &manualPathKey) as? URL ?? openPanel.url
            guard let url = url else { return }
            self?.openDatabase(at: url.path, type: .csv)
        }
    }

    func openCSVDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.title = L("dialog.openCSVDir")
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.accessoryView = createPathInputAccessoryView(for: openPanel)

        openPanel.begin { [weak self] response in
            guard response == .OK else { return }
            let url = objc_getAssociatedObject(openPanel, &manualPathKey) as? URL ?? openPanel.url
            guard let url = url else { return }
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
        openPanel.accessoryView = createPathInputAccessoryView(for: openPanel)

        openPanel.begin { [weak self] response in
            guard response == .OK else { return }
            let url = objc_getAssociatedObject(openPanel, &manualPathKey) as? URL ?? openPanel.url
            guard let url = url else { return }
            self?.openDatabase(at: url.path, type: .parquet)
        }
    }

    func openParquetDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.title = L("dialog.openParquetDir")
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.accessoryView = createPathInputAccessoryView(for: openPanel)

        openPanel.begin { [weak self] response in
            guard response == .OK else { return }
            let url = objc_getAssociatedObject(openPanel, &manualPathKey) as? URL ?? openPanel.url
            guard let url = url else { return }
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

    private func createPathInputAccessoryView(for openPanel: NSOpenPanel) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 32))

        let label = NSTextField(labelWithString: L("dialog.pathLabel"))
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        let pathField = NSTextField()
        pathField.placeholderString = L("dialog.pathPlaceholder")
        pathField.translatesAutoresizingMaskIntoConstraints = false
        pathField.delegate = self
        container.addSubview(pathField)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 60),

            pathField.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            pathField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pathField.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        objc_setAssociatedObject(pathField, &pathInputKey, openPanel, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        return container
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

extension AppDelegate: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSTextView.insertNewline(_:)) {
            let path = control.stringValue
            let expandedPath = (path as NSString).expandingTildeInPath

            if FileManager.default.fileExists(atPath: expandedPath) {
                let url = URL(fileURLWithPath: expandedPath)
                if let openPanel = objc_getAssociatedObject(control, &pathInputKey) as? NSOpenPanel {
                    objc_setAssociatedObject(openPanel, &manualPathKey, url, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

                    // Select the file in the panel's directory and filename fields
                    openPanel.directoryURL = url.deletingLastPathComponent()
                    openPanel.nameFieldStringValue = url.lastPathComponent

                    // Trigger the OK response
                    if let sheetParent = openPanel.sheetParent {
                        sheetParent.endSheet(openPanel, returnCode: .OK)
                    } else {
                        openPanel.close()
                        NSApp.stopModal(withCode: .OK)
                    }
                }
            }
            return true
        }
        return false
    }
}
