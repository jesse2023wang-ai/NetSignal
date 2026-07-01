import Cocoa

class SettingsWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.title = "NetSignal 设置"
        self.center()
        self.contentView = SettingsView(frame: NSRect(x: 0, y: 0, width: 560, height: 520))
    }
}

class SettingsView: NSView {
    private var websiteTable: NSTableView!
    private var websiteScrollView: NSScrollView!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        let view = self
        let W = 520

        // ===== Section 1: 通用设置 =====
        let settingsTitle = NSTextField(labelWithString: "通用设置")
        settingsTitle.font = NSFont.boldSystemFont(ofSize: 13)
        settingsTitle.frame = NSRect(x: 20, y: 488, width: 200, height: 20)
        view.addSubview(settingsTitle)

        let launchCheckbox = NSButton(checkboxWithTitle: "开机自动启动", target: self, action: #selector(launchAtLoginChanged(_:)))
        launchCheckbox.state = LaunchAtLoginHelper.isEnabled() ? .on : .off
        launchCheckbox.frame = NSRect(x: 20, y: 460, width: 200, height: 22)
        view.addSubview(launchCheckbox)

        let autoRefreshCheckbox = NSButton(checkboxWithTitle: "自动刷新", target: self, action: #selector(autoRefreshChanged(_:)))
        autoRefreshCheckbox.state = Preferences.shared.autoRefresh ? .on : .off
        autoRefreshCheckbox.frame = NSRect(x: 20, y: 434, width: 200, height: 22)
        view.addSubview(autoRefreshCheckbox)

        let intervalLabel = NSTextField(labelWithString: "刷新间隔: \(Int(Preferences.shared.refreshInterval)) 秒")
        intervalLabel.frame = NSRect(x: 20, y: 412, width: 200, height: 16)
        intervalLabel.tag = 201
        intervalLabel.isEnabled = Preferences.shared.autoRefresh
        intervalLabel.textColor = Preferences.shared.autoRefresh ? .labelColor : .secondaryLabelColor
        view.addSubview(intervalLabel)

        let slider = NSSlider(value: Preferences.shared.refreshInterval, minValue: 10, maxValue: 300, target: self, action: #selector(refreshIntervalChanged(_:)))
        slider.frame = NSRect(x: 20, y: 392, width: 300, height: 18)
        slider.tag = 202
        slider.isEnabled = Preferences.shared.autoRefresh
        view.addSubview(slider)

        // ===== Section 2: 分隔线 =====
        let separator = NSBox()
        separator.boxType = .separator
        separator.frame = NSRect(x: 16, y: 360, width: W, height: 1)
        view.addSubview(separator)

        // ===== Section 3: 网站管理 =====
        let webTitle = NSTextField(labelWithString: "检测网址")
        webTitle.font = NSFont.boldSystemFont(ofSize: 13)
        webTitle.frame = NSRect(x: 20, y: 338, width: 200, height: 20)
        view.addSubview(webTitle)

        let resetButton = NSButton(title: "重置", target: self, action: #selector(resetDefaults))
        resetButton.frame = NSRect(x: 20, y: 310, width: 80, height: 24)
        resetButton.bezelStyle = .rounded
        view.addSubview(resetButton)

        let addButton = NSButton(title: "添加", target: self, action: #selector(addWebsite))
        addButton.frame = NSRect(x: 420, y: 310, width: 80, height: 24)
        addButton.bezelStyle = .rounded
        addButton.font = NSFont.boldSystemFont(ofSize: 12)
        view.addSubview(addButton)

        // ===== Section 4: 网站列表 =====
        websiteTable = NSTableView()
        websiteTable.usesAlternatingRowBackgroundColors = true
        websiteTable.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        websiteTable.backgroundColor = NSColor.controlBackgroundColor

        let colName = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        colName.title = "名称"
        colName.width = 80
        colName.minWidth = 50
        colName.headerToolTip = "点击按名称排序"
        colName.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true)
        websiteTable.addTableColumn(colName)

        let colURL = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("url"))
        colURL.title = "地址"
        colURL.width = 120
        colURL.maxWidth = 150
        colURL.minWidth = 80
        colURL.headerToolTip = "点击按地址排序"
        colURL.sortDescriptorPrototype = NSSortDescriptor(key: "url", ascending: true)
        websiteTable.addTableColumn(colURL)

        let colType = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        colType.title = "类型"
        colType.width = 60
        colType.minWidth = 50
        colType.headerToolTip = "点击按类型排序"
        colType.sortDescriptorPrototype = NSSortDescriptor(key: "type", ascending: true)
        websiteTable.addTableColumn(colType)

        let colEnabled = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled"))
        colEnabled.title = "启用"
        colEnabled.width = 50
        colEnabled.minWidth = 40
        colEnabled.headerToolTip = "点击按启用状态排序"
        colEnabled.sortDescriptorPrototype = NSSortDescriptor(key: "enabled", ascending: true)
        websiteTable.addTableColumn(colEnabled)

        let colActions = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("actions"))
        colActions.title = "操作"
        colActions.width = 50
        colActions.minWidth = 40
        websiteTable.addTableColumn(colActions)

        websiteTable.delegate = self
        websiteTable.dataSource = self
        websiteTable.rowHeight = 30
        websiteTable.sortDescriptors = [NSSortDescriptor(key: "type", ascending: true)]

        // 初始按类型排序
        Preferences.shared.websites = Preferences.shared.websites.sorted { a, b in
            !a.isDomestic && b.isDomestic
        }

        websiteScrollView = NSScrollView(frame: NSRect(x: 20, y: 16, width: W - 40, height: 270))
        websiteScrollView.hasVerticalScroller = true
        websiteScrollView.hasHorizontalScroller = false
        websiteScrollView.autohidesScrollers = false
        websiteScrollView.borderType = .bezelBorder
        websiteScrollView.documentView = websiteTable

        view.addSubview(websiteScrollView)
    }

    // MARK: - Actions

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        let enabled = sender.state == .on
        Preferences.shared.launchAtLogin = enabled
        LaunchAtLoginHelper.setEnabled(enabled)
    }

