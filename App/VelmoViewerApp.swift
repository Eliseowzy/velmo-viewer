import SwiftUI
import Quartz

@main
struct VelmoViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Velmo Viewer", id: "main") {
            ContentView()
                .frame(minWidth: 880, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CheckForUpdatesCommand()
        }
    }
}

/// App 本身只是设置页，关掉窗口就退出；空格预览由扩展独立工作，不需要 App 在运行
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DIRECT_DISTRIBUTION
        _ = Updater.shared  // 启动更新器：按计划检查，并安装上次退出前已下载好的更新
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// 「测试」：用系统的快速查看面板打开示例文档，系统会挑当前启用的扩展来出预览。
/// 面板从响应链上找控制者，所以把自己插到主窗口后面。
final class QuickLookTester: NSResponder, QLPreviewPanelDataSource {
    static let shared = QuickLookTester()
    private var item: URL?

    func show(_ url: URL) {
        item = url
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }), window.nextResponder !== self {
            nextResponder = window.nextResponder
            window.nextResponder = self
        }
        guard let panel = QLPreviewPanel.shared() else { return }
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { item == nil ? 0 : 1 }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        item as NSURL?
    }
}
