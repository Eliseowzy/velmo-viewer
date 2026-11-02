import SwiftUI

// 自动更新：只有官网 dmg 直装版有（编译条件 DIRECT_DISTRIBUTION），App Store 版由系统更新，不编译这些。
// 用户很少打开这个 App（空格预览不需要它在运行），所以默认每次启动检查、后台下载、退出时安装：
// 关掉窗口 App 就退出，下次打开已经是新版本。

#if DIRECT_DISTRIBUTION
import Sparkle

@MainActor
final class Updater: NSObject, ObservableObject {
    static let shared = Updater()

    /// 设置页「检查更新」的结果，就地显示在按钮旁边，不弹 Sparkle 的检查进度框
    enum CheckStatus: Equatable {
        case idle, checking, upToDate, failed
        case available(version: String)
    }

    private(set) var controller: SPUStandardUpdaterController!
    @Published private(set) var canCheck = false
    @Published private(set) var checkStatus = CheckStatus.idle
    @Published var checksAutomatically: Bool {
        didSet { updater.automaticallyChecksForUpdates = checksAutomatically }
    }
    @Published var installsAutomatically: Bool {
        didSet { updater.automaticallyDownloadsUpdates = installsAutomatically }
    }

    private var updater: SPUUpdater { controller.updater }

    private override init() {
        checksAutomatically = false
        installsAutomatically = false
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        let updater = controller.updater
        checksAutomatically = updater.automaticallyChecksForUpdates
        installsAutomatically = updater.automaticallyDownloadsUpdates
        updater.publisher(for: \.canCheckForUpdates).receive(on: DispatchQueue.main).assign(to: &$canCheck)
    }

    /// 菜单栏用：Sparkle 标准流程（带进度框）
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    /// 设置页用：静默查一下有没有新版本，结果写进 checkStatus
    func checkForUpdatesInline() {
        guard canCheck, checkStatus != .checking else { return }
        checkStatus = .checking
        updater.checkForUpdateInformation()
    }

    /// 有新版本时，交给 Sparkle 标准界面显示更新说明并安装
    func installUpdate() {
        checkStatus = .idle
        controller.checkForUpdates(nil)
    }
}

extension Updater: SPUUpdaterDelegate {
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        MainActor.assumeIsolated {
            if checkStatus == .checking { checkStatus = .available(version: version) }
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        guard updateCheck == .updateInformation else { return }
        let error = error as NSError?
        MainActor.assumeIsolated {
            guard checkStatus == .checking else { return }
            if let error, !(error.domain == SUSparkleErrorDomain && error.code == Int(SUError.noUpdateError.rawValue)) {
                checkStatus = .failed
            } else {
                checkStatus = .upToDate
            }
        }
    }
}

/// 菜单栏「Velmo Viewer → 检查更新…」
struct CheckForUpdatesCommand: Commands {
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            CheckForUpdatesMenuItem(updater: .shared)
        }
    }
}

private struct CheckForUpdatesMenuItem: View {
    @ObservedObject var updater: Updater

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates).disabled(!updater.canCheck)
    }
}

/// 设置页里的「更新」一节
struct UpdateSection: View {
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        Section {
            Toggle("Automatically Check for Updates", isOn: $updater.checksAutomatically)
            Toggle("Automatically Download and Install Updates", isOn: $updater.installsAutomatically)
                .disabled(!updater.checksAutomatically)
        } header: {
            Text("Updates")
        } footer: {
            HStack {
                Text(appVersion).foregroundStyle(.secondary)
                Spacer()
                CheckStatusView(status: updater.checkStatus, install: updater.installUpdate)
                Button("Check for Updates…", action: updater.checkForUpdatesInline)
                    .controlSize(.small)
                    .disabled(!updater.canCheck || updater.checkStatus == .checking)
            }
        }
    }
}
private struct CheckStatusView: View {
    let status: Updater.CheckStatus
    let install: () -> Void

    var body: some View {
        switch status {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking for Updates…")
            }
            .foregroundStyle(.secondary)
        case .upToDate:
            Label("You're up to date", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
        case .failed:
            Label("Couldn't check for updates", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .available(let version):
            HStack(spacing: 6) {
                Text("Version \(version) available").foregroundStyle(.secondary)
                Button("Update…", action: install).controlSize(.small).buttonStyle(.borderedProminent)
            }
        }
    }
}
#else
struct CheckForUpdatesCommand: Commands {
    var body: some Commands { EmptyCommands() }
}

struct UpdateSection: View {
    var body: some View {
        Section {
            EmptyView()
        } footer: {
            Text(appVersion).foregroundStyle(.secondary)
        }
    }
}
#endif

private var appVersion: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    return String(localized: "Version \(version) (\(build))")
}
