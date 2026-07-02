import Cocoa

class StatusBarController: NSObject, NetworkMonitorDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem
    private var timer: Timer?
    private var countdownTimer: Timer?
    private var currentResults: [WebsiteResult] = []
    private var currentQuality: NetworkQuality = .noSignal
    private var isRefreshing = false
    private var lastTestTime: Date = .distantPast

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            let prefs = Preferences.shared
            button.image = SignalIcon.generateImage(quality: .noSignal, colorful: prefs.useColorfulIcon)
            button.imagePosition = .imageOnly
            button.toolTip = "NetSignal"
            button.target = self
            button.action = #selector(handleClick)
        }

        NetworkMonitor.shared.delegate = self
        buildMenu()
        startAutoRefresh()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iconStyleDidChange),
            name: .iconStyleChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(websitesDidChange),
            name: .websitesDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(autoRefreshDidChange),
            name: .autoRefreshChanged,
            object: nil
        )
    }

    @objc private func iconStyleDidChange() {
        let prefs = Preferences.shared
        statusItem.button?.image = SignalIcon.generateImage(quality: currentQuality, colorful: prefs.useColorfulIcon)
    }

    @objc private func websitesDidChange() {
        rebuildMenu()
        lastTestTime = Date()
        NetworkMonitor.shared.testAllWebsites()
    }

    @objc private func autoRefreshDidChange() {
        rebuildMenu()
    }

    @objc private func handleClick(_ sender: Any) {
        guard let menu = self.statusItem.menu else { return }
        if let button = self.statusItem.button, let window = button.window {
            let frame = button.convert(button.bounds, to: nil)
            let screenPoint = window.convertToScreen(frame)
            let menuOrigin = NSPoint(x: screenPoint.minX, y: screenPoint.minY - 5)
            menu.popUp(positioning: nil, at: menuOrigin, in: nil)
        } else {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = true
        menu.delegate = self
        let prefs = Preferences.shared

        // 状态标题
        let titleItem = NSMenuItem(title: "NetSignal - 网络状态监测", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // 网络质量
        let qualityItem = NSMenuItem(title: "网络质量: 检测中...", action: nil, keyEquivalent: "")
        qualityItem.isEnabled = false
        qualityItem.tag = 100
        menu.addItem(qualityItem)
        menu.addItem(NSMenuItem.separator())

        // 国内网站
        let domesticTitle = NSMenuItem(title: "  国内网站", action: nil, keyEquivalent: "")
        domesticTitle.isEnabled = false
        menu.addItem(domesticTitle)

        for website in prefs.websites.filter({ $0.isDomestic && $0.isEnabled }) {
            let item = NSMenuItem(title: "    \(website.name): 等待检测...", action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.tag = website.id.hashValue
            menu.addItem(item)
        }

        // 海外网站（仅在全局模式下显示）
        if prefs.environmentMode == .global {
            menu.addItem(NSMenuItem.separator())
            let overseasTitle = NSMenuItem(title: "  海外网站", action: nil, keyEquivalent: "")
            overseasTitle.isEnabled = false
            menu.addItem(overseasTitle)

            for website in prefs.websites.filter({ !$0.isDomestic && $0.isEnabled }) {
                let item = NSMenuItem(title: "    \(website.name): 等待检测...", action: nil, keyEquivalent: "")
                item.isEnabled = false
                item.tag = website.id.hashValue
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // 下一次刷新倒计时（仅在自动刷新开启时显示）
        let countdownItem = NSMenuItem(title: "下一次刷新", action: nil, keyEquivalent: "")
        countdownItem.isEnabled = false
        countdownItem.tag = 200
        countdownItem.isHidden = !Preferences.shared.autoRefresh
        menu.addItem(countdownItem)

        // 立即刷新
        let refreshItem = NSMenuItem(title: "立即刷新", action: #selector(refreshClicked), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        // 环境切换子菜单
        let envMenu = NSMenu()
        let domesticItem = NSMenuItem(title: "仅国内", action: #selector(setDomesticMode), keyEquivalent: "")
        domesticItem.target = self
        domesticItem.state = prefs.environmentMode == .domesticOnly ? .on : .off
        envMenu.addItem(domesticItem)

        let globalItem = NSMenuItem(title: "全球", action: #selector(setGlobalMode), keyEquivalent: "")
        globalItem.target = self
        globalItem.state = prefs.environmentMode == .global ? .on : .off
        envMenu.addItem(globalItem)

        // 环境切换 — 状态文字灰色且靠近 ▸
        let envMode = prefs.environmentMode == .global ? "全球" : "仅国内"
        let envAttr = NSMutableAttributedString(string: "环境切换")
        envAttr.append(NSAttributedString(string: "  \(envMode)", attributes: [.foregroundColor: NSColor.secondaryLabelColor]))
        let envItem = NSMenuItem()
        envItem.attributedTitle = envAttr
        envItem.submenu = envMenu
        menu.addItem(envItem)

        // 彩色图标子菜单
        let colorMenu = NSMenu()
        let colorOn = NSMenuItem(title: "开启", action: #selector(setColorfulOn), keyEquivalent: "")
        colorOn.target = self
        colorOn.state = prefs.useColorfulIcon ? .on : .off
        colorMenu.addItem(colorOn)

        let colorOff = NSMenuItem(title: "关闭", action: #selector(setColorfulOff), keyEquivalent: "")
        colorOff.target = self
        colorOff.state = prefs.useColorfulIcon ? .off : .on
        colorMenu.addItem(colorOff)

        let colorStatus = prefs.useColorfulIcon ? "开启" : "关闭"
        let colorAttr = NSMutableAttributedString(string: "彩色图标")
        colorAttr.append(NSAttributedString(string: "  \(colorStatus)", attributes: [.foregroundColor: NSColor.secondaryLabelColor]))
        let colorfulItem = NSMenuItem()
        colorfulItem.attributedTitle = colorAttr
        colorfulItem.submenu = colorMenu
        menu.addItem(colorfulItem)

        menu.addItem(NSMenuItem.separator())

        // 设置
        let settingsItem = NSMenuItem(title: "设置...", action: #selector(settingsClicked), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // 关于
        let aboutItem = NSMenuItem(title: "关于", action: #selector(aboutClicked), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        // 检查更新
        let updateItem = NSMenuItem(title: "检查更新", action: #selector(updateClicked), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        // 退出
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        menu.delegate = self
    }

    private func updateMenuItems() {
        guard let menu = statusItem.menu else { return }

        if let qualityItem = menu.item(withTag: 100) {
            let qualityText = isRefreshing ? "检测中..." : currentQuality.description
            qualityItem.title = "网络质量: \(qualityText)"
        }

        for result in currentResults {
            let tag = result.website.id.hashValue
            if let menuItem = menu.item(withTag: tag) {
                if result.status == .timeout {
                    menuItem.title = "    \(result.website.name): 超时"
                    menuItem.attributedTitle = NSAttributedString(
                        string: "    \(result.website.name): 超时",
                        attributes: [.foregroundColor: NSColor.systemGray]
                    )
                } else {
                    let timeStr = String(format: "%.0fms", result.responseTime)
                    menuItem.title = "    \(result.website.name): \(timeStr)"
                    let color = NSColor.fromHex(result.status.colorHex)
                    menuItem.attributedTitle = NSAttributedString(
                        string: "    \(result.website.name): \(timeStr)",
                        attributes: [.foregroundColor: color]
                    )
                }
                menuItem.isEnabled = false
            }
        }
    }

    private func startAutoRefresh() {
        timer?.invalidate()
        guard Preferences.shared.autoRefresh else { return }
        let interval = Preferences.shared.refreshInterval
        lastTestTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            NetworkMonitor.shared.testAllWebsites()
        }
        NetworkMonitor.shared.testAllWebsites()
    }

    // MARK: - NetworkMonitorDelegate

    func networkMonitorDidStartTesting() {
        isRefreshing = true
        lastTestTime = Date()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let prefs = Preferences.shared
            self.statusItem.button?.image = SignalIcon.generateImage(quality: .noSignal, colorful: prefs.useColorfulIcon)
            self.updateMenuItems()
        }
    }

    func networkMonitorDidUpdate(results: [WebsiteResult], quality: NetworkQuality) {
        isRefreshing = false
        currentResults = results
        currentQuality = quality

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let prefs = Preferences.shared
            self.statusItem.button?.image = SignalIcon.generateImage(quality: quality, colorful: prefs.useColorfulIcon)
            self.updateMenuItems()
        }
    }

    // MARK: - Actions

    @objc private func refreshClicked() {
        lastTestTime = Date()
        NetworkMonitor.shared.testAllWebsites()
    }

    @objc private func setDomesticMode() {
        Preferences.shared.environmentMode = .domesticOnly
        rebuildMenu()
        lastTestTime = Date()
        NetworkMonitor.shared.testAllWebsites()
    }

    @objc private func setGlobalMode() {
        Preferences.shared.environmentMode = .global
        rebuildMenu()
        lastTestTime = Date()
        NetworkMonitor.shared.testAllWebsites()
    }

    @objc private func setColorfulOn() {
        Preferences.shared.useColorfulIcon = true
        rebuildMenu()
        self.statusItem.button?.image = SignalIcon.generateImage(quality: currentQuality, colorful: true)
    }

    @objc private func setColorfulOff() {
        Preferences.shared.useColorfulIcon = false
        rebuildMenu()
        self.statusItem.button?.image = SignalIcon.generateImage(quality: currentQuality, colorful: false)
    }

    private func rebuildMenu() {
        statusItem.menu = nil
        buildMenu()
    }

    @objc private func settingsClicked() {
        SettingsWindowController.shared.showWindow()
    }

    @objc private func aboutClicked() {
        let alert = NSAlert()
        alert.messageText = "NetSignal"
        alert.informativeText = "版本 1.0.1\n\n网络状态监测工具\n通过监测国内外主要网站访问速度，直观反映当前网络状态。"
        alert.alertStyle = .informational
        alert.icon = appIcon()
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    private func appIcon() -> NSImage {
          return SignalIcon.drawAppIcon()
      }

    @objc private func updateClicked() {
        UpdateChecker.shared.checkForUpdate()
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension StatusBarController {
    func menuWillOpen(_ menu: NSMenu) {
        startMenuCountdown()
    }

    func menuDidClose(_ menu: NSMenu) {
        stopMenuCountdown()
    }

    private func startMenuCountdown() {
        stopMenuCountdown()
        updateCountdownItem()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCountdownItem()
        }
    }

    private func stopMenuCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func updateCountdownItem() {
        guard let menu = statusItem.menu,
              let item = menu.item(withTag: 200) else { return }
        let prefs = Preferences.shared
        guard prefs.autoRefresh else {
            item.isHidden = true
            return
        }
        item.isHidden = false

        let interval = prefs.refreshInterval
        let elapsed = Date().timeIntervalSince(lastTestTime)
        let remaining = max(0, interval - elapsed)
        let seconds = max(1, Int(ceil(remaining)))
        let text = "下一次刷新  \(seconds)秒"
        item.attributedTitle = NSAttributedString(
            string: text,
            attributes: [.foregroundColor: NSColor.secondaryLabelColor]
        )
    }
}

extension NSColor {
    static func fromHex(_ hex: String) -> NSColor {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
