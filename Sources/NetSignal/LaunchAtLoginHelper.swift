import Foundation
import ServiceManagement

class LaunchAtLoginHelper {
    static func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            // macOS 13 以下回退到 LaunchAgent
            setLaunchAgent(enabled: enabled, bundleId: Bundle.main.bundleIdentifier ?? "com.netsignal.app")
            return
        }

        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }

    static func isEnabled() -> Bool {
        guard #available(macOS 13.0, *) else {
            let bundleId = Bundle.main.bundleIdentifier ?? "com.netsignal.app"
            let plistPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents")
                .appendingPathComponent("\(bundleId).plist")
            return FileManager.default.fileExists(atPath: plistPath.path)
        }
        return SMAppService.mainApp.status == .enabled
    }

    // macOS 13 以下回退方案：LaunchAgent plist
    private static func setLaunchAgent(enabled: Bool, bundleId: String) {
        let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        let plistPath = launchAgentsDir.appendingPathComponent("\(bundleId).plist")

        if enabled {
            let plist: [String: Any] = [
                "Label": bundleId,
                "ProgramArguments": [Bundle.main.executablePath ?? ""],
                "RunAtLoad": true,
                "KeepAlive": false
            ]
            do {
                try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
                let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try data.write(to: plistPath)
            } catch {
                print("Failed to create launch agent: \(error)")
            }
        } else {
            try? FileManager.default.removeItem(at: plistPath)
        }
    }
}