    @objc private func autoRefreshChanged(_ sender: NSButton) {
        let enabled = sender.state == .on
        Preferences.shared.autoRefresh = enabled
        if let label = self.viewWithTag(201) as? NSTextField {
            label.isEnabled = enabled
            label.textColor = enabled ? NSColor.labelColor : NSColor.secondaryLabelColor
        }
        if let slider = self.viewWithTag(202) as? NSSlider {
            slider.isEnabled = enabled
        }
        NotificationCenter.default.post(name: .autoRefreshChanged, object: nil)
    }

    @objc private func refreshIntervalChanged(_ sender: NSSlider) {
        let interval = round(sender.doubleValue / 10) * 10
        Preferences.shared.refreshInterval = interval
        if let label = self.window?.contentView?.viewWithTag(201) as? NSTextField {
            label.stringValue = "刷新间隔: \(Int(interval)) 秒"
        }
    }

    @objc private func resetDefaults() {
        Preferences.shared.resetToDefaults()
        reloadWebsiteTable()
        NotificationCenter.default.post(name: .websitesDidChange, object: nil)
    }

    @objc private func addWebsite() {
        let alert = NSAlert()
        alert.messageText = "添加检测网址"
        alert.informativeText = "请输入网站名称和地址："
        // 加载应用图标替代默认占位符
        let appIcon = SignalIcon.drawAppIcon(size: NSSize(width: 32, height: 32))
        alert.icon = appIcon

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 120))

        let nameLabel = NSTextField(labelWithString: "名称:")
        nameLabel.frame = NSRect(x: 0, y: 90, width: 40, height: 20)
        accessory.addSubview(nameLabel)

        let nameField = NSTextField()
        nameField.frame = NSRect(x: 50, y: 88, width: 250, height: 24)
        nameField.placeholderString = "例如：百度"
        accessory.addSubview(nameField)

        let urlLabel = NSTextField(labelWithString: "地址:")
        urlLabel.frame = NSRect(x: 0, y: 54, width: 40, height: 20)
        accessory.addSubview(urlLabel)

        let urlField = NSTextField()
        urlField.frame = NSRect(x: 50, y: 52, width: 250, height: 24)
        urlField.placeholderString = "https://www.baidu.com"
        accessory.addSubview(urlField)

        let typeLabel = NSTextField(labelWithString: "类型:")
        typeLabel.frame = NSRect(x: 0, y: 18, width: 40, height: 20)
        accessory.addSubview(typeLabel)

        let typeSegment = NSSegmentedControl(labels: ["国内", "海外"], trackingMode: .selectOne, target: nil, action: nil)
        typeSegment.frame = NSRect(x: 50, y: 16, width: 140, height: 24)
        typeSegment.selectedSegment = 0
        accessory.addSubview(typeSegment)

        alert.accessoryView = accessory
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let url = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !url.isEmpty else { return }
            let finalURL = url.hasPrefix("http") ? url : "https://\(url)"
            let isDomestic = typeSegment.selectedSegment == 0
            let website = Website(name: name, url: finalURL, isDomestic: isDomestic)
            Preferences.shared.websites.append(website)
            reloadWebsiteTable()
            NotificationCenter.default.post(name: .websitesDidChange, object: nil)
        }
    }

    private func reloadWebsiteTable() {
        websiteTable?.reloadData()
    }
}

