import Cocoa

class SignalIcon {
    static func generateImage(quality: NetworkQuality, size: NSSize = NSSize(width: 20, height: 20), colorful: Bool = true) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let ctx = NSGraphicsContext.current!.cgContext
        ctx.setShouldAntialias(true)

        let barCount = 4
        let barWidth: CGFloat = 3
        let barSpacing: CGFloat = 1.5
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        let startX = (size.width - totalWidth) / 2
        let baseY: CGFloat = 3
        let maxBarHeight: CGFloat = size.height - baseY - 2

        let activeColor = colorful ? qualityColor(quality) : NSColor.labelColor
        let inactiveColor = NSColor.separatorColor.withAlphaComponent(0.25)

        for i in 0..<barCount {
            let barHeight = maxBarHeight * (CGFloat(i + 1) / CGFloat(barCount))
            let x = startX + CGFloat(i) * (barWidth + barSpacing)
            let y = baseY
            let rect = NSRect(x: x, y: y, width: barWidth, height: barHeight)
            let path = NSBezierPath(roundedRect: rect, xRadius: 1.0, yRadius: 1.0)

            if i < quality.rawValue {
                activeColor.setFill()
            } else {
                inactiveColor.setFill()
            }
            path.fill()
        }

        image.unlockFocus()
        image.isTemplate = !colorful
        return image
    }

    // 加载应用图标（从 Resources/AppIcon.png，用于弹窗）
    static func drawAppIcon(size: NSSize = NSSize(width: 64, height: 64)) -> NSImage {
        // 优先从 Bundle.main 加载（安装后的 .app）
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: url) {
            // 缩放到目标显示尺寸（PNG 是 512x512 高分辨率）
            let resized = NSImage(size: size)
            resized.lockFocus()
            icon.draw(in: NSRect(origin: .zero, size: size),
                      from: .zero,
                      operation: .sourceOver,
                      fraction: 1.0)
            resized.unlockFocus()
            return resized
        }

        // 回退：代码绘制绿色信号条
        let image = NSImage(size: size)
        image.lockFocus()
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.setShouldAntialias(true)

        let barCount = 4
        let barWidth: CGFloat = size.width * 9.0 / 64.0
        let barSpacing: CGFloat = size.width * 5.0 / 64.0
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        let startX = (size.width - totalWidth) / 2
        let baseY: CGFloat = size.height * 8.0 / 64.0
        let maxBarHeight: CGFloat = size.height - baseY - size.height * 8.0 / 64.0

        let barColor = NSColor(red: 76.0/255.0, green: 175.0/255.0, blue: 80.0/255.0, alpha: 1.0)

        for i in 0..<barCount {
            let barHeight = maxBarHeight * (CGFloat(i + 1) / CGFloat(barCount))
            let x = startX + CGFloat(i) * (barWidth + barSpacing)
            let y = baseY
            let rect = NSRect(x: x, y: y, width: barWidth, height: barHeight)
            let path = NSBezierPath(roundedRect: rect, xRadius: barWidth / 3, yRadius: barWidth / 3)
            barColor.setFill()
            path.fill()
        }

        image.unlockFocus()
        return image
    }

    private static func qualityColor(_ quality: NetworkQuality) -> NSColor {
        switch quality {
        case .noSignal:
            return NSColor.systemGray
        case .poor:
            return NSColor.systemRed
        case .fair:
            return NSColor.systemOrange
        case .good:
            return NSColor.systemGreen
        case .excellent:
            return NSColor.systemGreen.blended(withFraction: 0.3, of: NSColor.systemTeal) ?? NSColor.systemGreen
        }
    }
}
