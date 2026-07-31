import AppKit
import Carbon

/// 轻量设置面板：快捷键录制、默认排序、登录启动
final class SettingsWindowController: NSWindowController {
    var onHotKeyChanged: ((HotKeyConfig) -> Void)?
    var onRequestRebuild: (() -> Void)?

    private let hotkeyButton = NSButton(title: "", target: nil, action: nil)
    private let sortPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let loginCheck = NSButton(checkboxWithTitle: "登录时自动启动", target: nil, action: nil)
    private let hintLabel = NSTextField(labelWithString: "")
    private var recording = false
    private var keyMonitor: Any?

    convenience init() {
        let win = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "设置"
        win.isFloatingPanel = true
        win.level = .floating
        win.isReleasedWhenClosed = false
        self.init(window: win)
        buildUI()
        reload()
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let title = NSTextField(labelWithString: "FlashFind 设置")
        title.font = Theme.songBold(16)
        title.translatesAutoresizingMaskIntoConstraints = false

        let hkLabel = NSTextField(labelWithString: "唤起快捷键")
        hkLabel.font = Theme.songBold(13)
        hkLabel.translatesAutoresizingMaskIntoConstraints = false

        hotkeyButton.bezelStyle = .rounded
        hotkeyButton.font = Theme.songBold(13)
        hotkeyButton.target = self
        hotkeyButton.action = #selector(startRecord)
        hotkeyButton.translatesAutoresizingMaskIntoConstraints = false
        hotkeyButton.toolTip = "点击后按下新的组合键"

        let resetBtn = NSButton(title: "恢复默认", target: self, action: #selector(resetHotKey))
        resetBtn.bezelStyle = .rounded
        resetBtn.font = Theme.songBold(12)
        resetBtn.translatesAutoresizingMaskIntoConstraints = false

        hintLabel.font = Theme.songBold(11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.stringValue = "点击按钮后按下组合键（需含 ⌘ / ⌥ / ⌃ / ⇧）"
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        let sortLabel = NSTextField(labelWithString: "默认排序")
        sortLabel.font = Theme.songBold(13)
        sortLabel.translatesAutoresizingMaskIntoConstraints = false

        sortPopup.font = Theme.songBold(12)
        sortPopup.translatesAutoresizingMaskIntoConstraints = false
        sortPopup.removeAllItems()
        for k in IndexEngine.SortKey.allCases {
            sortPopup.addItem(withTitle: k.rawValue)
        }
        sortPopup.target = self
        sortPopup.action = #selector(sortChanged)

        loginCheck.font = Theme.songBold(13)
        loginCheck.target = self
        loginCheck.action = #selector(loginToggled)
        loginCheck.translatesAutoresizingMaskIntoConstraints = false

        let rebuildBtn = NSButton(title: "立即重建索引", target: self, action: #selector(rebuild))
        rebuildBtn.bezelStyle = .rounded
        rebuildBtn.font = Theme.songBold(12)
        rebuildBtn.translatesAutoresizingMaskIntoConstraints = false

        let closeBtn = NSButton(title: "完成", target: self, action: #selector(closeSettings))
        closeBtn.bezelStyle = .rounded
        closeBtn.font = Theme.songBold(13)
        closeBtn.keyEquivalent = "\r"
        closeBtn.translatesAutoresizingMaskIntoConstraints = false

        for v in [title, hkLabel, hotkeyButton, resetBtn, hintLabel, sortLabel, sortPopup, loginCheck, rebuildBtn, closeBtn] {
            content.addSubview(v)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),

            hkLabel.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 22),
            hkLabel.leadingAnchor.constraint(equalTo: title.leadingAnchor),

            hotkeyButton.centerYAnchor.constraint(equalTo: hkLabel.centerYAnchor),
            hotkeyButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 120),
            hotkeyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            resetBtn.centerYAnchor.constraint(equalTo: hkLabel.centerYAnchor),
            resetBtn.leadingAnchor.constraint(equalTo: hotkeyButton.trailingAnchor, constant: 8),

            hintLabel.topAnchor.constraint(equalTo: hkLabel.bottomAnchor, constant: 8),
            hintLabel.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            hintLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),

            sortLabel.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 20),
            sortLabel.leadingAnchor.constraint(equalTo: title.leadingAnchor),

            sortPopup.centerYAnchor.constraint(equalTo: sortLabel.centerYAnchor),
            sortPopup.leadingAnchor.constraint(equalTo: hotkeyButton.leadingAnchor),
            sortPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),

