import Cocoa
import QuickLookUI

// 空格预览：在 Finder 里选中 .md 按空格时显示排好版的文章。
// 渲染交给 MarkdownRenderer，这里只负责读文件、读设置。

final class PreviewViewController: NSViewController, QLPreviewingController {
    private var renderer: MarkdownRenderer?

    override func loadView() {
        guard let dir = MarkdownRenderer.webDirectory else {
            view = NSView()
            return
        }
        let renderer = MarkdownRenderer(webDirectory: dir)
        self.renderer = renderer
        view = renderer.webView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            handler(error)
            return
        }
        guard let renderer else {
            handler(CocoaError(.fileReadNoSuchFile))
            return
        }
        // 不是合法 UTF-8 时按 UTF-8 尽量解出来，坏掉的字节显示成替换符
        let markdown = String(decoding: data, as: UTF8.self)
        renderer.render(markdown: markdown, baseDir: url.deletingLastPathComponent(), settings: .load()) { error in
            if error == nil { SharedStore.markPreviewed() }
            handler(error)
        }
    }
}
