import AppKit
import QuartzCore

final class SearchWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSMenuDelegate {
    private var hits: [IndexEngine.Hit] = []
    private var lastMs: Double = 0
    private var searchGeneration = 0
    private var currentSort: IndexEngine.SortKey = {
        if let raw = UserDefaults.standard.string(forKey: "ff.defaultSort")
            ?? UserDefaults.standard.string(forKey: "qqs.defaultSort"),
           let k = IndexEngine.SortKey(rawValue: raw) {
            return k
        }
        return .relevance
    }()
    private var contextRow: Int = -1
    private var isAnimating = false

    private let chrome = NSVisualEffectView()
    private let queryField = CenteredTextField()
    private let searchIcon = NSImageView()
    private let sortPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let statusLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let countLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "FlashFind")
    private let searchCard = NSView()
    private let settingsButton = NSButton()
    private let titleBar = NSView()
    private let trafficButtons = TrafficButtonsView()

    private lazy var settingsWC = SettingsWindowController()
    var hotKeyHandler: ((HotKeyConfig) -> Void)?
    var rebuildHandler: (() -> Void)?

    convenience init() {
        // 无系统标题栏：用自绘关闭/缩小，避免 fullSizeContentView 错位
        let win = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "FlashFind"
        win.isFloatingPanel = true
        win.level = .floating
        win.hidesOnDeactivate = false
        win.isReleasedWhenClosed = false
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.isMovableByWindowBackground = true
        win.minSize = NSSize(width: 560, height: 360)
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.init(window: win)
        win.delegate = self
        buildUI()
    }

    private func buildUI() {
        guard let window else { return }

        // 内容视图铺满，毛玻璃与窗口边缘对齐 → 红绿灯落在窗口内
        let content = NSView(frame: .zero)
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = content

        chrome.material = .sidebar
        chrome.blendingMode = .behindWindow
        chrome.state = .followsWindowActiveState
        chrome.wantsLayer = true
        chrome.layer?.cornerRadius = 14
        chrome.layer?.masksToBounds = true
        chrome.layer?.borderWidth = 0.5
        chrome.layer?.borderColor = Theme.subtleBorder.cgColor
        chrome.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(chrome)

        // 顶部栏：关闭 / 缩小 + 标题 + 设置（按钮在窗口内容内）
        titleBar.translatesAutoresizingMaskIntoConstraints = false
        trafficButtons.translatesAutoresizingMaskIntoConstraints = false
        trafficButtons.onClose = { [weak self] in
            self?.dismissAnimated()
        }
        trafficButtons.onMinimize = { [weak self] in
            self?.window?.miniaturize(nil)
            // borderless 面板可能不支持 miniaturize，退化为隐藏
            if self?.window?.isMiniaturized != true {
                self?.window?.orderOut(nil)
            }
        }

        titleLabel.font = Theme.songBold(13)
        titleLabel.textColor = Theme.accent
        titleLabel.alignment = .center
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        settingsButton.bezelStyle = .regularSquare
        settingsButton.isBordered = false
        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "设置")
        settingsButton.image?.isTemplate = true
        settingsButton.contentTintColor = .secondaryLabelColor
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        settingsButton.toolTip = "设置"
        settingsButton.translatesAutoresizingMaskIntoConstraints = false

        // 搜索卡片 + 自绘放大镜 + 垂直居中文本框
        searchCard.wantsLayer = true
        searchCard.layer?.cornerRadius = 11
        searchCard.layer?.backgroundColor = Theme.cardFill.cgColor
        searchCard.layer?.borderWidth = 1
        searchCard.layer?.borderColor = Theme.subtleBorder.cgColor
        searchCard.translatesAutoresizingMaskIntoConstraints = false

        searchIcon.image = MenuBarIcon.make(size: 16)
        searchIcon.image?.isTemplate = true
        searchIcon.contentTintColor = .secondaryLabelColor
        searchIcon.imageScaling = .scaleProportionallyUpOrDown
        searchIcon.translatesAutoresizingMaskIntoConstraints = false

        queryField.placeholderString = "搜索文件名…"
        queryField.font = Theme.songBold(16)
        queryField.isBordered = false
        queryField.isBezeled = false
        queryField.drawsBackground = false
        queryField.focusRingType = .none
        queryField.delegate = self
        queryField.translatesAutoresizingMaskIntoConstraints = false
        if let cell = queryField.cell as? NSTextFieldCell {
            cell.isScrollable = true
            cell.wraps = false
            cell.usesSingleLineMode = true
            cell.font = Theme.songBold(16)
            // placeholder 同样用宋体粗，颜色次要
            cell.placeholderAttributedString = NSAttributedString(
                string: "搜索文件名…",
                attributes: [
                    .font: Theme.songBold(16),
                    .foregroundColor: NSColor.placeholderTextColor,
                    .baselineOffset: 0,
                ]
            )
        }

        sortPopup.translatesAutoresizingMaskIntoConstraints = false
        sortPopup.controlSize = .small
        sortPopup.font = Theme.songBold(11)
        sortPopup.bezelStyle = .inline
        sortPopup.isBordered = false
        sortPopup.removeAllItems()
        for key in IndexEngine.SortKey.allCases {
            sortPopup.addItem(withTitle: key.rawValue)
        }
        if let idx = IndexEngine.SortKey.allCases.firstIndex(of: currentSort) {
            sortPopup.selectItem(at: idx)
        }
        sortPopup.target = self
        sortPopup.action = #selector(sortChanged)

        let sortCaption = NSTextField(labelWithString: "排序")
        sortCaption.font = Theme.songBold(11)
        sortCaption.textColor = Theme.secondaryText
        sortCaption.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = Theme.songBold(11)
        statusLabel.textColor = Theme.secondaryText
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        countLabel.font = Theme.songBold(11)
        countLabel.textColor = Theme.metaText
        countLabel.alignment = .right
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        tableView.headerView = nil
        tableView.rowHeight = 44
        tableView.style = .plain
        tableView.backgroundColor = .clear
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.selectionHighlightStyle = .regular
        tableView.doubleAction = #selector(openSelected)
        tableView.target = self
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsEmptySelection = false
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.menu = {
            let m = NSMenu()
            m.delegate = self
            return m
        }()

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        col.width = 680
        tableView.addTableColumn(col)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        chrome.addSubview(titleBar)
        titleBar.addSubview(trafficButtons)
        titleBar.addSubview(titleLabel)
        titleBar.addSubview(settingsButton)
        chrome.addSubview(searchCard)
        searchCard.addSubview(searchIcon)
        searchCard.addSubview(queryField)
        chrome.addSubview(sortCaption)
        chrome.addSubview(sortPopup)
        chrome.addSubview(statusLabel)
        chrome.addSubview(countLabel)
        chrome.addSubview(scrollView)

        NSLayoutConstraint.activate([
            chrome.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            chrome.topAnchor.constraint(equalTo: content.topAnchor),
            chrome.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            // 顶部栏在窗口内：关闭 / 缩小 明确可见
            titleBar.leadingAnchor.constraint(equalTo: chrome.leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: chrome.trailingAnchor),
            titleBar.topAnchor.constraint(equalTo: chrome.topAnchor),
            titleBar.heightAnchor.constraint(equalToConstant: 44),

            trafficButtons.leadingAnchor.constraint(equalTo: titleBar.leadingAnchor),
            trafficButtons.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            trafficButtons.widthAnchor.constraint(equalToConstant: 60),
            trafficButtons.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: titleBar.centerXAnchor),

            settingsButton.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            settingsButton.trailingAnchor.constraint(equalTo: titleBar.trailingAnchor, constant: -12),
            settingsButton.widthAnchor.constraint(equalToConstant: 28),
            settingsButton.heightAnchor.constraint(equalToConstant: 28),

            searchCard.topAnchor.constraint(equalTo: titleBar.bottomAnchor, constant: 2),
            searchCard.leadingAnchor.constraint(equalTo: chrome.leadingAnchor, constant: 16),
            searchCard.trailingAnchor.constraint(equalTo: chrome.trailingAnchor, constant: -16),
            searchCard.heightAnchor.constraint(equalToConstant: 44),

            searchIcon.leadingAnchor.constraint(equalTo: searchCard.leadingAnchor, constant: 14),
            searchIcon.centerYAnchor.constraint(equalTo: searchCard.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 16),
            searchIcon.heightAnchor.constraint(equalToConstant: 16),

            // 文本框在卡片内垂直居中（配合 CenteredTextFieldCell）
            queryField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 10),
            queryField.trailingAnchor.constraint(equalTo: searchCard.trailingAnchor, constant: -14),
            queryField.topAnchor.constraint(equalTo: searchCard.topAnchor, constant: 0),
            queryField.bottomAnchor.constraint(equalTo: searchCard.bottomAnchor, constant: 0),

            sortCaption.topAnchor.constraint(equalTo: searchCard.bottomAnchor, constant: 10),
            sortCaption.leadingAnchor.constraint(equalTo: searchCard.leadingAnchor, constant: 2),

            sortPopup.centerYAnchor.constraint(equalTo: sortCaption.centerYAnchor),
            sortPopup.leadingAnchor.constraint(equalTo: sortCaption.trailingAnchor, constant: 4),

            statusLabel.centerYAnchor.constraint(equalTo: sortCaption.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: sortPopup.trailingAnchor, constant: 12),

            countLabel.centerYAnchor.constraint(equalTo: sortCaption.centerYAnchor),
            countLabel.trailingAnchor.constraint(equalTo: searchCard.trailingAnchor),
            countLabel.leadingAnchor.constraint(greaterThanOrEqualTo: statusLabel.trailingAnchor, constant: 8),

            scrollView.topAnchor.constraint(equalTo: sortCaption.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: chrome.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: chrome.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: chrome.bottomAnchor, constant: -10),
        ])

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event) ?? event
        }

        // 绑定设置
        settingsWC.onHotKeyChanged = { [weak self] cfg in
            self?.hotKeyHandler?(cfg)
            self?.refreshStatusLine()
        }
        settingsWC.onRequestRebuild = { [weak self] in
            self?.rebuildHandler?()
        }

        DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshChrome()
        }
    }

    private func refreshChrome() {
        chrome.layer?.borderColor = Theme.subtleBorder.cgColor
        searchCard.layer?.backgroundColor = Theme.cardFill.cgColor
        searchCard.layer?.borderColor = Theme.subtleBorder.cgColor
        titleLabel.textColor = Theme.accent
        searchIcon.contentTintColor = .secondaryLabelColor
    }

    // MARK: - Animation

    func present() {
        guard let window else { return }
        refreshChrome()

        let end = targetFrame(for: window)
        var start = end
        let scale: CGFloat = 0.96
        start.size.width = end.width * scale
        start.size.height = end.height * scale
        start.origin.x = end.midX - start.width / 2
        start.origin.y = end.origin.y - 14

        window.setFrame(start, display: true)
        window.alphaValue = 0

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(queryField)
        refreshStatusLine()

        isAnimating = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.36
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
            ctx.allowsImplicitAnimation = true
            window.animator().alphaValue = 1
            window.animator().setFrame(end, display: true)
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
            if let layer = self?.chrome.layer {
                let anim = CASpringAnimation(keyPath: "transform.scale")
                anim.fromValue = 0.99
                anim.toValue = 1.0
                anim.mass = 0.6
                anim.stiffness = 200
                anim.damping = 18
                anim.duration = anim.settlingDuration
                layer.add(anim, forKey: "spring")
            }
        })

        if !queryField.stringValue.isEmpty {
            runSearch()
        }
    }

    func dismissAnimated() {
        guard let window, window.isVisible else { return }
        isAnimating = true
        var end = window.frame
        end.origin.y -= 10
        end.size.width *= 0.98
        end.size.height *= 0.98
        end.origin.x += window.frame.width * 0.01

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
            window.animator().setFrame(end, display: true)
        }, completionHandler: {
            window.orderOut(nil)
            window.alphaValue = 1
            self.isAnimating = false
        })
    }

    private func targetFrame(for window: NSWindow) -> NSRect {
        let size = window.frame.size.width > 100 ? window.frame.size : NSSize(width: 720, height: 520)
        guard let screen = NSScreen.main else {
            return NSRect(origin: .zero, size: size)
        }
        let vis = screen.visibleFrame
        return NSRect(
            x: vis.midX - size.width / 2,
            y: vis.midY - size.height / 2 + 48,
            width: size.width,
            height: size.height
        )
    }

    func setIndexStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    func updateHotKeyHint() {
        refreshStatusLine()
    }

    private func refreshStatusLine() {
        let n = IndexEngine.shared.fileCount
        let hk = HotKeyConfig.load().display
        if IndexEngine.shared.isIndexing {
            statusLabel.stringValue = "索引中… \(n) 项"
        } else if n == 0 {
            statusLabel.stringValue = "正在准备索引…"
        } else {
            statusLabel.stringValue = "\(n) 项 · \(hk)"
        }
    }

    // MARK: - Settings

    @objc func openSettings() {
        settingsWC.present()
    }

    // MARK: - Search

    @objc private func sortChanged() {
        guard let title = sortPopup.selectedItem?.title,
              let key = IndexEngine.SortKey(rawValue: title) else { return }
        currentSort = key
        UserDefaults.standard.set(key.rawValue, forKey: "ff.defaultSort")
        if !hits.isEmpty { resortCurrentHits() } else { runSearch() }
    }

    private func resortCurrentHits() {
        let gen = searchGeneration
        var list = hits
        let sort = currentSort
        let needle = queryField.stringValue.lowercased()
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            if sort.needsMetadata { IndexEngine.shared.enrichMetadata(&list) }
            list = IndexEngine.sortHits(list, by: sort, needle: needle)
            DispatchQueue.main.async {
                guard let self, gen == self.searchGeneration else { return }
                self.hits = list
                self.tableView.reloadData()
                if !list.isEmpty {
                    self.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                }
                self.updateCountLabel()
            }
        }
    }

    private func runSearch() {
        let q = queryField.stringValue
        searchGeneration += 1
        let gen = searchGeneration
        let sort = currentSort

        if q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            hits = []
            lastMs = 0
            countLabel.stringValue = ""
            tableView.reloadData()
            return
        }

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            let result = IndexEngine.shared.search(query: q, sort: sort, limit: 200)
            DispatchQueue.main.async {
                guard let self, gen == self.searchGeneration else { return }
                self.hits = result.hits
                self.lastMs = result.elapsedMs
                self.updateCountLabel()
                self.tableView.reloadData()
                if !result.hits.isEmpty {
                    self.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                }
            }
        }
    }

    private func updateCountLabel() {
        if hits.isEmpty {
            countLabel.stringValue = lastMs > 0 ? String(format: "0 条 · %.1f ms", lastMs) : ""
        } else {
            countLabel.stringValue = String(format: "%d 条 · %.1f ms", hits.count, lastMs)
        }
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { hits.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell = (tableView.makeView(withIdentifier: id, owner: nil) as? ResultCell) ?? ResultCell()
        cell.identifier = id
        if row < hits.count { cell.configure(hits[row], sort: currentSort) }
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        SoftRowView()
    }

    // MARK: - Context menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        contextRow = row
        guard row >= 0, row < hits.count else { return }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)

        let items: [(String, Selector)] = [
            ("打开", #selector(ctxOpen)),
            ("在访达中显示", #selector(ctxReveal)),
            ("定位到所在文件夹", #selector(ctxOpenParent)),
            ("—", #selector(ctxOpen)),
            ("复制文件路径", #selector(ctxCopyPath)),
            ("复制文件夹路径", #selector(ctxCopyFolder)),
        ]
        for (t, sel) in items {
            if t == "—" {
                menu.addItem(.separator())
                continue
            }
            let it = NSMenuItem(title: t, action: sel, keyEquivalent: "")
            it.target = self
            it.attributedTitle = NSAttributedString(string: t, attributes: [.font: Theme.songBold(13)])
            menu.addItem(it)
        }
    }

    @objc private func ctxOpen() { openHit(at: contextRow) }
    @objc private func ctxReveal() { revealHit(at: contextRow) }
    @objc private func ctxOpenParent() { openParentFolder(at: contextRow) }
    @objc private func ctxCopyPath() { copyPath(at: contextRow) }
    @objc private func ctxCopyFolder() { copyFolderPath(at: contextRow) }
    @objc private func openSelected() { openHit(at: tableView.selectedRow) }

    private func openHit(at row: Int) {
        guard row >= 0, row < hits.count else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: hits[row].path))
    }

    private func revealHit(at row: Int) {
        guard row >= 0, row < hits.count else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: hits[row].path)])
    }

    private func openParentFolder(at row: Int) {
        guard row >= 0, row < hits.count else { return }
        let hit = hits[row]
        if hit.isDirectory {
            NSWorkspace.shared.open(URL(fileURLWithPath: hit.path, isDirectory: true))
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: hit.path)])
        }
    }

    private func copyPath(at row: Int) {
        guard row >= 0, row < hits.count else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hits[row].path, forType: .string)
    }

    private func copyFolderPath(at row: Int) {
        guard row >= 0, row < hits.count else { return }
        let hit = hits[row]
        let folder = hit.isDirectory ? hit.path : hit.parentPath
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(folder, forType: .string)
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard window?.isKeyWindow == true else { return event }
        // 设置面板录制时不抢键
        if settingsWC.window?.isVisible == true { return event }
        switch event.keyCode {
        case 53:
            dismissAnimated()
            return nil
        case 36, 76:
            if event.modifierFlags.contains(.command) {
                revealHit(at: tableView.selectedRow)
            } else if event.modifierFlags.contains(.option) {
                openParentFolder(at: tableView.selectedRow)
            } else {
                openHit(at: tableView.selectedRow)
            }
            return nil
        case 125: moveSelection(1); return nil
        case 126: moveSelection(-1); return nil
        case 8 where event.modifierFlags.contains(.command):
            copyPath(at: tableView.selectedRow)
            return nil
        default:
            return event
        }
    }

    private func moveSelection(_ delta: Int) {
        guard !hits.isEmpty else { return }
        var row = tableView.selectedRow
        if row < 0 { row = 0 }
        row = max(0, min(hits.count - 1, row + delta))
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        window?.makeFirstResponder(queryField)
    }

    func controlTextDidChange(_ obj: Notification) {
        runSearch()
    }
}

