// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import Sparkle

class SettingsWindowController: NSWindowController {
    private var tabView: NSTabView!
    private var generalTab: NSView!
    private var aboutTab: NSView!
    private var languagePopup: NSPopUpButton!
    private var updateCheckPopup: NSPopUpButton!
    private var versionLabel: NSTextField!
    private var copyrightLabel: NSTextField!
    private var descriptionLabel: NSTextField!
    private var nameLabel: NSTextField!
    private var githubButton: NSButton!
    private var checkUpdatesButton: NSButton!

    private let labelWidth: CGFloat = 120
    private let controlWidth: CGFloat = 200
    private let rowSpacing: CGFloat = 16

    init() {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let width: CGFloat = 550
        let height: CGFloat = 450
        let x = screenFrame.midX - width / 2
        let y = screenFrame.midY - height / 2
        let frame = NSRect(x: x, y: y, width: width, height: height)

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L("settings.title")
        window.minSize = NSSize(width: 450, height: 350)

        super.init(window: window)

        setupUI()
        setupKeyHandlers()

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

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        tabView = NSTabView(frame: contentView.bounds.insetBy(dx: 10, dy: 10))
        tabView.autoresizingMask = [.width, .height]

        recreateTabs()

        contentView.addSubview(tabView)
    }

    private func recreateTabs() {
        while let tab = tabView.tabViewItems.first {
            tabView.removeTabViewItem(tab)
        }

        generalTab = createGeneralTab()
        let generalItem = NSTabViewItem(identifier: "general")
        generalItem.label = L("settings.tab.general")
        generalItem.view = generalTab
        tabView.addTabViewItem(generalItem)

        aboutTab = createAboutTab()
        let aboutItem = NSTabViewItem(identifier: "about")
        aboutItem.label = L("settings.tab.about")
        aboutItem.view = aboutTab
        tabView.addTabViewItem(aboutItem)

        window?.title = L("settings.title")
    }

    @objc private func languageDidChange() {
        recreateTabs()
    }

    // MARK: - Layout Helpers

