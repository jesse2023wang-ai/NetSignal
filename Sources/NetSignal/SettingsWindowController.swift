import Cocoa

class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    init() {
        let window = SettingsWindow()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
