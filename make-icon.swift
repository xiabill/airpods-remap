import Cocoa

// 手绘 AirPods Pro 风格图标：圆角蓝色背景 + 两只白色 AirPods 略微外八

func drawAirPods(size: CGFloat) {
    NSColor.white.setFill()

    // 单只 AirPod：椭圆头 + 较短的圆角矩形 stem
    // AirPods Pro 风格：偏圆的头 + 短粗 stem
    let podWidth   = size * 0.24
    let podHeight  = size * 0.28
    let stemWidth  = size * 0.11
    let stemHeight = size * 0.20
    let overlap    = size * 0.03
    let gap        = size * 0.08
    let tiltDeg: CGFloat = 14

    let canvasMidX = size / 2
    let canvasMidY = size / 2

    // 整体把双 AirPods 略微往下移一点点视觉更稳
    let yShift: CGFloat = -size * 0.02

    func drawOne(centerX: CGFloat, tilt: CGFloat) {
        NSGraphicsContext.saveGraphicsState()

        // 旋转坐标：以 (centerX, canvasMidY+yShift) 为旋转中心
        let cy = canvasMidY + yShift
        let xform = NSAffineTransform()
        xform.translateX(by: centerX, yBy: cy)
        xform.rotate(byDegrees: tilt)
        xform.translateX(by: -centerX, yBy: -cy)
        xform.concat()

        // 头部椭圆：以 (centerX, cy + podHeight/2) 为中心向上
        let headTop = cy + podHeight * 0.5
        let headRect = NSRect(
            x: centerX - podWidth / 2,
            y: headTop - podHeight,
            width: podWidth, height: podHeight)
        NSBezierPath(ovalIn: headRect).fill()

        // stem：从头部下方往下延伸
        let stemTop = headRect.minY + overlap
        let stemRect = NSRect(
            x: centerX - stemWidth / 2,
            y: stemTop - stemHeight,
            width: stemWidth, height: stemHeight)
        NSBezierPath(
            roundedRect: stemRect,
            xRadius: stemWidth / 2,
            yRadius: stemWidth / 2
        ).fill()

        NSGraphicsContext.restoreGraphicsState()
    }

    let leftX  = canvasMidX - (podWidth / 2 + gap / 2)
    let rightX = canvasMidX + (podWidth / 2 + gap / 2)
    drawOne(centerX: leftX,  tilt: -tiltDeg)
    drawOne(centerX: rightX, tilt:  tiltDeg)
}

func renderIconPNG(pxSize: Int) -> Data? {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: pxSize, height: pxSize,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ns
    defer { NSGraphicsContext.restoreGraphicsState() }

    let size = CGFloat(pxSize)

    // 1. 圆角方块背景（macOS app icon 常见 22.37% 圆角，留 4% 透明 padding）
    let radius = size * 0.2237
    let inset  = size * 0.04
    let bgRect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(colors: [
        NSColor(red: 0.30, green: 0.65, blue: 1.00, alpha: 1.0),  // 顶部亮蓝
        NSColor(red: 0.05, green: 0.18, blue: 0.62, alpha: 1.0),  // 底部深蓝
    ])!
    gradient.draw(in: bgPath, angle: -90)

    // 2. 内部高光弧
    NSGraphicsContext.saveGraphicsState()
    bgPath.addClip()
    let hlRect = NSRect(x: inset, y: size * 0.58, width: size - inset * 2, height: size * 0.42)
    let hl = NSGradient(colors: [
        NSColor(white: 1.0, alpha: 0.18),
        NSColor(white: 1.0, alpha: 0.0)
    ])!
    hl.draw(in: hlRect, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // 3. AirPods 主体（白色）
    NSGraphicsContext.saveGraphicsState()
    bgPath.addClip()
    drawAirPods(size: size)
    NSGraphicsContext.restoreGraphicsState()

    // 4. 内部细边框，给浅色背景增加可读性
    let borderPath = NSBezierPath(
        roundedRect: bgRect.insetBy(dx: 0.5, dy: 0.5),
        xRadius: radius, yRadius: radius)
    NSColor(white: 0, alpha: 0.10).setStroke()
    borderPath.lineWidth = max(1, size / 1024)
    borderPath.stroke()

    guard let cgImage = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    return rep.representation(using: .png, properties: [:])
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16",       16),
    ("icon_16x16@2x",    32),
    ("icon_32x32",       32),
    ("icon_32x32@2x",    64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x",1024),
]

for (name, px) in sizes {
    if let data = renderIconPNG(pxSize: px) {
        let url = URL(fileURLWithPath: outDir).appendingPathComponent("\(name).png")
        try? data.write(to: url)
        print("✓ \(name).png  \(px)×\(px)")
    } else {
        print("✗ failed \(name) \(px)")
    }
}
