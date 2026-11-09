import Cocoa
import QuickLookUI

// 空格预览：Markdown 显示排好版的文章，常见代码文件显示语法高亮源码。
// 渲染交给 MarkdownRenderer，这里只负责识别语言、限制读取大小和读取设置。

final class PreviewViewController: NSViewController, QLPreviewingController {
    private static let codeByteLimit = 2 * 1_048_576

    private struct CodePreview {
        let source: String
        let truncated: Bool
    }

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
                let preview = try Self.readCode(from: url, language: language)
                let notice = preview.truncated && language == .jsonl
                    ? String(localized: "Only complete records in the first 2 MiB are shown; later records are omitted.")
                    : nil
                renderer.render(code: preview.source, language: language.rawValue, baseDir: baseDir,
                                settings: settings, notice: notice, completion: completion)
            }
        } catch {
            handler(error)
        }
    }

    /// 最多读取 2 MiB + 1 字节；额外字节只用于判断截断，避免大文件占满扩展进程内存。
    private static func readCode(from url: URL, language: SourceLanguage) throws -> CodePreview {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: codeByteLimit + 1) ?? Data()
        let truncated = data.count > codeByteLimit
        var sourceData = data.prefix(codeByteLimit)

        if language == .jsonl && truncated {
            // JSONL 不在半条记录处停下；即使第一行就超限，也只显示截断提示。
            let end = sourceData.lastIndex(of: 0x0A).map { sourceData.index(after: $0) } ?? sourceData.startIndex
            sourceData = sourceData[..<end]
        }

        // 不是合法 UTF-8 或末尾恰好截断多字节字符时，坏掉的字节显示成替换符。
        let source = String(decoding: sourceData, as: UTF8.self)
        let notice = truncated && language != .jsonl ? language.truncationNotice(limit: codeByteLimit) : ""
        return CodePreview(source: notice + source, truncated: truncated)
    }
}
