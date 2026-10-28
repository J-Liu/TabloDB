// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class SettingsWindowController: NSWindowController {
    private var tabView: NSTabView!

    init() {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let width: CGFloat = 500
        let height: CGFloat = 400
        let x = screenFrame.midX - width / 2
        let y = screenFrame.midY - height / 2
        let frame = NSRect(x: x, y: y, width: width, height: height)

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.minSize = NSSize(width: 400, height: 300)

        super.init(window: window)

        setupUI()
        setupKeyHandlers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        tabView = NSTabView(frame: contentView.bounds.insetBy(dx: 10, dy: 10))
        tabView.autoresizingMask = [.width, .height]

        let aboutTab = createAboutTab()
        let aboutItem = NSTabViewItem(identifier: "about")
        aboutItem.label = "About"
        aboutItem.view = aboutTab
        tabView.addTabViewItem(aboutItem)

        contentView.addSubview(tabView)
    }

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

        let nameLabel = NSTextField(labelWithString: "TabloDB")
        nameLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        nameLabel.alignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let versionLabel = NSTextField(labelWithString: "Version \(version) (\(build))")
        versionLabel.alignment = .center
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(versionLabel)

        let copyrightLabel = NSTextField(labelWithString: "Copyright © 2026 Jia Liu")
        copyrightLabel.alignment = .center
        copyrightLabel.textColor = .secondaryLabelColor
        copyrightLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(copyrightLabel)

        let descriptionLabel = NSTextField(wrappingLabelWithString: "A native macOS database GUI for SQLite and DuckDB.")
        descriptionLabel.alignment = .center
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(descriptionLabel)

        let githubButton = NSButton(title: "github.com/J-Liu/TabloDB", target: self, action: #selector(openGitHub))
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

    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/J-Liu/TabloDB") {
            NSWorkspace.shared.open(url)
        }
    }
}
