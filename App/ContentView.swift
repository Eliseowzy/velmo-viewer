import SwiftUI
import notify

struct ContentView: View {
    @State private var settings = ViewerSettings.load()
    @AppStorage("setupFinished") private var setupFinished = false

    var body: some View {
        if setupFinished { main } else { OnboardingView { setupFinished = true } }
    }

    private var main: some View {
        HSplitView {
            Form {
                SetupSection()
                Section {
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(ViewerTheme.allCases) { Text($0.title).tag($0) }
                    }
                    LabeledContent("Font Size") {
                        HStack {
                            Slider(value: $settings.fontSize, in: ViewerSettings.fontSizeRange, step: 1)
                            Text("\(Int(settings.fontSize)) pt").monospacedDigit().frame(width: 44, alignment: .trailing)
                        }
                    }
                    Picker("Text Width", selection: $settings.width) {
                        ForEach(ViewerWidth.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Wrap Code Blocks", isOn: $settings.wrapCode)
                    Toggle("Load Remote Images", isOn: $settings.remoteImages)
                } header: {
                    Text("Preview Style")
                } footer: {
                    HStack {
                        Text("Changes take effect immediately.").foregroundStyle(.secondary)
                        Spacer()
                        Button("Restore Defaults", action: reset).controlSize(.small)
                    }
                }
                UpdateSection()
            }
            .formStyle(.grouped)
            .onChange(of: settings) { $0.save() }
            .frame(minWidth: 340, idealWidth: 360, maxWidth: 420)

            PreviewPane(settings: settings)
                .frame(minWidth: 420)
        }
    }

    private func reset() {
        settings = ViewerSettings()
    }
}

// MARK: - 引导：在系统设置里启用本扩展，并用快速查看验证

private enum SetupCheck { case idle, checking, ok, notUsed }

/// 系统设置路径只在第一步的按钮旁用图标和短句带过，不再铺一大段步骤文字
private enum QuickLookSetup {
    static func openSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.quicklook.preview",
            "x-apple.systempreferences:com.apple.ExtensionsPreferences",
        ]
        for s in candidates {
            if let url = URL(string: s), NSWorkspace.shared.open(url) { return }
        }
    }

    /// 用系统快速查看面板打开示例文档；扩展出图后会发通知，据此判断系统是不是在用本扩展
    static func test(_ completion: @escaping (SetupCheck) -> Void) {
        guard let sample = Bundle.main.url(forResource: "Sample", withExtension: "md") else { return }
        completion(.checking)
        PreviewWatcher.shared.start { used in completion(used ? .ok : .notUsed) }
        QuickLookTester.shared.show(sample)
    }
}

/// 首次启动的整页引导：三步走完、测试通过后才进入设置页，之后不再出现
private struct OnboardingView: View {
    let finish: () -> Void
    @State private var check = SetupCheck.idle

    var body: some View {
        VStack(spacing: 28) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 84, height: 84)
            VStack(spacing: 6) {
                Text(check == .ok ? "You're all set" : "Enable Velmo Viewer").font(.largeTitle.bold())
                Text(check == .ok ? "Select a .md file in Finder and press Space."
                                  : "Three quick steps, then Markdown files preview in Finder with Space.")
                    .foregroundStyle(.secondary)
            }
            if check == .ok {
                Label("Velmo Viewer is active", systemImage: "checkmark.circle.fill")
                    .font(.title3).foregroundStyle(.green)
                Button("Get Started", action: finish)
                    .buttonStyle(.borderedProminent).controlSize(.large)
            } else {
                VStack(spacing: 10) {
                    card(1, "Open Quick Look extensions", nil) {
                        Button("Open System Settings…", action: QuickLookSetup.openSettings)
                    }
                    card(2, "Turn on Velmo Viewer", "Turn off other Markdown previewers.") { EmptyView() }
                    card(3, "Test it", check == .notUsed ? "Not active yet. Make sure Velmo Viewer is turned on." : nil, warn: true) {
                        if check == .checking {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Test") { QuickLookSetup.test { check = $0 } }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .frame(maxWidth: 460)
                Button("Skip for Now", action: finish).buttonStyle(.link).foregroundStyle(.secondary)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.default, value: check)
    }

    private func card<Action: View>(_ n: Int, _ title: LocalizedStringKey, _ note: LocalizedStringKey?, warn: Bool = false,
                                    @ViewBuilder action: () -> Action) -> some View {
        HStack(spacing: 12) {
            Text(n, format: .number).font(.callout.bold()).foregroundStyle(.white)
                .frame(width: 24, height: 24).background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                if let note {
                    Text(note).font(.callout).foregroundStyle(warn ? Color.orange : Color.secondary)
                }
            }
            Spacer()
            action()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
    }
}

/// 设置页里引导完成后留下的一行：状态加重新检查的入口
private struct SetupSection: View {
    @State private var check = SetupCheck.idle

    var body: some View {
        Section {
            HStack {
                switch check {
                case .idle: Text("Quick Preview")
                case .checking: ProgressView().controlSize(.small)
                case .ok: Label("Velmo Viewer is active", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                case .notUsed: Label("Not active yet. Make sure Velmo Viewer is turned on.", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
                Spacer()
                Button("Open System Settings…", action: QuickLookSetup.openSettings)
                Button("Test") { QuickLookSetup.test { check = $0 } }.disabled(check == .checking)
            }
        } header: {
            Text("Enable Velmo Viewer")
        } footer: {
            Text("Select a Markdown file in Finder and press Space to preview it.").foregroundStyle(.secondary)
        }
    }
}

/// 在限定时间内等扩展的「已出预览」通知
private final class PreviewWatcher {
    static let shared = PreviewWatcher()
    private var token: Int32 = NOTIFY_TOKEN_INVALID
    private var timeout: DispatchWorkItem?
    private var done: ((Bool) -> Void)?

    func start(seconds: Double = 5, _ completion: @escaping (Bool) -> Void) {
        stop()
        done = completion
        notify_register_dispatch(SharedStore.previewedNotification, &token, .main) { [weak self] _ in
            self?.finish(true)
        }
        let item = DispatchWorkItem { [weak self] in self?.finish(false) }
        timeout = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    private func finish(_ used: Bool) {
        let completion = done
        stop()
        completion?(used)
    }

    private func stop() {
        if token != NOTIFY_TOKEN_INVALID { notify_cancel(token) }
        token = NOTIFY_TOKEN_INVALID
        timeout?.cancel()
        timeout = nil
        done = nil
    }
}

// MARK: - 实时预览：和空格预览用同一个渲染器

private struct PreviewPane: NSViewRepresentable {
    let settings: ViewerSettings

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        guard let dir = MarkdownRenderer.webDirectory else { return NSView() }
        let renderer = MarkdownRenderer(webDirectory: dir)
        context.coordinator.renderer = renderer
        context.coordinator.settings = settings
        let sample = Bundle.main.url(forResource: "Sample", withExtension: "md")
        let markdown = sample.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        renderer.render(markdown: markdown, baseDir: sample?.deletingLastPathComponent(), settings: settings)
        return renderer.webView
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard context.coordinator.settings != settings else { return }
        context.coordinator.settings = settings
        context.coordinator.renderer?.update(settings: settings)
    }

    final class Coordinator {
        var renderer: MarkdownRenderer?
        var settings: ViewerSettings?
    }
}
