import AppKit
import QuartzCore

/// 设计稿布局：左侧边栏（分类/位置）+ 右侧搜索与结果
final class SearchWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSMenuDelegate {
    // MARK: State
    private var hits: [IndexEngine.Hit] = []
    private var categoryCounts: [IndexEngine.Category: Int] = [:]
    private var lastMs: Double = 0
    private var searchGeneration = 0
    private var selectedCategory: IndexEngine.Category = .all
    private var selectedLocationPath: String? = nil // nil = 全部
    private var currentSort: IndexEngine.SortKey = .relevance
    private var filterExt: String? = nil
    private var filterMinSize: Int64? = nil
    private var filterMaxSize: Int64? = nil
    private var filterModifiedDays: Int? = nil // 近 N 天
    private var contextRow = -1
    private var isListView = true

    // MARK: Chrome
    private let rootView = NSView()
    private let sidebar = NSView()
    private let mainPane = NSView()
    private let trafficButtons = TrafficButtonsView()

    // Sidebar
    private let brandIcon = NSImageView()
    private let brandLabel = NSTextField(labelWithString: "FlashFind")
    private let categoryStack = NSStackView()
    private let locationStack = NSStackView()
    private let locationScroll = NSScrollView()
    private let locTitle = NSTextField(labelWithString: "")
    private let sidebarSettingsBtn = NSButton()
    private var categoryButtons: [IndexEngine.Category: SidebarRowButton] = [:]
    private var locationButtons: [String: SidebarRowButton] = [:] // path -> btn, "" = all

    // Main
    private let headline = NSTextField(labelWithString: "")
    private let subhead = NSTextField(labelWithString: "")
    private let hotkeyBadge = NSView()
    private let hotkeyBadgeLabel = NSTextField(labelWithString: "")
    private let searchCard = NSView()
    private let searchIcon = NSImageView()
    private let queryField = CenteredTextField()
    private let clearBtn = NSButton()
    private let filterStack = NSStackView()
    private let typeFilter = NSPopUpButton(frame: .zero, pullsDown: true)
    private let timeFilter = NSPopUpButton(frame: .zero, pullsDown: true)
    private let sizeFilter = NSPopUpButton(frame: .zero, pullsDown: true)
    private let locFilter = NSPopUpButton(frame: .zero, pullsDown: true)
    private let sortPopup = NSPopUpButton(frame: .zero, pullsDown: true)
    private let listViewBtn = NSButton()
    private let gridViewBtn = NSButton()
    private let contentSearchPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let footerLabel = NSTextField(labelWithString: "")
    private let footerHints = NSTextField(labelWithString: "")
    private let searchSpinner = NSProgressIndicator()
    /// 是否正在搜索（用于底部状态与转圈）
    private var isSearching = false
    private var searchingIsContent = false

    private lazy var settingsWC = SettingsWindowController()
    var hotKeyHandler: ((HotKeyConfig) -> Void)?
    var rebuildHandler: (() -> Void)?

