import Cocoa
import QuickLookUI

// 空格预览：Markdown 显示排好版的文章，常见代码文件显示语法高亮源码。
// 渲染交给 MarkdownRenderer，这里只负责识别语言、限制读取大小和读取设置。

final class PreviewViewController: NSViewController, QLPreviewingController {
    private static let codeByteLimit = 2 * 1_048_576

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
        guard let renderer else {
            handler(CocoaError(.fileReadNoSuchFile))
            return
        }
        guard let language = SourceLanguage.resolve(for: url) else {
            handler(CocoaError(.fileReadUnknown))
            return
        }

        let baseDir = url.deletingLastPathComponent()
        let settings = ViewerSettings.load()
        let completion: (Error?) -> Void = { error in
            if error == nil { SharedStore.markPreviewed() }
            handler(error)
        }

        do {
            if language == .markdown {
                // Markdown 保留原来的完整读取与渲染路径。
                let markdown = String(decoding: try Data(contentsOf: url), as: UTF8.self)
                renderer.render(markdown: markdown, baseDir: baseDir, settings: settings, completion: completion)
            } else {
                let code = try Self.readCode(from: url, language: language)
                renderer.render(code: code, language: language.rawValue, baseDir: baseDir,
                                settings: settings, completion: completion)
            }
        } catch {
            handler(error)
        }
    }

    /// 最多读取 2 MiB + 1 字节；额外字节只用于判断截断，避免大文件占满扩展进程内存。
    private static func readCode(from url: URL, language: SourceLanguage) throws -> String {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: codeByteLimit + 1) ?? Data()
        // 不是合法 UTF-8 或末尾恰好截断多字节字符时，坏掉的字节显示成替换符。
        let source = String(decoding: data.prefix(codeByteLimit), as: UTF8.self)
        let notice = data.count > codeByteLimit ? language.truncationNotice(limit: codeByteLimit) : ""
        return notice + source
    }
}