    private func wrapInTopAlignedContainer(_ stack: NSStackView) -> NSView {
        let container = NSView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor)
        ])
        return container
    }

    private func makeRow(label: String, control: NSView) -> NSStackView {
        let labelField = NSTextField(labelWithString: label)
        labelField.alignment = .right
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true

        control.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [labelField, control])
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        return row
    }

    private func makeVerticalStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = rowSpacing
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        return stack
    }

    // MARK: - General Tab

    private func createGeneralTab() -> NSView {
        let stack = makeVerticalStack()

        languagePopup = NSPopUpButton()
        for language in AppLanguage.allCases {
            languagePopup.addItem(withTitle: language.displayName)
            languagePopup.lastItem?.representedObject = language
        }
        let current = LocalizationManager.shared.currentLanguage
        if let index = AppLanguage.allCases.firstIndex(of: current) {
            languagePopup.selectItem(at: index)
        }
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged(_:))
        languagePopup.widthAnchor.constraint(equalToConstant: controlWidth).isActive = true
        stack.addArrangedSubview(makeRow(label: L("settings.language"), control: languagePopup))

        updateCheckPopup = NSPopUpButton()
        let frequencies: [(key: String, interval: TimeInterval)] = [
            ("settings.updateCheck.atStartup", 0),
            ("settings.updateCheck.daily", 86400),
            ("settings.updateCheck.weekly", 604800),
            ("settings.updateCheck.monthly", 2592000),
            ("settings.updateCheck.never", -1)
        ]
        for freq in frequencies {
            updateCheckPopup.addItem(withTitle: L(freq.key))
            updateCheckPopup.lastItem?.representedObject = freq.interval
        }
        let savedInterval = UserDefaults.standard.double(forKey: "settings.updateCheckInterval")
        let selectedIndex: Int
        if savedInterval < 0 {
            selectedIndex = 4
        } else if savedInterval == 0 {
            selectedIndex = 0
        } else if savedInterval <= 86400 {
            selectedIndex = 1
        } else if savedInterval <= 604800 {
            selectedIndex = 2
        } else {
            selectedIndex = 3
        }
        updateCheckPopup.selectItem(at: selectedIndex)
        updateCheckPopup.target = self
        updateCheckPopup.action = #selector(updateCheckFrequencyChanged(_:))
        updateCheckPopup.widthAnchor.constraint(equalToConstant: controlWidth).isActive = true

        checkUpdatesButton = NSButton(title: L("settings.updateCheck.now"), target: self, action: #selector(checkForUpdatesNow))
        let updateCheckRow = NSStackView(views: [updateCheckPopup, checkUpdatesButton])
        updateCheckRow.orientation = .horizontal
        updateCheckRow.spacing = 8
        stack.addArrangedSubview(makeRow(label: L("settings.updateCheck"), control: updateCheckRow))

        return wrapInTopAlignedContainer(stack)
    }

    // MARK: - About Tab

    private func createAboutTab() -> NSView {
        let container = NSView()

        let appIcon = NSImageView()
        if let icnsPath = Bundle.main.path(forResource: "TabloDB", ofType: "icns"),
           let image = NSImage(contentsOfFile: icnsPath) {
            appIcon.image = image
        } else if let image = NSImage(named: "NSApplicationIcon") {
            appIcon.image = image
        } else {
            appIcon.image = NSImage(systemSymbolName: "cylinder.split.1x2", accessibilityDescription: nil)
            appIcon.contentTintColor = .controlAccentColor
        }
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        appIcon.widthAnchor.constraint(equalToConstant: 80).isActive = true
        appIcon.heightAnchor.constraint(equalToConstant: 80).isActive = true
        container.addSubview(appIcon)

        nameLabel = NSTextField(labelWithString: "TabloDB")
        nameLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        nameLabel.alignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        versionLabel = NSTextField(labelWithString: "\(L("settings.about.version")) \(version) (\(build))")
        versionLabel.alignment = .center
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(versionLabel)

        copyrightLabel = NSTextField(labelWithString: L("settings.about.copyright"))
        copyrightLabel.alignment = .center
        copyrightLabel.textColor = .secondaryLabelColor
        copyrightLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(copyrightLabel)

        descriptionLabel = NSTextField(wrappingLabelWithString: L("settings.about.description"))
        descriptionLabel.alignment = .center
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(descriptionLabel)

        githubButton = NSButton(title: "github.com/J-Liu/TabloDB", target: self, action: #selector(openGitHub))
        githubButton.bezelStyle = .rounded
        githubButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(githubButton)

        NSLayoutConstraint.activate([
            appIcon.topAnchor.constraint(equalTo: container.topAnchor, constant: 40),
            appIcon.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            nameLabel.topAnchor.constraint(equalTo: appIcon.bottomAnchor, constant: 16),
            nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            versionLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            versionLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            copyrightLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 8),
            copyrightLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: copyrightLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 40),
            descriptionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -40),
            descriptionLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            githubButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 24),
            githubButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            githubButton.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -20)
        ])

        return container
    }

    private func setupKeyHandlers() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.window?.isVisible == true else { return event }
            if event.keyCode == 53 {
                self.window?.close()
                return nil
            }
            if event.modifierFlags.contains(.command) && event.keyCode == 13 {
                self.window?.close()
                return nil
            }
            return event
        }
    }

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        guard let selected = sender.selectedItem?.representedObject as? AppLanguage else { return }
        LocalizationManager.shared.currentLanguage = selected
    }

    @objc private func updateCheckFrequencyChanged(_ sender: NSPopUpButton) {
        guard let interval = sender.selectedItem?.representedObject as? TimeInterval else { return }
        UserDefaults.standard.set(interval, forKey: "settings.updateCheckInterval")

        if let appDelegate = NSApp.delegate as? AppDelegate {
            let updater = appDelegate.updaterController.updater
            if interval < 0 {
                updater.automaticallyChecksForUpdates = false
            } else if interval == 0 {
                updater.automaticallyChecksForUpdates = false
            } else {
                updater.automaticallyChecksForUpdates = true
                updater.updateCheckInterval = interval
            }
        }
    }

    @objc private func checkForUpdatesNow() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.updaterController.checkForUpdates(nil)
        }
    }

    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/J-Liu/TabloDB") {
            NSWorkspace.shared.open(url)
        }
    }
}
