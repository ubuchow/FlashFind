import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var searchWC: SearchWindowController!
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        searchWC = SearchWindowController()
        searchWC.hotKeyHandler = { [weak self] cfg in
            _ = self?.hotKey?.rebind(
                keyCode: cfg.keyCode,
                carbonModifiers: cfg.carbonModifiers,
                display: cfg.display
            )
            self?.updateTooltip()
            self?.searchWC.updateHotKeyHint()
        }
        searchWC.rebuildHandler = {
            IndexEngine.shared.rebuildAsync(reason: "重建索引")
        }

        setupStatusItem()
        setupHotKey()
        setupIndex()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = item.button {
            let icon = MenuBarIcon.make(size: 18)
            icon.isTemplate = true
            btn.image = icon
            btn.toolTip = tooltipText()
            btn.target = self
            btn.action = #selector(statusClicked(_:))
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    private func setupHotKey() {
        hotKey = HotKey { [weak self] in
            self?.toggleSearch()
        }
        _ = hotKey?.register()
        updateTooltip()
    }

    private func setupIndex() {
        let engine = IndexEngine.shared
        engine.onStatus = { [weak self] text in
            self?.searchWC.setIndexStatus(text)
            self?.statusItem?.button?.toolTip = "FlashFind — \(text)"
        }
        engine.onIndexFinished = { [weak self] in
            self?.searchWC.setIndexStatus("索引 \(IndexEngine.shared.fileCount) 项")
            self?.updateTooltip()
        }
        engine.start()
    }

    private func tooltipText() -> String {
        "FlashFind — \(HotKeyConfig.load().display)"
    }

    private func updateTooltip() {
        statusItem?.button?.toolTip = tooltipText()
    }

    @objc private func statusClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            toggleSearch()
            return
        }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggleSearch()
        }
    }

    private func toggleSearch() {
        if let w = searchWC.window, w.isVisible {
            searchWC.dismissAnimated()
        } else {
            searchWC.present()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let entries: [(String, Selector?)] = [
            ("打开搜索", #selector(openSearch)),
            ("设置…", #selector(openSettings)),
            ("重建索引", #selector(rebuild)),
            ("—", nil),
            ("关于 FlashFind", #selector(about)),
            ("退出", #selector(quit)),
        ]
        for (t, sel) in entries {
            if t == "—" {
                menu.addItem(.separator())
                continue
            }
            let item = NSMenuItem(title: t, action: sel, keyEquivalent: t == "退出" ? "q" : "")
            item.attributedTitle = NSAttributedString(string: t, attributes: [.font: Theme.songBold(13)])
            item.target = self
            menu.addItem(item)
        }
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openSearch() { searchWC.present() }
    @objc private func openSettings() { searchWC.openSettings() }

    @objc private func rebuild() {
        IndexEngine.shared.rebuildAsync(reason: "重建索引")
        searchWC.present()
    }

    @objc private func about() {
        let alert = NSAlert()
        alert.messageText = "FlashFind"
        alert.informativeText = """
        毫秒级文件名搜索 · 体积极小 · 低内存

        当前快捷键：\(HotKeyConfig.load().display)
        窗口右上角 ⚙ 可修改快捷键与其它设置

        回车打开 · ⌘回车 访达 · ⌥回车 定位文件夹
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}