// MARK: - Panel

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class SoftRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 6, dy: 1), xRadius: 10, yRadius: 10)
        Theme.accent.withAlphaComponent(isEmphasized ? 0.16 : 0.10).setFill()
        path.fill()
    }

    override var interiorBackgroundStyle: NSView.BackgroundStyle { .normal }
}

private final class ResultCell: NSTableCellView {
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(labelWithString: "")
    private let metaLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown

        nameLabel.font = Theme.songBold(13.5)
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        pathLabel.font = Theme.songBold(11)
        pathLabel.textColor = Theme.secondaryText
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.translatesAutoresizingMaskIntoConstraints = false

        metaLabel.font = Theme.songBold(10.5)
        metaLabel.textColor = Theme.metaText
        metaLabel.alignment = .right
        metaLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(nameLabel)
        addSubview(pathLabel)
        addSubview(metaLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            metaLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            metaLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            metaLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 150),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: metaLabel.leadingAnchor, constant: -10),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),

            pathLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            pathLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            pathLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(_ hit: IndexEngine.Hit, sort: IndexEngine.SortKey) {
        nameLabel.stringValue = hit.name
        var p = hit.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if p.hasPrefix(home) { p = "~" + p.dropFirst(home.count) }
        pathLabel.stringValue = p
        iconView.image = NSWorkspace.shared.icon(forFile: hit.path)
        metaLabel.stringValue = Self.metaText(for: hit, sort: sort)
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    private static func metaText(for hit: IndexEngine.Hit, sort: IndexEngine.SortKey) -> String {
        switch sort {
        case .type: return hit.typeKey
        case .sizeAsc, .sizeDesc: return hit.fileSize >= 0 ? humanSize(hit.fileSize) : ""
        case .createdAsc, .createdDesc:
            return hit.createdAt.map { dateFmt.string(from: $0) } ?? ""
        case .modifiedAsc, .modifiedDesc:
            return hit.modifiedAt.map { dateFmt.string(from: $0) } ?? ""
        default:
            return hit.isDirectory ? "文件夹" : (hit.fileExtension.isEmpty ? "" : ".\(hit.fileExtension)")
        }
    }

    private static func humanSize(_ n: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(n)
        var i = 0
        while size >= 1024 && i < units.count - 1 { size /= 1024; i += 1 }
        return i == 0 ? "\(Int(size)) B" : String(format: "%.1f %@", size, units[i])
    }
}