    convenience init() {
        let win = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 640),
            styleMask: [.borderless, .fullSizeContentView, .resizable],
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
        win.minSize = NSSize(width: 820, height: 520)
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.init(window: win)
        win.delegate = self
        buildUI()
    }

    // MARK: - Build

    private func buildUI() {
        guard let window else { return }
        let content = NSView()
        content.wantsLayer = true
        window.contentView = content

        rootView.wantsLayer = true
        rootView.layer?.cornerRadius = 16
        rootView.layer?.masksToBounds = true
        rootView.layer?.borderWidth = 0.5
        rootView.layer?.borderColor = Theme.subtleBorder.cgColor
        rootView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(rootView)

        // 侧边栏
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = Theme.sidebarBg.cgColor
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(sidebar)

        trafficButtons.translatesAutoresizingMaskIntoConstraints = false
        trafficButtons.onClose = { [weak self] in self?.dismissAnimated() }
        trafficButtons.onMinimize = { [weak self] in self?.window?.orderOut(nil) }
        sidebar.addSubview(trafficButtons)

        brandIcon.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)
        brandIcon.contentTintColor = Theme.accent
        brandIcon.translatesAutoresizingMaskIntoConstraints = false
        brandLabel.font = Theme.songBold(15)
        brandLabel.textColor = Theme.titleText
        brandLabel.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(brandIcon)
        sidebar.addSubview(brandLabel)

        categoryStack.orientation = .vertical
        categoryStack.alignment = .leading
        categoryStack.spacing = 2
        categoryStack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(categoryStack)

        locTitle.font = Theme.songBold(11)
        locTitle.textColor = Theme.metaText
        locTitle.isBezeled = false
        locTitle.drawsBackground = false
        locTitle.isEditable = false
        locTitle.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(locTitle)

        // 位置列表可滚动，避免与左下角设置按钮重叠
        locationStack.orientation = .vertical
        locationStack.alignment = .leading
        locationStack.spacing = 2
        locationStack.translatesAutoresizingMaskIntoConstraints = false
        locationStack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 4, right: 0)

        locationScroll.drawsBackground = false
        locationScroll.backgroundColor = .clear
        locationScroll.borderType = .noBorder
        locationScroll.hasVerticalScroller = true
        locationScroll.scrollerStyle = .overlay
        locationScroll.autohidesScrollers = true
        locationScroll.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(locationScroll)
        locationScroll.documentView = locationStack
        // 宽度贴合滚动区域，高度由 stack 内容撑开以便滚动
        NSLayoutConstraint.activate([
            locationStack.topAnchor.constraint(equalTo: locationScroll.contentView.topAnchor),
            locationStack.leadingAnchor.constraint(equalTo: locationScroll.contentView.leadingAnchor),
            locationStack.trailingAnchor.constraint(equalTo: locationScroll.contentView.trailingAnchor),
            locationStack.bottomAnchor.constraint(equalTo: locationScroll.contentView.bottomAnchor),
            locationStack.widthAnchor.constraint(equalTo: locationScroll.contentView.widthAnchor),
        ])

        sidebarSettingsBtn.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "设置")
        sidebarSettingsBtn.image?.isTemplate = true
        sidebarSettingsBtn.isBordered = false
        sidebarSettingsBtn.contentTintColor = Theme.secondaryText
        sidebarSettingsBtn.target = self
        sidebarSettingsBtn.action = #selector(openSettings)
        sidebarSettingsBtn.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(sidebarSettingsBtn)

        // 主区
        mainPane.wantsLayer = true
        mainPane.layer?.backgroundColor = Theme.contentBg.cgColor
        mainPane.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(mainPane)

        headline.font = Theme.songBold(22)
        headline.textColor = Theme.titleText
        headline.translatesAutoresizingMaskIntoConstraints = false
        subhead.font = Theme.songBold(12.5)
        subhead.textColor = Theme.secondaryText
        subhead.translatesAutoresizingMaskIntoConstraints = false
        // 快捷键徽章：容器 + 居中标签
        hotkeyBadge.wantsLayer = true
        hotkeyBadge.layer?.cornerRadius = 8
        hotkeyBadge.layer?.backgroundColor = Theme.chipBg.cgColor
        hotkeyBadge.translatesAutoresizingMaskIntoConstraints = false
        hotkeyBadgeLabel.font = Theme.songBold(11)
        hotkeyBadgeLabel.textColor = Theme.secondaryText
        hotkeyBadgeLabel.alignment = .center
        hotkeyBadgeLabel.isBezeled = false
        hotkeyBadgeLabel.drawsBackground = false
        hotkeyBadgeLabel.isEditable = false
        hotkeyBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        hotkeyBadge.addSubview(hotkeyBadgeLabel)

        mainPane.addSubview(headline)
        mainPane.addSubview(subhead)
        // hotkey 放到右下角，与 footer 同行

        // 搜索框
        searchCard.wantsLayer = true
        searchCard.layer?.cornerRadius = 12
        searchCard.layer?.borderWidth = 1.5
        searchCard.layer?.borderColor = Theme.accent.withAlphaComponent(0.55).cgColor
        searchCard.layer?.backgroundColor = Theme.contentBg.cgColor
        searchCard.translatesAutoresizingMaskIntoConstraints = false
        mainPane.addSubview(searchCard)

        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        searchIcon.contentTintColor = Theme.secondaryText
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        queryField.placeholderString = "输入关键词搜索…"
        queryField.font = Theme.songBold(15)
        queryField.isBordered = false
        queryField.drawsBackground = false
        queryField.focusRingType = .none
        queryField.delegate = self
        queryField.translatesAutoresizingMaskIntoConstraints = false
        if let cell = queryField.cell as? NSTextFieldCell {
            cell.placeholderAttributedString = NSAttributedString(
                string: "输入关键词搜索…",
                attributes: [.font: Theme.songBold(15), .foregroundColor: NSColor.placeholderTextColor]
            )
        }
        clearBtn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "清除")
        clearBtn.image?.isTemplate = true
        clearBtn.isBordered = false
        clearBtn.contentTintColor = Theme.metaText
        clearBtn.target = self
        clearBtn.action = #selector(clearQuery)
        clearBtn.isHidden = true
        clearBtn.translatesAutoresizingMaskIntoConstraints = false
        searchSpinner.style = .spinning
        searchSpinner.controlSize = .small
        searchSpinner.isDisplayedWhenStopped = false
        searchSpinner.isHidden = true
        searchSpinner.translatesAutoresizingMaskIntoConstraints = false
        searchCard.addSubview(searchIcon)
        searchCard.addSubview(queryField)
        searchCard.addSubview(searchSpinner)
        searchCard.addSubview(clearBtn)

        // 过滤条
        filterStack.orientation = .horizontal
        filterStack.spacing = 8
        filterStack.translatesAutoresizingMaskIntoConstraints = false
        mainPane.addSubview(filterStack)

        configureFilter(typeFilter, title: "类型", items: [
            ("全部类型", ""),
            ("文件夹", "folder"),
            ("应用", "app"),
            ("PDF", "pdf"),
            ("图片", "image"),
            ("文档", "doc"),
            ("表格", "sheet"),
            ("演示", "slide"),
            ("视频", "video"),
            ("音频", "audio"),
            ("压缩包", "archive"),
            ("代码", "code"),
        ], action: #selector(typeFilterChanged))
        configureFilter(timeFilter, title: "修改时间", items: [
            ("不限时间", ""),
            ("今天", "1"),
            ("近 7 天", "7"),
            ("近 30 天", "30"),
            ("近一年", "365"),
        ], action: #selector(timeFilterChanged))
        configureFilter(sizeFilter, title: "大小", items: [
            ("不限大小", ""),
            ("< 1 MB", "0-1"),
            ("1 – 10 MB", "1-10"),
            ("10 – 100 MB", "10-100"),
            ("> 100 MB", "100-"),
        ], action: #selector(sizeFilterChanged))
        configureFilter(locFilter, title: "位置", items: [("全部位置", "")], action: #selector(locFilterChanged))

        for b in [typeFilter, timeFilter, sizeFilter, locFilter] {
            styleChipPopup(b)
            filterStack.addArrangedSubview(b)
        }

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        filterStack.addArrangedSubview(spacer)

        configureFilter(sortPopup, title: "相关性", items: IndexEngine.SortKey.allCases.map { ($0.rawValue, $0.rawValue) }, action: #selector(sortChanged))
        styleChipPopup(sortPopup)
        filterStack.addArrangedSubview(sortPopup)

        // 搜索范围：仅文件名 / 可根据正文内容
        contentSearchPopup.target = self
        contentSearchPopup.action = #selector(contentSearchModeChanged(_:))
        contentSearchPopup.setContentHuggingPriority(.required, for: .horizontal)
        contentSearchPopup.font = Theme.songBold(12)
        styleChipPopup(contentSearchPopup)
        contentSearchPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 130).isActive = true
        filterStack.addArrangedSubview(contentSearchPopup)
        rebuildContentSearchPopup()

        listViewBtn.image = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "列表")
        gridViewBtn.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "网格")
        for b in [listViewBtn, gridViewBtn] {
            b.isBordered = false
            b.image?.isTemplate = true
            b.translatesAutoresizingMaskIntoConstraints = false
            b.widthAnchor.constraint(equalToConstant: 28).isActive = true
            b.heightAnchor.constraint(equalToConstant: 28).isActive = true
            filterStack.addArrangedSubview(b)
        }
        listViewBtn.target = self
        listViewBtn.action = #selector(showList)
        gridViewBtn.target = self
        gridViewBtn.action = #selector(showGrid)
        updateViewToggle()

        // 结果表
        tableView.headerView = nil
        tableView.rowHeight = 56
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.style = .plain
        tableView.doubleAction = #selector(openSelected)
        tableView.target = self
        tableView.dataSource = self
        tableView.delegate = self
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.menu = { let m = NSMenu(); m.delegate = self; return m }()
        let col = NSTableColumn(identifier: .init("main"))
        col.width = 700
        tableView.addTableColumn(col)

        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        mainPane.addSubview(scrollView)

        footerLabel.font = Theme.songBold(11)
        footerLabel.textColor = Theme.secondaryText
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerHints.font = Theme.songBold(11)
        footerHints.textColor = Theme.metaText
        footerHints.alignment = .right
        footerHints.translatesAutoresizingMaskIntoConstraints = false
        mainPane.addSubview(footerLabel)
        mainPane.addSubview(footerHints)
        mainPane.addSubview(hotkeyBadge)

        NSLayoutConstraint.activate([
            rootView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            rootView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            rootView.topAnchor.constraint(equalTo: content.topAnchor),
            rootView.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            sidebar.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: rootView.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 200),

            trafficButtons.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 4),
            trafficButtons.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 10),
            trafficButtons.widthAnchor.constraint(equalToConstant: 56),
            trafficButtons.heightAnchor.constraint(equalToConstant: 20),

            brandIcon.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 18),
            brandIcon.topAnchor.constraint(equalTo: trafficButtons.bottomAnchor, constant: 14),
            brandIcon.widthAnchor.constraint(equalToConstant: 18),
            brandIcon.heightAnchor.constraint(equalToConstant: 18),
            brandLabel.leadingAnchor.constraint(equalTo: brandIcon.trailingAnchor, constant: 6),
            brandLabel.centerYAnchor.constraint(equalTo: brandIcon.centerYAnchor),

            categoryStack.topAnchor.constraint(equalTo: brandIcon.bottomAnchor, constant: 20),
            categoryStack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 10),
            categoryStack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -10),

            locTitle.topAnchor.constraint(equalTo: categoryStack.bottomAnchor, constant: 18),
            locTitle.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 18),

            // 位置区域：可滚动，底部止于设置按钮上方
            locationScroll.topAnchor.constraint(equalTo: locTitle.bottomAnchor, constant: 6),
            locationScroll.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 10),
            locationScroll.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -10),
            locationScroll.bottomAnchor.constraint(equalTo: sidebarSettingsBtn.topAnchor, constant: -12),

            sidebarSettingsBtn.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 16),
            sidebarSettingsBtn.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -14),
            sidebarSettingsBtn.widthAnchor.constraint(equalToConstant: 24),
            sidebarSettingsBtn.heightAnchor.constraint(equalToConstant: 24),

            mainPane.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            mainPane.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            mainPane.topAnchor.constraint(equalTo: rootView.topAnchor),
            mainPane.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            headline.topAnchor.constraint(equalTo: mainPane.topAnchor, constant: 28),
            headline.leadingAnchor.constraint(equalTo: mainPane.leadingAnchor, constant: 28),
            headline.trailingAnchor.constraint(lessThanOrEqualTo: mainPane.trailingAnchor, constant: -28),
            subhead.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 4),
            subhead.leadingAnchor.constraint(equalTo: headline.leadingAnchor),
            subhead.trailingAnchor.constraint(lessThanOrEqualTo: mainPane.trailingAnchor, constant: -28),

            searchCard.topAnchor.constraint(equalTo: subhead.bottomAnchor, constant: 18),
            searchCard.leadingAnchor.constraint(equalTo: mainPane.leadingAnchor, constant: 28),
            searchCard.trailingAnchor.constraint(equalTo: mainPane.trailingAnchor, constant: -28),
            searchCard.heightAnchor.constraint(equalToConstant: 44),

            searchIcon.leadingAnchor.constraint(equalTo: searchCard.leadingAnchor, constant: 14),
            searchIcon.centerYAnchor.constraint(equalTo: searchCard.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 16),
            searchIcon.heightAnchor.constraint(equalToConstant: 16),
            clearBtn.trailingAnchor.constraint(equalTo: searchCard.trailingAnchor, constant: -10),
            clearBtn.centerYAnchor.constraint(equalTo: searchCard.centerYAnchor),
            clearBtn.widthAnchor.constraint(equalToConstant: 20),
            clearBtn.heightAnchor.constraint(equalToConstant: 20),
            searchSpinner.trailingAnchor.constraint(equalTo: clearBtn.leadingAnchor, constant: -6),
            searchSpinner.centerYAnchor.constraint(equalTo: searchCard.centerYAnchor),
            searchSpinner.widthAnchor.constraint(equalToConstant: 16),
            searchSpinner.heightAnchor.constraint(equalToConstant: 16),
            queryField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 10),
            queryField.trailingAnchor.constraint(equalTo: searchSpinner.leadingAnchor, constant: -6),
            queryField.topAnchor.constraint(equalTo: searchCard.topAnchor),
            queryField.bottomAnchor.constraint(equalTo: searchCard.bottomAnchor),

            filterStack.topAnchor.constraint(equalTo: searchCard.bottomAnchor, constant: 12),
            filterStack.leadingAnchor.constraint(equalTo: searchCard.leadingAnchor),
            filterStack.trailingAnchor.constraint(equalTo: searchCard.trailingAnchor),
            filterStack.heightAnchor.constraint(equalToConstant: 32),

            scrollView.topAnchor.constraint(equalTo: filterStack.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: mainPane.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: mainPane.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -8),

            footerLabel.leadingAnchor.constraint(equalTo: searchCard.leadingAnchor),
            footerLabel.bottomAnchor.constraint(equalTo: mainPane.bottomAnchor, constant: -14),
            footerLabel.trailingAnchor.constraint(lessThanOrEqualTo: footerHints.leadingAnchor, constant: -12),

            // 快捷键徽章：右下角，文字在徽章内水平+垂直居中
            hotkeyBadge.centerYAnchor.constraint(equalTo: footerLabel.centerYAnchor),
            hotkeyBadge.trailingAnchor.constraint(equalTo: searchCard.trailingAnchor),
            hotkeyBadge.heightAnchor.constraint(equalToConstant: 26),
            hotkeyBadgeLabel.centerXAnchor.constraint(equalTo: hotkeyBadge.centerXAnchor),
            hotkeyBadgeLabel.centerYAnchor.constraint(equalTo: hotkeyBadge.centerYAnchor, constant: -0.5),
            hotkeyBadgeLabel.leadingAnchor.constraint(equalTo: hotkeyBadge.leadingAnchor, constant: 10),
            hotkeyBadgeLabel.trailingAnchor.constraint(equalTo: hotkeyBadge.trailingAnchor, constant: -10),

            footerHints.centerYAnchor.constraint(equalTo: footerLabel.centerYAnchor),
            footerHints.trailingAnchor.constraint(equalTo: hotkeyBadge.leadingAnchor, constant: -12),
        ])

        rebuildCategorySidebar()
        rebuildLocationSidebar()
        applyLocalizedCopy()
        refreshHotkeyBadge()
        AppPrefs.applyAppearance()

        settingsWC.onHotKeyChanged = { [weak self] cfg in
            self?.hotKeyHandler?(cfg)
            self?.refreshHotkeyBadge()
        }
        settingsWC.onRequestRebuild = { [weak self] in self?.rebuildHandler?() }

        NotificationCenter.default.addObserver(
            forName: .ffPrefsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyLocalizedCopy()
            self?.rebuildCategorySidebar()
            self?.rebuildLocationSidebar()
            self?.applyThemeColors()
            self?.refreshHotkeyBadge()
            self?.updateFooter()
            self?.tableView.reloadData()
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            self?.handleKey(e) ?? e
        }
    }

    private func applyLocalizedCopy() {
        locTitle.stringValue = L10n.locations
        headline.stringValue = L10n.searchHeadline
        subhead.stringValue = L10n.searchSubhead
        footerHints.stringValue = L10n.footerHints
        queryField.placeholderString = L10n.searchPlaceholder
        if let cell = queryField.cell as? NSTextFieldCell {
            cell.placeholderAttributedString = NSAttributedString(
                string: L10n.searchPlaceholder,
                attributes: [.font: Theme.songBold(15), .foregroundColor: NSColor.placeholderTextColor]
            )
        }
        typeFilter.item(at: 0)?.title = L10n.type
        timeFilter.item(at: 0)?.title = L10n.modified
        sizeFilter.item(at: 0)?.title = L10n.size
        locFilter.item(at: 0)?.title = L10n.location
        sortPopup.item(at: 0)?.title = currentSort.rawValue
        rebuildContentSearchPopup()
    }

    private func rebuildContentSearchPopup() {
        contentSearchPopup.removeAllItems()
        contentSearchPopup.addItem(withTitle: L10n.contentSearchOff)
        contentSearchPopup.lastItem?.tag = 0
        contentSearchPopup.addItem(withTitle: L10n.contentSearchOn)
        contentSearchPopup.lastItem?.tag = 1
        contentSearchPopup.selectItem(withTag: AppPrefs.contentSearchEnabled ? 1 : 0)
    }

    @objc private func contentSearchModeChanged(_ sender: NSPopUpButton) {
        let wantOn = sender.selectedTag() == 1
        let wasOn = AppPrefs.contentSearchEnabled
        AppPrefs.contentSearchEnabled = wantOn
        if wantOn, !wasOn {
            let alert = NSAlert()
            alert.messageText = L10n.contentSearchAlertTitle
            alert.informativeText = L10n.contentSearchAlertMessage
            alert.alertStyle = .informational
            alert.addButton(withTitle: L10n.contentSearchAlertOK)
            if let window {
                alert.beginSheetModal(for: window) { [weak self] _ in
                    self?.runSearch()
                }
            } else {
                alert.runModal()
                runSearch()
            }
        } else {
            runSearch()
        }
    }

    private func configureFilter(_ btn: NSPopUpButton, title: String, items: [(String, String)], action: Selector) {
        btn.removeAllItems()
        btn.autoenablesItems = false
        // pullsDown 第一项为标题
        btn.pullsDown = true
        btn.addItem(withTitle: title)
        for (label, value) in items {
            let item = NSMenuItem(title: label, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = value
            btn.menu?.addItem(item)
        }
        btn.font = Theme.songBold(12)
    }

    private func styleChipPopup(_ btn: NSPopUpButton) {
        btn.bezelStyle = .rounded
        btn.controlSize = .regular
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(greaterThanOrEqualToConstant: 88).isActive = true
    }

    private func rebuildCategorySidebar() {
        categoryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        categoryButtons.removeAll()
        for cat in IndexEngine.Category.allCases {
            let count = categoryCounts[cat] ?? (cat == .all ? hits.count : 0)
            let row = SidebarRowButton(title: L10n.category(cat), symbol: cat.symbol, count: count)
            row.isSelected = (cat == selectedCategory)
            row.onTap = { [weak self] in
                self?.selectedCategory = cat
                self?.rebuildCategorySidebar()
                self?.runSearch()
            }
            categoryButtons[cat] = row
            categoryStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: categoryStack.widthAnchor).isActive = true
        }
    }

    private func rebuildLocationSidebar() {
        locationStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        locationButtons.removeAll()

        let all = SidebarRowButton(title: L10n.allLocations, symbol: "internaldrive", count: nil)
        all.isSelected = selectedLocationPath == nil
        all.onTap = { [weak self] in
            self?.selectedLocationPath = nil
            self?.rebuildLocationSidebar()
            self?.runSearch()
        }
        locationButtons[""] = all
        locationStack.addArrangedSubview(all)
        all.widthAnchor.constraint(equalTo: locationStack.widthAnchor).isActive = true

        let hd = SidebarRowButton(title: "Macintosh HD", symbol: "desktopcomputer", count: nil)
        hd.isSelected = selectedLocationPath == "/"
        hd.onTap = { [weak self] in
            self?.selectedLocationPath = "/"
            self?.rebuildLocationSidebar()
            self?.runSearch()
        }
        locationButtons["/"] = hd
        locationStack.addArrangedSubview(hd)
        hd.widthAnchor.constraint(equalTo: locationStack.widthAnchor).isActive = true

        for loc in IndexEngine.shared.indexedLocations() where loc.path != "/" {
            let path = loc.path
            let title = L10n.locationTitle(path, fallback: loc.title)
            let row = SidebarRowButton(title: title, symbol: "folder", count: nil)
            row.isSelected = selectedLocationPath == path
            row.onTap = { [weak self] in
                self?.selectedLocationPath = path
                self?.rebuildLocationSidebar()
                self?.runSearch()
            }
            locationButtons[path] = row
            locationStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: locationStack.widthAnchor).isActive = true
        }

        let add = SidebarRowButton(title: L10n.addLocation, symbol: "plus", count: nil)
        add.isAddStyle = true
        add.onTap = { [weak self] in self?.addLocation() }
        locationStack.addArrangedSubview(add)
        add.widthAnchor.constraint(equalTo: locationStack.widthAnchor).isActive = true

        refreshLocFilterMenu()
    }

    private func refreshLocFilterMenu() {
        locFilter.removeAllItems()
        locFilter.pullsDown = true
        locFilter.addItem(withTitle: "位置")
        let all = NSMenuItem(title: "全部位置", action: #selector(locFilterChanged), keyEquivalent: "")
        all.target = self
        all.representedObject = ""
        locFilter.menu?.addItem(all)
        for loc in IndexEngine.shared.indexedLocations() {
            let item = NSMenuItem(title: loc.title, action: #selector(locFilterChanged), keyEquivalent: "")
            item.target = self
            item.representedObject = loc.path
            locFilter.menu?.addItem(item)
        }
    }

    // MARK: - Present

    /// 避免连点开关时重复排队动画
    private var isPresenting = false
    private var isDismissing = false

    func present() {
        guard let window else { return }
        if window.isVisible, !isDismissing {
            // 已在前台：只聚焦，不重做整套动画/重建
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(queryField)
            return
        }
        if isPresenting { return }
        isPresenting = true
        isDismissing = false

        // 轻量刷新：不重建侧边栏、不 reload 整表（打开时最卡的点）
        applyThemeColors(light: true)
        refreshHotkeyBadge()

        let frame = targetFrame(window)
        // display:false 避免 setFrame 同步强制绘制
        window.alphaValue = 0
        window.setFrame(frame, display: false)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(queryField)

        // 仅淡入，不做缩放/位移（复杂 Auto Layout 窗口缩放会明显卡顿）
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            window.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            self?.isPresenting = false
        })

        if !queryField.stringValue.isEmpty { runSearch() }
        else { updateFooter() }
    }

    func dismissAnimated() {
        guard let window, window.isVisible else { return }
        if isDismissing { return }
        isDismissing = true
        isPresenting = false

        // 仅淡出；不做 frame 动画，关闭更顺滑
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            ctx.allowsImplicitAnimation = true
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            window.alphaValue = 1
            self?.isDismissing = false
        })
    }

    private func targetFrame(_ window: NSWindow) -> NSRect {
        let size = window.frame.size.width > 100 ? window.frame.size : NSSize(width: 980, height: 640)
        guard let s = NSScreen.main else { return NSRect(origin: .zero, size: size) }
        let v = s.visibleFrame
        return NSRect(x: v.midX - size.width / 2, y: v.midY - size.height / 2 + 30, width: size.width, height: size.height)
    }

    /// - Parameter light: 打开窗口时用轻量路径（不 reload 表格、不重建按钮颜色过多）
    private func applyThemeColors(light: Bool = false) {
        // 显式按 AppPrefs 解析颜色，避免 layer CGColor 不随外观更新
        sidebar.layer?.backgroundColor = Theme.sidebarBg.cgColor
        mainPane.layer?.backgroundColor = Theme.contentBg.cgColor
        rootView.layer?.borderColor = Theme.subtleBorder.cgColor
        rootView.layer?.backgroundColor = Theme.contentBg.cgColor
        searchCard.layer?.backgroundColor = Theme.contentBg.cgColor
        searchCard.layer?.borderColor = Theme.searchBorder.cgColor
        hotkeyBadge.layer?.backgroundColor = Theme.chipBg.cgColor

        headline.textColor = Theme.titleText
        subhead.textColor = Theme.secondaryText
        brandLabel.textColor = Theme.titleText
        brandIcon.contentTintColor = Theme.accent
        footerLabel.textColor = Theme.secondaryText
        footerHints.textColor = Theme.metaText
        hotkeyBadgeLabel.textColor = Theme.secondaryText
        searchIcon.contentTintColor = Theme.secondaryText
        clearBtn.contentTintColor = Theme.metaText
        sidebarSettingsBtn.contentTintColor = Theme.secondaryText
        locTitle.textColor = Theme.metaText

        // 窗口外观与全局一致
        if let named = NSApp.appearance?.name {
            window?.appearance = NSAppearance(named: named)
        } else {
            window?.appearance = nil
        }

        if light {
            tableView.backgroundColor = .clear
            return
        }

        categoryButtons.values.forEach { $0.refreshColors() }
        locationButtons.values.forEach { $0.refreshColors() }
        tableView.reloadData()
        tableView.backgroundColor = .clear
        updateViewToggle()
    }

    func setIndexStatus(_ text: String) {
        if queryField.stringValue.isEmpty {
            footerLabel.stringValue = text
        }
    }

    func updateHotKeyHint() { refreshHotkeyBadge() }

    private func refreshHotkeyBadge() {
        hotkeyBadgeLabel.stringValue = HotKeyConfig.load().display
    }

    // MARK: - Search

    private func buildOptions() -> IndexEngine.SearchOptions {
        var opt = IndexEngine.SearchOptions()
        opt.category = selectedCategory
        opt.locationPrefix = selectedLocationPath
        opt.sort = currentSort
        opt.limit = 200
        opt.alwaysEnrich = true
        opt.fileExtension = filterExt
        opt.minSize = filterMinSize
        opt.maxSize = filterMaxSize
        opt.searchContent = AppPrefs.contentSearchEnabled
        if let days = filterModifiedDays {
            opt.modifiedAfter = Calendar.current.date(byAdding: .day, value: -days, to: Date())
        }
        return opt
    }

    private func runSearch() {
        let q = queryField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        clearBtn.isHidden = q.isEmpty
        searchGeneration += 1
        let gen = searchGeneration
        var opt = buildOptions()

        // 类型筛选里的特殊值
        if filterExt == "folder" {
            opt.category = .folder
            opt.fileExtension = nil
        } else if filterExt == "app" {
            opt.category = .app
            opt.fileExtension = nil
        } else if filterExt == "image" {
            opt.fileExtension = nil // 后过滤
        }

        if q.isEmpty {
            setSearching(false)
            hits = []
            categoryCounts = [:]
            lastMs = 0
            tableView.reloadData()
            rebuildCategorySidebar()
            updateFooter()
            return
        }

        let wantContent = opt.searchContent
        let groupFilter = filterExt
        // 正文搜索较慢：立刻显示转圈 + 底部提示；文件名先出结果
        setSearching(true, content: wantContent)

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self else { return }

            // 第一阶段：仅文件名（毫秒级），先让用户看到结果
            var nameOpt = opt
            nameOpt.searchContent = false
            let nameResult = IndexEngine.shared.search(query: q, options: nameOpt)
            var nameList = nameResult.hits
            if let g = groupFilter, ["image", "doc", "sheet", "slide", "video", "audio", "archive", "code"].contains(g) {
                nameList = nameList.filter { Self.matchesGroup(g, hit: $0) }
            }

            DispatchQueue.main.async {
                guard gen == self.searchGeneration else { return }
                self.applySearchResults(hits: nameList, counts: nameResult.counts, ms: nameResult.elapsedMs)
                if wantContent {
                    // 文件名结果已出，继续提示正在搜正文
                    self.setSearching(true, content: true)
                } else {
                    self.setSearching(false)
                }
            }

            guard wantContent else { return }

            // 第二阶段：含正文（Spotlight，可能数秒）
            let fullResult = IndexEngine.shared.search(query: q, options: opt)
            var fullList = fullResult.hits
            if let g = groupFilter, ["image", "doc", "sheet", "slide", "video", "audio", "archive", "code"].contains(g) {
                fullList = fullList.filter { Self.matchesGroup(g, hit: $0) }
            }
            DispatchQueue.main.async {
                guard gen == self.searchGeneration else { return }
                self.applySearchResults(hits: fullList, counts: fullResult.counts, ms: fullResult.elapsedMs)
                self.setSearching(false)
            }
        }
    }

    private func applySearchResults(hits list: [IndexEngine.Hit], counts: [IndexEngine.Category: Int], ms: Double) {
        hits = list
        categoryCounts = counts
        lastMs = ms
        tableView.reloadData()
        if !list.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        rebuildCategorySidebar()
        updateFooter()
    }

    private func setSearching(_ on: Bool, content: Bool = false) {
        isSearching = on
        searchingIsContent = on && content
        if on {
            searchSpinner.isHidden = false
            searchSpinner.startAnimation(nil)
        } else {
            searchSpinner.stopAnimation(nil)
            searchSpinner.isHidden = true
        }
        updateFooter()
    }

    private static func matchesGroup(_ g: String, hit: IndexEngine.Hit) -> Bool {
        let e = hit.fileExtension
        switch g {
        case "image": return ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp", "svg"].contains(e)
        case "doc": return ["pdf", "doc", "docx", "txt", "rtf", "md", "pages"].contains(e)
        case "sheet": return ["xls", "xlsx", "csv", "numbers"].contains(e)
        case "slide": return ["ppt", "pptx", "key"].contains(e)
        case "video": return ["mp4", "mov", "m4v", "avi", "mkv", "webm"].contains(e)
        case "audio": return ["mp3", "wav", "aac", "m4a", "flac", "aiff"].contains(e)
        case "archive": return ["zip", "rar", "7z", "tar", "gz", "dmg"].contains(e)
        case "code": return ["swift", "py", "js", "ts", "java", "go", "rs", "c", "cpp", "h", "json", "xml", "html", "css"].contains(e)
        default: return true
        }
    }

    private func updateFooter() {
        if queryField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            footerLabel.stringValue = IndexEngine.shared.isIndexing
                ? String(format: L10n.indexingFormat, IndexEngine.shared.fileCount)
                : String(format: L10n.indexFormat, IndexEngine.shared.fileCount)
            return
        }

        if isSearching {
            if searchingIsContent {
                // 已有文件名结果时，说明在补充正文
                if hits.isEmpty {
                    footerLabel.stringValue = L10n.searchingContentHint
                } else {
                    footerLabel.stringValue = String(format: L10n.foundFormat, hits.count, lastMs)
                        + " · "
                        + L10n.searchingContent
                }
            } else {
                footerLabel.stringValue = L10n.searching
            }
            return
        }

        var s = String(format: L10n.foundFormat, hits.count, lastMs)
        if AppPrefs.contentSearchEnabled {
            let contentOnly = hits.filter { $0.matchKind == .content }.count
            let both = hits.filter { $0.matchKind == .both }.count
            if contentOnly + both > 0 {
                s += L10n.t(" · 含内容命中 \(contentOnly + both)", " · content hits \(contentOnly + both)")
            } else if lastMs > 500 {
                s += L10n.t(" · 正文无额外命中（依赖系统 Spotlight）", " · no extra content hits (Spotlight)")
            }
        }
        footerLabel.stringValue = s
    }

    // MARK: - Filters actions

    @objc private func typeFilterChanged(_ sender: NSMenuItem) {
        let v = sender.representedObject as? String ?? ""
        filterExt = v.isEmpty ? nil : v
        typeFilter.item(at: 0)?.title = v.isEmpty ? "类型" : sender.title
        runSearch()
    }

    @objc private func timeFilterChanged(_ sender: NSMenuItem) {
        let v = sender.representedObject as? String ?? ""
        filterModifiedDays = Int(v)
        timeFilter.item(at: 0)?.title = v.isEmpty ? "修改时间" : sender.title
        runSearch()
    }

    @objc private func sizeFilterChanged(_ sender: NSMenuItem) {
        let v = sender.representedObject as? String ?? ""
        filterMinSize = nil
        filterMaxSize = nil
        if v == "0-1" { filterMaxSize = 1_000_000 }
        else if v == "1-10" { filterMinSize = 1_000_000; filterMaxSize = 10_000_000 }
        else if v == "10-100" { filterMinSize = 10_000_000; filterMaxSize = 100_000_000 }
        else if v == "100-" { filterMinSize = 100_000_000 }
        sizeFilter.item(at: 0)?.title = v.isEmpty ? "大小" : sender.title
        runSearch()
    }

    @objc private func locFilterChanged(_ sender: NSMenuItem) {
        let v = sender.representedObject as? String ?? ""
        selectedLocationPath = v.isEmpty ? nil : v
        locFilter.item(at: 0)?.title = v.isEmpty ? "位置" : sender.title
        rebuildLocationSidebar()
        runSearch()
    }

    @objc private func sortChanged(_ sender: NSMenuItem) {
        let t = sender.title
        if let k = IndexEngine.SortKey(rawValue: t) {
            currentSort = k
            sortPopup.item(at: 0)?.title = t
            runSearch()
        }
    }

    @objc private func clearQuery() {
        queryField.stringValue = ""
        runSearch()
        window?.makeFirstResponder(queryField)
    }

    @objc private func showList() { isListView = true; updateViewToggle(); tableView.rowHeight = 56; tableView.reloadData() }
    @objc private func showGrid() { isListView = false; updateViewToggle(); tableView.rowHeight = 88; tableView.reloadData() }

    private func updateViewToggle() {
        listViewBtn.contentTintColor = isListView ? Theme.accent : Theme.secondaryText
        gridViewBtn.contentTintColor = !isListView ? Theme.accent : Theme.secondaryText
    }

    @objc func openSettings() { settingsWC.present() }

    private func addLocation() {
        let p = NSOpenPanel()
        p.canChooseFiles = false
        p.canChooseDirectories = true
        p.allowsMultipleSelection = false
        p.prompt = "添加"
        p.message = "选择要纳入索引的文件夹"
        p.begin { [weak self] r in
            guard r == .OK, let url = p.url else { return }
            IndexEngine.shared.addRoot(url)
            self?.rebuildLocationSidebar()
        }
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { hits.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier(isListView ? "list" : "grid")
        let cell = (tableView.makeView(withIdentifier: id, owner: nil) as? ResultRowView) ?? ResultRowView(style: isListView ? .list : .grid)
        cell.identifier = id
        if row < hits.count { cell.configure(hits[row]) }
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { SoftRowView() }

    // MARK: - Menu / actions

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        contextRow = row
        guard row >= 0, row < hits.count else { return }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        for (t, sel) in [
            ("打开", #selector(ctxOpen)),
            ("在访达中显示", #selector(ctxReveal)),
            ("定位到所在文件夹", #selector(ctxParent)),
            ("—", #selector(ctxOpen)),
            ("复制路径", #selector(ctxCopy)),
        ] as [(String, Selector)] {
            if t == "—" { menu.addItem(.separator()); continue }
            let it = NSMenuItem(title: t, action: sel, keyEquivalent: "")
            it.target = self
            menu.addItem(it)
        }
    }

    @objc private func ctxOpen() { open(at: contextRow) }
    @objc private func ctxReveal() { reveal(at: contextRow) }
    @objc private func ctxParent() { reveal(at: contextRow) }
    @objc private func ctxCopy() {
        guard contextRow >= 0, contextRow < hits.count else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hits[contextRow].path, forType: .string)
    }
    @objc private func openSelected() { open(at: tableView.selectedRow) }

    private func open(at row: Int) {
        guard row >= 0, row < hits.count else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: hits[row].path))
    }
    private func reveal(at row: Int) {
        guard row >= 0, row < hits.count else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: hits[row].path)])
    }

    private func handleKey(_ e: NSEvent) -> NSEvent? {
        guard window?.isKeyWindow == true else { return e }
        if settingsWC.window?.isVisible == true { return e }
        switch e.keyCode {
        case 53: dismissAnimated(); return nil
        case 36, 76:
            if e.modifierFlags.contains(.command) { reveal(at: tableView.selectedRow) }
            else { open(at: tableView.selectedRow) }
            return nil
        case 125: move(1); return nil
        case 126: move(-1); return nil
        case 8 where e.modifierFlags.contains(.command):
            let r = tableView.selectedRow
            if r >= 0, r < hits.count {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(hits[r].path, forType: .string)
            }
            return nil
        default: return e
        }
    }

    private func move(_ d: Int) {
        guard !hits.isEmpty else { return }
        var r = max(0, tableView.selectedRow)
        r = max(0, min(hits.count - 1, r + d))
        tableView.selectRowIndexes(IndexSet(integer: r), byExtendingSelection: false)
        tableView.scrollRowToVisible(r)
    }

    func controlTextDidChange(_ obj: Notification) { runSearch() }
    func windowDidBecomeKey(_ notification: Notification) { window?.makeFirstResponder(queryField) }
}

