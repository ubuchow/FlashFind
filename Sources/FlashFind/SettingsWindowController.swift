import AppKit
import Carbon
import QuartzCore

/// 设置：快捷键、排序、语言、外观、登录启动
final class SettingsWindowController: NSWindowController {
    var onHotKeyChanged: ((HotKeyConfig) -> Void)?
    var onRequestRebuild: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let hkLabel = NSTextField(labelWithString: "")
    private let hotkeyButton = NSButton(title: "", target: nil, action: nil)
    private let resetBtn = NSButton(title: "", target: nil, action: nil)
    private let hintLabel = NSTextField(wrappingLabelWithString: "")
    private let sortLabel = NSTextField(labelWithString: "")
    private let sortPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let langLabel = NSTextField(labelWithString: "")
    private let langPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let appearLabel = NSTextField(labelWithString: "")
    private let appearPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let loginCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let contentCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let rebuildBtn = NSButton(title: "", target: nil, action: nil)
    private let closeBtn = NSButton(title: "", target: nil, action: nil)

    /// 左栏标签统一宽度，避免中英文长短不一导致右侧控件错位
    private let labelWidth: CGFloat = 108
    private let controlLeading: CGFloat = 140

    private var recording = false
    private var keyMonitor: Any?

    convenience init() {
        let win = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Settings"
        win.isFloatingPanel = true
        win.level = .floating
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 420, height: 420)
        self.init(window: win)
        buildUI()
        reload()
    }

    private func styleLabel(_ tf: NSTextField, size: CGFloat = 13) {
        tf.font = Theme.songBold(size)
        tf.isBezeled = false
        tf.drawsBackground = false
        tf.isEditable = false
        tf.isSelectable = false
        tf.lineBreakMode = .byTruncatingTail
        tf.setContentHuggingPriority(.required, for: .vertical)
        tf.setContentCompressionResistancePriority(.required, for: .vertical)
        tf.translatesAutoresizingMaskIntoConstraints = false
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        styleLabel(titleLabel, size: 17)
        styleLabel(hkLabel)
        styleLabel(sortLabel)
        styleLabel(langLabel)
        styleLabel(appearLabel)

        hintLabel.font = Theme.songBold(11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.maximumNumberOfLines = 2
        hintLabel.isEditable = false
        hintLabel.isBezeled = false
        hintLabel.drawsBackground = false
        hintLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        hotkeyButton.bezelStyle = .rounded
        hotkeyButton.font = Theme.songBold(13)
        hotkeyButton.target = self
        hotkeyButton.action = #selector(startRecord)
        hotkeyButton.translatesAutoresizingMaskIntoConstraints = false
        hotkeyButton.setContentHuggingPriority(.defaultLow, for: .horizontal)

        resetBtn.bezelStyle = .rounded
        resetBtn.font = Theme.songBold(12)
        resetBtn.target = self
        resetBtn.action = #selector(resetHotKey)
        resetBtn.translatesAutoresizingMaskIntoConstraints = false

        for p in [sortPopup, langPopup, appearPopup] {
            p.font = Theme.songBold(12)
            p.translatesAutoresizingMaskIntoConstraints = false
            p.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }
        sortPopup.target = self
        sortPopup.action = #selector(sortChanged)
        langPopup.target = self
        langPopup.action = #selector(langChanged)
        appearPopup.target = self
        appearPopup.action = #selector(appearChanged)

        loginCheck.font = Theme.songBold(13)
        loginCheck.target = self
        loginCheck.action = #selector(loginToggled)
        loginCheck.translatesAutoresizingMaskIntoConstraints = false

        contentCheck.font = Theme.songBold(13)
        contentCheck.target = self
        contentCheck.action = #selector(contentToggled)
        contentCheck.translatesAutoresizingMaskIntoConstraints = false

        rebuildBtn.bezelStyle = .rounded
        rebuildBtn.font = Theme.songBold(12)
        rebuildBtn.target = self
        rebuildBtn.action = #selector(rebuild)
        rebuildBtn.translatesAutoresizingMaskIntoConstraints = false

        closeBtn.bezelStyle = .rounded
        closeBtn.font = Theme.songBold(13)
        closeBtn.keyEquivalent = "\r"
        closeBtn.target = self
        closeBtn.action = #selector(closeSettings)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false

        let views: [NSView] = [
            titleLabel, hkLabel, hotkeyButton, resetBtn, hintLabel,
            sortLabel, sortPopup, langLabel, langPopup, appearLabel, appearPopup,
            loginCheck, contentCheck, rebuildBtn, closeBtn,
        ]
        views.forEach { content.addSubview($0) }

        // 表单式垂直布局：左标签固定宽，右控件统一 leading
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -24),

            // 行 1：快捷键
            hkLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            hkLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            hkLabel.widthAnchor.constraint(equalToConstant: labelWidth),

            hotkeyButton.centerYAnchor.constraint(equalTo: hkLabel.centerYAnchor),
            hotkeyButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: controlLeading),
            hotkeyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            hotkeyButton.heightAnchor.constraint(equalToConstant: 28),

            resetBtn.centerYAnchor.constraint(equalTo: hkLabel.centerYAnchor),
            resetBtn.leadingAnchor.constraint(equalTo: hotkeyButton.trailingAnchor, constant: 8),
            resetBtn.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -24),
            resetBtn.heightAnchor.constraint(equalToConstant: 28),

            hintLabel.topAnchor.constraint(equalTo: hkLabel.bottomAnchor, constant: 8),
            hintLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: controlLeading),
            hintLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),

            // 行 2：默认排序
            sortLabel.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 18),
            sortLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            sortLabel.widthAnchor.constraint(equalToConstant: labelWidth),
            sortPopup.centerYAnchor.constraint(equalTo: sortLabel.centerYAnchor),
            sortPopup.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: controlLeading),
            sortPopup.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            sortPopup.heightAnchor.constraint(equalToConstant: 26),

            // 行 3：语言
            langLabel.topAnchor.constraint(equalTo: sortLabel.bottomAnchor, constant: 16),
            langLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            langLabel.widthAnchor.constraint(equalToConstant: labelWidth),
            langPopup.centerYAnchor.constraint(equalTo: langLabel.centerYAnchor),
            langPopup.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: controlLeading),
            langPopup.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            langPopup.heightAnchor.constraint(equalToConstant: 26),

            // 行 4：外观
            appearLabel.topAnchor.constraint(equalTo: langLabel.bottomAnchor, constant: 16),
            appearLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            appearLabel.widthAnchor.constraint(equalToConstant: labelWidth),
            appearPopup.centerYAnchor.constraint(equalTo: appearLabel.centerYAnchor),
            appearPopup.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: controlLeading),
            appearPopup.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            appearPopup.heightAnchor.constraint(equalToConstant: 26),

            // 登录
            loginCheck.topAnchor.constraint(equalTo: appearLabel.bottomAnchor, constant: 20),
            loginCheck.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            loginCheck.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -24),

            // 内容搜索
            contentCheck.topAnchor.constraint(equalTo: loginCheck.bottomAnchor, constant: 12),
            contentCheck.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            contentCheck.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -24),

            // 重建
            rebuildBtn.topAnchor.constraint(equalTo: contentCheck.bottomAnchor, constant: 16),
            rebuildBtn.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            rebuildBtn.heightAnchor.constraint(equalToConstant: 28),

            closeBtn.topAnchor.constraint(greaterThanOrEqualTo: rebuildBtn.bottomAnchor, constant: 24),
            closeBtn.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            closeBtn.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            closeBtn.heightAnchor.constraint(equalToConstant: 30),
            closeBtn.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
        ])
    }

    func present() {
        reload()
        guard let window else { return }
        window.title = L10n.settings
        if let named = NSApp.appearance?.name {
            window.appearance = NSAppearance(named: named)
        } else {
            window.appearance = nil
        }

        // 固定内容尺寸，动画只改位置与透明度，避免布局被压扁错位
        let size = NSSize(width: 460, height: 460)
        guard let screen = NSScreen.main else {
            window.setContentSize(size)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let vis = screen.visibleFrame
        let end = NSRect(
            x: vis.midX - size.width / 2,
            y: vis.midY - size.height / 2 + 20,
            width: size.width,
            height: size.height
        )
        var start = end
        start.origin.y -= 18
        // 轻微缩放：只动位置/透明度，尺寸保持，防止 Auto Layout 错位
        window.setFrame(end, display: false)
        window.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.setFrame(start, display: true)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.32
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
            ctx.allowsImplicitAnimation = true
            window.animator().alphaValue = 1
            window.animator().setFrame(end, display: true)
        }, completionHandler: {
            if let cv = window.contentView {
                cv.wantsLayer = true
                let anim = CASpringAnimation(keyPath: "transform.scale")
                anim.fromValue = 0.985
                anim.toValue = 1.0
                anim.mass = 0.5
                anim.stiffness = 240
                anim.damping = 18
                anim.duration = anim.settlingDuration
                cv.layer?.add(anim, forKey: "springIn")
            }
        })
    }

    private func reload() {
        applyLabels()
        let cfg = HotKeyConfig.load()
        hotkeyButton.title = cfg.display
        recording = false
        hintLabel.stringValue = L10n.hotkeyHint
        hintLabel.textColor = .secondaryLabelColor

        sortPopup.removeAllItems()
        for k in IndexEngine.SortKey.allCases {
            sortPopup.addItem(withTitle: k.rawValue)
        }
        let sortRaw = UserDefaults.standard.string(forKey: "ff.defaultSort") ?? IndexEngine.SortKey.relevance.rawValue
        sortPopup.selectItem(withTitle: sortRaw)

        langPopup.removeAllItems()
        for l in AppPrefs.Language.allCases {
            langPopup.addItem(withTitle: l.label)
            langPopup.lastItem?.representedObject = l.rawValue
        }
        langPopup.selectItem(withTitle: AppPrefs.language.label)

        appearPopup.removeAllItems()
        let lang = AppPrefs.language
        for a in AppPrefs.Appearance.allCases {
            appearPopup.addItem(withTitle: a.label(lang: lang))
            appearPopup.lastItem?.representedObject = a.rawValue
        }
        appearPopup.selectItem(withTitle: AppPrefs.appearance.label(lang: lang))

        loginCheck.state = FileManager.default.fileExists(
            atPath: NSHomeDirectory() + "/Library/LaunchAgents/com.local.FlashFind.plist"
        ) ? .on : .off
        contentCheck.state = AppPrefs.contentSearchEnabled ? .on : .off
    }

    private func applyLabels() {
        titleLabel.stringValue = L10n.settingsTitle
        hkLabel.stringValue = L10n.hotkey
        resetBtn.title = L10n.resetDefault
        sortLabel.stringValue = L10n.defaultSort
        langLabel.stringValue = L10n.language
        appearLabel.stringValue = L10n.appearance
        loginCheck.title = L10n.launchAtLogin
        contentCheck.title = L10n.t("可根据正文内容搜索（会稍慢）", "Search in file contents (slower)")
        rebuildBtn.title = L10n.rebuildIndex
        closeBtn.title = L10n.done
        window?.title = L10n.settings
    }

    @objc private func contentToggled() {
        let on = contentCheck.state == .on
        AppPrefs.contentSearchEnabled = on
        guard on else { return }
        let alert = NSAlert()
        alert.messageText = L10n.contentSearchAlertTitle
        alert.informativeText = L10n.contentSearchAlertMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.contentSearchAlertOK)
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    @objc private func startRecord() {
        recording = true
        hotkeyButton.title = L10n.t("请按下快捷键…", "Press shortcut…")
        hintLabel.stringValue = L10n.t("正在录制… Esc 取消", "Recording… Esc to cancel")
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
            self.hintLabel.stringValue = L10n.t("需要带修饰键的组合，例如 ⌘⌥F", "Need modifiers, e.g. ⌘⌥F")
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
            hintLabel.stringValue = L10n.t("已取消", "Cancelled")
        } else {
            hintLabel.stringValue = L10n.t("快捷键已更新", "Hotkey updated")
            hintLabel.textColor = .secondaryLabelColor
        }
    }

    @objc private func resetHotKey() {
        HotKeyConfig.default.save()
        hotkeyButton.title = HotKeyConfig.default.display
        onHotKeyChanged?(HotKeyConfig.default)
        hintLabel.stringValue = L10n.t("已恢复默认 ⌃⌥Space", "Reset to ⌃⌥Space")
    }

    @objc private func sortChanged() {
        if let t = sortPopup.selectedItem?.title {
            UserDefaults.standard.set(t, forKey: "ff.defaultSort")
        }
    }

    @objc private func langChanged() {
        guard let raw = langPopup.selectedItem?.representedObject as? String,
              let lang = AppPrefs.Language(rawValue: raw) else { return }
        AppPrefs.language = lang
        reload()
    }

    @objc private func appearChanged() {
        guard let raw = appearPopup.selectedItem?.representedObject as? String,
              let a = AppPrefs.Appearance(rawValue: raw) else { return }
        AppPrefs.appearance = a
        if let named = NSApp.appearance?.name {
            window?.appearance = NSAppearance(named: named)
        } else {
            window?.appearance = nil
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
        hintLabel.stringValue = L10n.t("已开始重建索引", "Rebuilding index…")
    }

    @objc private func closeSettings() {
        stopRecord(cancel: true)
        guard let window else { return }
        var end = window.frame
        end.origin.y -= 12
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
            window.animator().setFrame(end, display: true)
        }, completionHandler: {
            window.orderOut(nil)
            window.alphaValue = 1
        })
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