// MARK: - NSTableViewDataSource & Delegate

extension SettingsView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return Preferences.shared.websites.count
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sort = tableView.sortDescriptors.first else {
            tableView.reloadData()
            return
        }
        let websites = Preferences.shared.websites
        Preferences.shared.websites = websites.sorted { a, b in
            guard let key = sort.key else { return false }
            switch key {
            case "name":
                return sort.ascending ? a.name < b.name : a.name > b.name
            case "url":
                return sort.ascending ? a.url < b.url : a.url > b.url
            case "type":
                return sort.ascending ? (!a.isDomestic && b.isDomestic) : (a.isDomestic && !b.isDomestic)
            case "enabled":
                return sort.ascending ? (!a.isEnabled && b.isEnabled) : (a.isEnabled && !b.isEnabled)
            default:
                return false
            }
        }
        tableView.reloadData()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let websites = Preferences.shared.websites
        guard row < websites.count else { return nil }
        let website = websites[row]

        let reuseID = NSUserInterfaceItemIdentifier("cell.\(row)")
        var cellView = tableView.makeView(withIdentifier: reuseID, owner: self) as? NSTableCellView
        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = reuseID
        }
        cellView?.subviews.forEach { $0.removeFromSuperview() }

        switch tableColumn?.identifier.rawValue {
        case "name":
            let label = NSTextField(labelWithString: website.name)
            label.font = NSFont.systemFont(ofSize: 12)
            label.translatesAutoresizingMaskIntoConstraints = false
            cellView?.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 4),
                label.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        case "url":
            let label = NSTextField(labelWithString: website.url)
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
            label.lineBreakMode = .byTruncatingTail
            label.translatesAutoresizingMaskIntoConstraints = false
            cellView?.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 4),
                label.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        case "type":
            let label = NSTextField(labelWithString: website.isDomestic ? "国内" : "海外")
            label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            label.textColor = website.isDomestic ? .systemGreen : .systemBlue
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            cellView?.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: cellView!.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        case "enabled":
            let cb = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleWebsite(_:)))
            cb.state = website.isEnabled ? .on : .off
            cb.tag = row
            cb.translatesAutoresizingMaskIntoConstraints = false
            cellView?.addSubview(cb)
            NSLayoutConstraint.activate([
                cb.centerXAnchor.constraint(equalTo: cellView!.centerXAnchor),
                cb.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        case "actions":
            let btn = NSButton()
            btn.title = ""
            btn.bezelStyle = .smallSquare
            btn.tag = row
            btn.attributedTitle = NSAttributedString(
                string: "✕",
                attributes: [
                    .foregroundColor: NSColor.systemRed,
                    .font: NSFont.systemFont(ofSize: 12, weight: .bold)
                ]
            )
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.target = self
            btn.action = #selector(deleteWebsite(_:))
            cellView?.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.widthAnchor.constraint(equalToConstant: 18),
                btn.heightAnchor.constraint(equalToConstant: 18),
                btn.centerXAnchor.constraint(equalTo: cellView!.centerXAnchor),
                btn.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        default:
            return nil
        }

        return cellView
    }

    @objc private func toggleWebsite(_ sender: NSButton) {
        let row = sender.tag
        guard row < Preferences.shared.websites.count else { return }
        Preferences.shared.websites[row].isEnabled = (sender.state == .on)
        NotificationCenter.default.post(name: .websitesDidChange, object: nil)
    }

    @objc private func deleteWebsite(_ sender: NSButton) {
        let row = sender.tag
        guard row < Preferences.shared.websites.count else { return }
        let website = Preferences.shared.websites[row]

        let alert = NSAlert()
        alert.messageText = "删除网站"
        alert.informativeText = "确定要删除 \(website.name)？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        alert.beginSheetModal(for: self.window!) { response in
            if response == .alertFirstButtonReturn {
                Preferences.shared.websites.remove(at: row)
                self.reloadWebsiteTable()
                NotificationCenter.default.post(name: .websitesDidChange, object: nil)
            }
        }
    }
}