// MARK: - Sidebar row

private final class SidebarRowButton: NSView {
    var onTap: (() -> Void)?
    var isSelected = false { didSet { needsDisplay = true; apply() } }
    var isAddStyle = false
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let badge = NSTextField(labelWithString: "")

    init(title: String, symbol: String, count: Int?) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 32).isActive = true

        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.image?.isTemplate = true
        icon.translatesAutoresizingMaskIntoConstraints = false
        label.stringValue = title
        label.font = Theme.songBold(12.5)
        label.translatesAutoresizingMaskIntoConstraints = false
        badge.font = Theme.songBold(11)
        badge.textColor = Theme.metaText
        badge.alignment = .right
        badge.translatesAutoresizingMaskIntoConstraints = false
        if let count { badge.stringValue = "\(count)" } else { badge.stringValue = "" }

        addSubview(icon)
        addSubview(label)
        addSubview(badge)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 14),
            icon.heightAnchor.constraint(equalToConstant: 14),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: badge.leadingAnchor, constant: -4),
        ])
        apply()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func apply() {
        if isSelected {
            layer?.backgroundColor = Theme.accentSoft.cgColor
            label.textColor = Theme.accent
            icon.contentTintColor = Theme.accent
            badge.textColor = Theme.accent
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            label.textColor = isAddStyle ? Theme.secondaryText : Theme.titleText
            icon.contentTintColor = Theme.secondaryText
            badge.textColor = Theme.metaText
        }
    }

    func refreshColors() { apply() }

    override func mouseDown(with event: NSEvent) { onTap?() }
    override func draw(_ dirtyRect: NSRect) { /* layer backed */ }
}

