import AppKit
import WebKit

// 用 web/ 里的渲染页显示 Markdown 和独立代码文件。
// 扩展里出空格预览、App 里的实时预览都用它，所以两边看到的效果完全一致。

final class MarkdownRenderer: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    private let page = URL(string: "\(AssetSchemeHandler.scheme)://app/index.html")!
    private enum Content {
        case markdown(String)
        case code(source: String, language: String, notice: String?)
    }

    private var content: Content = .markdown("")
    private var baseDir = ""
    private var settings = ViewerSettings()
    private var completion: ((Error?) -> Void)?

    /// 扩展里是 Bundle.main 的 Resources/web；App 里从内嵌的扩展包里取，不重复打包
    static var webDirectory: URL? {
        if let url = Bundle.main.url(forResource: "web", withExtension: nil) { return url }
        return Bundle.main.builtInPlugInsURL?
            .appendingPathComponent("VelmoViewerQuickLook.appex/Contents/Resources/web")
    }

    init(webDirectory: URL) {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(AssetSchemeHandler(webDirectory: webDirectory), forURLScheme: AssetSchemeHandler.scheme)
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
    }

    /// 加载渲染页并显示文档；baseDir 是文档所在文件夹，用来解析相对路径的图片
    func render(markdown: String, baseDir: URL?, settings: ViewerSettings, completion: ((Error?) -> Void)? = nil) {
        load(content: .markdown(markdown), baseDir: baseDir, settings: settings, completion: completion)
    }

    /// 显示独立代码文件；语言标识由 SourceLanguage 统一映射。
    func render(code: String, language: String, baseDir: URL?, settings: ViewerSettings,
                notice: String? = nil, completion: ((Error?) -> Void)? = nil) {
        load(content: .code(source: code, language: language, notice: notice), baseDir: baseDir,
             settings: settings, completion: completion)
    }

    private func load(content: Content, baseDir: URL?, settings: ViewerSettings,
                      completion: ((Error?) -> Void)?) {
        finish(nil)
        self.content = content
        self.baseDir = baseDir.map(AssetSchemeHandler.url(forDirectory:)) ?? "\(AssetSchemeHandler.scheme)://app/"
        self.settings = settings
        self.completion = completion
        applyAppearance()
        Self.remoteImageBlocker { [weak self] rules in
            guard let self else { return }
            let controller = self.webView.configuration.userContentController
            controller.removeAllContentRuleLists()
            if !settings.remoteImages, let rules { controller.add(rules) }
            self.webView.load(URLRequest(url: self.page))
        }
    }

    /// 只改了字号、宽度、主题这类样式时直接改页面，不重新渲染
    func update(settings new: ViewerSettings) {
        let needsReload = new.remoteImages != settings.remoteImages
        settings = new
        if needsReload {
            let dir = AssetSchemeHandler.directory(from: baseDir)
            switch content {
            case .markdown(let markdown):
                render(markdown: markdown, baseDir: dir, settings: new)
            case .code(let source, let language, let notice):
                render(code: source, language: language, baseDir: dir, settings: new, notice: notice)
            }
            return
        }
        applyAppearance()
        webView.callAsyncJavaScript("document.getElementById('vv-override').textContent = css",
                                    arguments: ["css": overrideCss], in: nil, in: .page, completionHandler: nil)
    }

    private var overrideCss: String {
        switch content {
        case .markdown:
            return settings.overrideCss
        case .code:
            // 代码视图不能被文章宽度设置限制；其余字号和代码换行设置继续生效。
            var css = settings.overrideCss + " .velmo-article.velmo-code-view { max-width: none; }"
            if settings.wrapCode {
                css += " .velmo-article.velmo-code-view > pre > code { width: auto; min-width: 0; }"
            }
            return css
        }
    }

    private func applyAppearance() {
        switch settings.theme {
        case .system: webView.appearance = nil
        case .light: webView.appearance = NSAppearance(named: .aqua)
        case .dark: webView.appearance = NSAppearance(named: .darkAqua)
        }
    }

    /// 代码块语言 → 渲染它的脚本（web/ 里的 ES module，导出 render()）。文档里有对应代码块时才加载
    private static func plugins(page: URL) -> [String: String] {
        let dir = page.deletingLastPathComponent()
        return ["echarts": "vv-echarts.js", "mermaid": "vv-mermaid.js"]
            .mapValues { dir.appendingPathComponent($0).absoluteString }
    }

    /// 渲染页（web/vv-*.js）里显示的文案，按系统语言从字符串目录里取；{xxx} 由页面替换成实际内容
    private static var webStrings: [String: String] {
        [
            "loadFailed": String(localized: "Couldn’t load {file}",
                                 comment: "Shown in the preview when a bundled chart or diagram script fails to load"),
            "notObject": String(localized: "The option must be a JSON object",
                                comment: "Shown under an echarts code block whose content is not a JSON object"),
            "error": String(localized: "{name}: {message}",
                            comment: "Error under a chart or diagram code block; {name} is ECharts or Mermaid"),
        ]
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let renderJS: String
        var arguments: [String: Any]
        switch content {
        case .markdown(let markdown):
            renderJS = """
            window.vvStrings = strings;
            await velmoRender(md, dir);
            await Promise.all(Object.entries(plugins).map(async ([lang, url]) => {
              if (!document.querySelector(`.velmo-article pre > code.language-${lang}`)) return;
              try { await (await import(url)).render(); } catch (e) { console.error(e); }
            }));
            """
            arguments = ["md": markdown, "dir": baseDir, "css": overrideCss,
                         "plugins": Self.plugins(page: page), "strings": Self.webStrings]
        case .code(let source, let language, let notice):
            renderJS = language == "jsonl"
                ? "await velmoRenderJSONL(source, notice);"
                : "await velmoRenderCode(source, language);"
            arguments = ["source": source, "language": language, "notice": notice ?? "", "css": overrideCss]
        }
        let js = renderJS + """
        const s = document.createElement('style');
        s.id = 'vv-override';
        s.textContent = css;
        document.head.append(s);
        """
        webView.callAsyncJavaScript(js, arguments: arguments, in: nil, in: .page) { [weak self] result in
            switch result {
            case .success:
                self?.finish(nil)
            case .failure(let error):
                NSLog("Velmo Viewer: %@", error.localizedDescription)
                self?.finish(error)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(error)
    }

    /// 点链接用默认浏览器打开，预览里不跳转；页内锚点照常滚动
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.navigationType == .linkActivated, let url = action.request.url {
            if url.fragment != nil, url.path == webView.url?.path {
                decisionHandler(.allow)
                return
            }
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    private func finish(_ error: Error?) {
        let done = completion
        completion = nil
        done?(error)
    }

    // MARK: - 不加载网络图片

    private static var blocker: WKContentRuleList?

    private static func remoteImageBlocker(_ handler: @escaping (WKContentRuleList?) -> Void) {
        if let blocker { return handler(blocker) }
        let rules = #"[{"trigger":{"url-filter":"^https?://","resource-type":["image","media"]},"action":{"type":"block"}}]"#
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "vv-block-remote-images",
                                                                encodedContentRuleList: rules) { list, error in
            if let error { NSLog("Velmo Viewer: %@", error.localizedDescription) }
            blocker = list
            handler(list)
        }
    }
}

// MARK: - 页面资源

/// 沙盒里 WKWebView 的网页进程读不了任意本地文件，所以页面和文档旁的图片都走自定义 scheme，由本进程读出来交给它：
///   vv-asset://app/<文件>        渲染页自己的 html/js/css
///   vv-asset://file/<绝对路径>   文档引用的本地图片（本进程能读到才显示）
final class AssetSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "vv-asset"
    private let webDirectory: URL

    init(webDirectory: URL) {
        self.webDirectory = webDirectory.standardizedFileURL
    }

    static func url(forDirectory dir: URL) -> String {
        var path = dir.standardizedFileURL.path
        if !path.hasSuffix("/") { path += "/" }
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        return "\(scheme)://file\(encoded)"
    }

    static func directory(from base: String) -> URL? {
        guard let url = URL(string: base), url.host == "file" else { return nil }
        return URL(fileURLWithPath: url.path, isDirectory: true)
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, let file = fileURL(for: url),
              let data = try? Data(contentsOf: file) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let response = URLResponse(url: url, mimeType: Self.mimeType(file.pathExtension),
                                   expectedContentLength: data.count, textEncodingName: nil)
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    private func fileURL(for url: URL) -> URL? {
        switch url.host {
        case "app":
            let file = webDirectory.appendingPathComponent(url.path).standardizedFileURL
            return file.path.hasPrefix(webDirectory.path + "/") ? file : nil
        case "file":
            return URL(fileURLWithPath: url.path)
        default:
            return nil
        }
    }

    private static func mimeType(_ ext: String) -> String {
        switch ext.lowercased() {
        case "html": return "text/html"
        case "js": return "text/javascript"
        case "css": return "text/css"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "avif": return "image/avif"
        case "bmp": return "image/bmp"
        default: return "application/octet-stream"
        }
    }
}
