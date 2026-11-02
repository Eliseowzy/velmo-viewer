// 把 screenshots/raw 里的截图拼成 App Store 要的 2880×1800 图：深色渐变背景，上方标题，下方截图。
//   swift appstore/compose.swift
// 带阴影的窗口截图（screencapture -l 默认带阴影）原样贴上；全屏快速查看截图没有边框，补圆角和阴影。
import AppKit

let W = 2880.0, H = 1800.0
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("screenshots")
let raw = root.appendingPathComponent("raw"), out = root.appendingPathComponent("en")

struct Shot {
    let file: String; let title: String; let subtitle: String; let framed: Bool
    var crop: CGRect? = nil  // 像素坐标，左上角为原点；全屏截图左右空白太多，裁到正文那一栏
}
let shots = [
    Shot(file: "ql-kyoto.png", title: "Markdown, beautifully typeset",
         subtitle: "Select a file in Finder and press Space.", framed: true),
    Shot(file: "fs-report.png", title: "Math and charts, right in Quick Look",
         subtitle: "LaTeX formulas and ECharts render instantly.", framed: false,
         crop: CGRect(x: 540, y: 110, width: 1860, height: 1500)),
    Shot(file: "fs-release.png", title: "Diagrams and highlighted code",
         subtitle: "Mermaid flowcharts, footnotes and syntax highlighting.", framed: false,
         crop: CGRect(x: 540, y: 110, width: 1860, height: 1560)),
    Shot(file: "fs-kyoto.png", title: "Tables, task lists and more",
         subtitle: "Everything GitHub-flavored Markdown can do.", framed: false,
         crop: CGRect(x: 540, y: 110, width: 1860, height: 1560)),
    Shot(file: "app-settings.png", title: "Make it yours",
         subtitle: "Theme, font size and text width, applied instantly.", framed: true),
    Shot(file: "app-onboarding.png", title: "Set up in a minute",
         subtitle: "A three-step guide and a Test button.", framed: true),
]

func render(_ s: Shot, index: Int) throws {
    guard var img = NSImage(contentsOf: raw.appendingPathComponent(s.file)),
          let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8,
                                     samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 32) else { throw CocoaError(.fileReadCorruptFile) }
    rep.size = NSSize(width: W, height: H)
    if let crop = s.crop, let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil)?.cropping(to: crop) {
        img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // 背景：跟图标一致的深蓝，往下稍亮
    NSGradient(starting: NSColor(srgbRed: 0.07, green: 0.08, blue: 0.13, alpha: 1),
               ending: NSColor(srgbRed: 0.16, green: 0.19, blue: 0.33, alpha: 1))!
        .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 90 + 180)

    // 标题和副标题（AppKit 坐标原点在左下）
    let center = NSMutableParagraphStyle(); center.alignment = .center
    NSAttributedString(string: s.title, attributes: [
        .font: NSFont.systemFont(ofSize: 112, weight: .bold), .foregroundColor: NSColor.white, .paragraphStyle: center,
    ]).draw(in: NSRect(x: 0, y: H - 250, width: W, height: 150))
    NSAttributedString(string: s.subtitle, attributes: [
        .font: NSFont.systemFont(ofSize: 56, weight: .regular),
        .foregroundColor: NSColor(white: 1, alpha: 0.7), .paragraphStyle: center,
    ]).draw(in: NSRect(x: 0, y: H - 345, width: W, height: 80))

    // 截图区域：标题下方，留边
    let box = NSRect(x: 200, y: 60, width: W - 400, height: H - 345 - 60 - 60)
    let scale = min(box.width / img.size.width, box.height / img.size.height)
    let size = NSSize(width: img.size.width * scale, height: img.size.height * scale)
    let rect = NSRect(x: box.midX - size.width / 2, y: box.maxY - size.height, width: size.width, height: size.height)
    if s.framed {
        img.draw(in: rect)
    } else {
        let path = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: 0.55); shadow.shadowBlurRadius = 60
        shadow.shadowOffset = NSSize(width: 0, height: -20); shadow.set()
        NSColor.black.setFill(); path.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.saveGraphicsState()
        path.addClip(); img.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
        NSColor(white: 1, alpha: 0.12).setStroke(); path.lineWidth = 2; path.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()

    // 位图本身不带透明通道（App Store 不收带 alpha 的截图）
    let url = out.appendingPathComponent(String(format: "%d-%@", index + 1, s.file))
    try rep.representation(using: .png, properties: [:])!.write(to: url)
    print(url.path)
}

try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for (i, s) in shots.enumerated() { try render(s, index: i) }
