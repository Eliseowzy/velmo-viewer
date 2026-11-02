import Foundation
import notify

// 宿主 App 和空格预览扩展共用的设置：存成 App Group 容器里的 settings.json，
// App 里改，扩展每次预览时重新读。两个 target 都编译这个文件。
// 不用 UserDefaults(suiteName:)：常驻的进程会缓存旧值，跨进程改动不能及时看到。

enum ViewerTheme: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return String(localized: "Match System")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }
}

enum ViewerWidth: String, CaseIterable, Identifiable, Codable {
    case narrow, standard, wide, full
    var id: String { rawValue }
    var title: String {
        switch self {
        case .narrow: return String(localized: "Narrow")
        case .standard: return String(localized: "Standard")
        case .wide: return String(localized: "Wide")
        case .full: return String(localized: "Full Width")
        }
    }
    var css: String {
        switch self {
        case .narrow: return "36em"
        case .standard: return "42em"
        case .wide: return "56em"
        case .full: return "none"
        }
    }
}

struct ViewerSettings: Equatable, Codable {
    var theme: ViewerTheme = .system
    var fontSize: Double = 17
    var width: ViewerWidth = .standard
    var wrapCode = false
    var remoteImages = true

    static let fontSizeRange: ClosedRange<Double> = 13...24

    init() {}

    /// 缺字段或值不认识时用默认值，以后加设置项不会把旧文件读坏
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ViewerSettings()
        theme = (try? c.decode(ViewerTheme.self, forKey: .theme)) ?? d.theme
        fontSize = (try? c.decode(Double.self, forKey: .fontSize)).map {
            min(max($0, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
        } ?? d.fontSize
        width = (try? c.decode(ViewerWidth.self, forKey: .width)) ?? d.width
        wrapCode = (try? c.decode(Bool.self, forKey: .wrapCode)) ?? d.wrapCode
        remoteImages = (try? c.decode(Bool.self, forKey: .remoteImages)) ?? d.remoteImages
    }

    static func load() -> ViewerSettings {
        guard let url = SharedStore.settingsURL, let data = try? Data(contentsOf: url),
              let s = try? JSONDecoder().decode(ViewerSettings.self, from: data) else { return ViewerSettings() }
        return s
    }

    func save() {
        guard let url = SharedStore.settingsURL, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// 叠加在渲染器自带文章样式之后的覆盖样式
    var overrideCss: String {
        var css = ".velmo-article { font-size: \(Int(fontSize))px; max-width: \(width.css); }"
        if wrapCode {
            css += " .velmo-article pre, .velmo-article pre code { white-space: pre-wrap; word-break: break-word; }"
        }
        return css
    }
}

enum SharedStore {
    /// App Group 标识写在两个 target 的 Info.plist（VVAppGroup）里，由构建时的团队前缀展开。
    /// 没有团队签名（临时签名）时拿不到共享容器，退回各自的容器，设置就只在 App 里生效。
    static let directory: URL? = {
        let fm = FileManager.default
        var dir: URL?
        if let group = Bundle.main.object(forInfoDictionaryKey: "VVAppGroup") as? String, !group.hasPrefix("$") {
            dir = fm.containerURL(forSecurityApplicationGroupIdentifier: group)?
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        }
        dir = dir ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let dir { try? fm.createDirectory(at: dir, withIntermediateDirectories: true) }
        return dir
    }()

    static var settingsURL: URL? { directory?.appendingPathComponent("settings.json") }

    /// 扩展每次成功出预览时发出的 Darwin 通知，App 用它判断系统是不是真的在用本扩展。
    /// 快速查看扩展的沙盒不能写文件（包括 App Group 容器），所以不能靠写时间戳。
    static let previewedNotification = "ink.velmo.viewer.previewed"

    static func markPreviewed() {
        notify_post(previewedNotification)
    }
}