// MARK: - Result row

private final class ResultRowView: NSTableCellView {
    enum Style { case list, grid }
    private let style: Style
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(labelWithString: "")
    private let sizeLabel = NSTextField(labelWithString: "")
    private let dateLabel = NSTextField(labelWithString: "")
    private let matchBadge = NSTextField(labelWithString: "")

    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        nameLabel.font = Theme.songBold(13.5)
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.font = Theme.songBold(11)
        pathLabel.textColor = Theme.secondaryText
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        sizeLabel.font = Theme.songBold(11)
        sizeLabel.textColor = Theme.secondaryText
        sizeLabel.alignment = .right
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = Theme.songBold(11)
        dateLabel.textColor = Theme.metaText
        dateLabel.alignment = .right
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        matchBadge.font = Theme.songBold(10)
        matchBadge.alignment = .center
        matchBadge.isBezeled = false
        matchBadge.drawsBackground = false
        matchBadge.isEditable = false
        matchBadge.wantsLayer = true
        matchBadge.layer?.cornerRadius = 4
        matchBadge.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(nameLabel)
        addSubview(pathLabel)
        addSubview(sizeLabel)
        addSubview(dateLabel)
        addSubview(matchBadge)

        let iconSize: CGFloat = style == .list ? 28 : 40
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: iconSize),
            iconView.heightAnchor.constraint(equalToConstant: iconSize),

            dateLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            dateLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            dateLabel.widthAnchor.constraint(equalToConstant: 88),

            sizeLabel.trailingAnchor.constraint(equalTo: dateLabel.leadingAnchor, constant: -12),
            sizeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            sizeLabel.widthAnchor.constraint(equalToConstant: 72),

            matchBadge.trailingAnchor.constraint(equalTo: sizeLabel.leadingAnchor, constant: -8),
            matchBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            matchBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 36),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: matchBadge.leadingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: style == .list ? 10 : 12),

            pathLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            pathLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            pathLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(_ hit: IndexEngine.Hit) {
        nameLabel.stringValue = hit.name
        var p = hit.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if p.hasPrefix(home) { p = "~" + p.dropFirst(home.count) }
        pathLabel.stringValue = p
        iconView.image = NSWorkspace.shared.icon(forFile: hit.path)
        if hit.isDirectory {
            sizeLabel.stringValue = "—"
        } else if hit.fileSize >= 0 {
            sizeLabel.stringValue = Self.humanSize(hit.fileSize)
        } else {
            sizeLabel.stringValue = ""
        }
        dateLabel.stringValue = hit.modifiedAt.map { Self.fmtDate($0) } ?? ""

        switch hit.matchKind {
        case .name:
            matchBadge.stringValue = ""
            matchBadge.isHidden = true
        case .content:
            matchBadge.isHidden = false
            matchBadge.stringValue = " \(L10n.matchContent) "
            matchBadge.textColor = Theme.accent
            matchBadge.layer?.backgroundColor = Theme.accentSoft.cgColor
        case .both:
            matchBadge.isHidden = false
            matchBadge.stringValue = " \(L10n.matchBoth) "
            matchBadge.textColor = Theme.accent
            matchBadge.layer?.backgroundColor = Theme.accentSoft.cgColor
        }
    }

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    private static func fmtDate(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) {
            df.dateFormat = "今天 HH:mm"
        } else if cal.isDateInYesterday(d) {
            df.dateFormat = "昨天 HH:mm"
        } else {
            df.dateFormat = "yyyy/MM/dd"
        }
        return df.string(from: d)
    }

    private static func humanSize(_ n: Int64) -> String {
        let u = ["B", "KB", "MB", "GB"]
        var s = Double(n), i = 0
        while s >= 1024 && i < u.count - 1 { s /= 1024; i += 1 }
        return i == 0 ? "\(Int(s)) B" : String(format: "%.1f %@", s, u[i])
    }
}

private final class SoftRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 8, dy: 2), xRadius: 10, yRadius: 10)
        Theme.accentSoft.setFill()
        path.fill()
    }
    override var interiorBackgroundStyle: NSView.BackgroundStyle { .normal }
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