            loginCheck.topAnchor.constraint(equalTo: sortLabel.bottomAnchor, constant: 18),
            loginCheck.leadingAnchor.constraint(equalTo: title.leadingAnchor),

            rebuildBtn.topAnchor.constraint(equalTo: loginCheck.bottomAnchor, constant: 18),
            rebuildBtn.leadingAnchor.constraint(equalTo: title.leadingAnchor),

            closeBtn.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),
            closeBtn.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
        ])
    }

    func present() {
        reload()
        guard let window else { return }
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: f.midX - window.frame.width / 2, y: f.midY - window.frame.height / 2))
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func reload() {
        let cfg = HotKeyConfig.load()
        hotkeyButton.title = cfg.display
        recording = false
        hintLabel.stringValue = "点击按钮后按下组合键（需含 ⌘ / ⌥ / ⌃ / ⇧）"
        hintLabel.textColor = .secondaryLabelColor

        let sortRaw = UserDefaults.standard.string(forKey: "ff.defaultSort") ?? IndexEngine.SortKey.relevance.rawValue
        sortPopup.selectItem(withTitle: sortRaw)

        loginCheck.state = FileManager.default.fileExists(
            atPath: NSHomeDirectory() + "/Library/LaunchAgents/com.local.FlashFind.plist"
        ) ? .on : .off
    }

    @objc private func startRecord() {
        recording = true
        hotkeyButton.title = "请按下快捷键…"
        hintLabel.stringValue = "正在录制… Esc 取消"
        hintLabel.textColor = Theme.accent

        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.recording else { return event }
            if event.keyCode == UInt16(kVK_Escape) {
                self.stopRecord(cancel: true)
                return nil
            }
            if let cfg = HotKeyConfig.from(event: event) {
                cfg.save()
                self.hotkeyButton.title = cfg.display
                self.onHotKeyChanged?(cfg)
                self.stopRecord(cancel: false)
                return nil
            }
            self.hintLabel.stringValue = "需要带修饰键的组合，例如 ⌘⌥F"
            self.hintLabel.textColor = .systemOrange
            return nil
        }
    }

    private func stopRecord(cancel: Bool) {
        recording = false
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if cancel {
            hotkeyButton.title = HotKeyConfig.load().display
            hintLabel.stringValue = "已取消"
        } else {
            hintLabel.stringValue = "快捷键已更新"
            hintLabel.textColor = .secondaryLabelColor
        }
    }

    @objc private func resetHotKey() {
        HotKeyConfig.default.save()
        hotkeyButton.title = HotKeyConfig.default.display
        onHotKeyChanged?(HotKeyConfig.default)
        hintLabel.stringValue = "已恢复默认 ⌃⌥Space"
    }

    @objc private func sortChanged() {
        if let t = sortPopup.selectedItem?.title {
            UserDefaults.standard.set(t, forKey: "ff.defaultSort")
        }
    }

    @objc private func loginToggled() {
        let enable = loginCheck.state == .on
        let plist = NSHomeDirectory() + "/Library/LaunchAgents/com.local.FlashFind.plist"
        let app = NSHomeDirectory() + "/Applications/FlashFind.app/Contents/MacOS/FlashFind"
        if enable {
            let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict>
            <key>Label</key><string>com.local.FlashFind</string>
            <key>ProgramArguments</key><array>
            <string>\(app)</string>
            </array>
            <key>RunAtLoad</key><true/>
            <key>LimitLoadToSessionType</key><string>Aqua</string>
            </dict></plist>
            """
            try? xml.write(toFile: plist, atomically: true, encoding: .utf8)
            let uid = getuid()
            _ = run("/bin/launchctl", ["bootout", "gui/\(uid)/com.local.FlashFind"])
            _ = run("/bin/launchctl", ["bootstrap", "gui/\(uid)", plist])
        } else {
            let uid = getuid()
            _ = run("/bin/launchctl", ["bootout", "gui/\(uid)/com.local.FlashFind"])
            try? FileManager.default.removeItem(atPath: plist)
        }
    }

    @objc private func rebuild() {
        onRequestRebuild?()
        hintLabel.stringValue = "已开始重建索引"
    }

    @objc private func closeSettings() {
        stopRecord(cancel: true)
        window?.orderOut(nil)
    }

    @discardableResult
    private func run(_ path: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus
    }
}
