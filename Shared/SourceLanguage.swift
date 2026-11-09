import Foundation
import UniformTypeIdentifiers

/// Quick Look 内容类型、文件名与独立代码渲染器语言标识之间的唯一映射。
enum SourceLanguage: String, CaseIterable {
    case markdown
    case swift
    case c
    case cpp
    case objectiveC = "objc"
    case java
    case python
    case shell
    case javascript
    case typescript = "tsx"
    case go
    case rust
    case ruby
    case php
    case html
    case css
    case sql
    case json
    case xml
    case yaml

    private var contentTypes: [String] {
        switch self {
        case .markdown:
            return ["net.daringfireball.markdown", "public.markdown"]
        case .swift:
            return ["public.swift-source"]
        case .c:
            return ["public.c-source", "public.c-header"]
        case .cpp:
            return ["public.c-plus-plus-source", "public.c-plus-plus-header"]
        case .objectiveC:
            return ["public.objective-c-source", "public.objective-c-plus-plus-source"]
        case .java:
            return ["com.sun.java-source"]
        case .python:
            return ["public.python-script"]
        case .shell:
            return ["public.shell-script", "public.zsh-script"]
        case .javascript:
            return ["com.netscape.javascript-source"]
        case .typescript:
            return ["public.typescript-source", "com.microsoft.typescript"]
        case .go:
            return ["public.go-source"]
        case .rust:
            return ["public.rust-source"]
        case .ruby:
            return ["public.ruby-script"]
        case .php:
            return ["public.php-script"]
        case .html:
            return ["public.html"]
        case .css:
            return ["public.css"]
        case .sql:
            return ["org.iso.sql"]
        case .json:
            return ["public.json"]
        case .xml:
            return ["public.xml"]
        case .yaml:
            return ["public.yaml"]
        }
    }

    private var extensions: Set<String> {
        switch self {
        case .markdown:
            return ["md", "markdown", "mdown", "mkdn", "mkd"]
        case .swift:
            return ["swift"]
        case .c:
            return ["c", "h"]
        case .cpp:
            return ["cpp", "cc", "cxx", "c++", "hpp", "hh", "hxx", "h++", "ipp"]
        case .objectiveC:
            return ["m", "mm"]
        case .java:
            return ["java"]
        case .python:
            return ["py", "pyw"]
        case .shell:
            return ["sh", "bash", "zsh"]
        case .javascript:
            return ["js", "mjs", "cjs", "jsx"]
        case .typescript:
            return ["ts", "tsx", "mts", "cts"]
        case .go:
            return ["go"]
        case .rust:
            return ["rs"]
        case .ruby:
            return ["rb", "rake", "gemspec"]
        case .php:
            return ["php", "phtml"]
        case .html:
            return ["html", "htm"]
        case .css:
            return ["css"]
        case .sql:
            return ["sql"]
        case .json:
            return ["json", "jsonc", "geojson"]
        case .xml:
            return ["xml", "xsd", "xsl", "xslt", "plist", "storyboard", "xib"]
        case .yaml:
            return ["yaml", "yml"]
        }
    }

    private var specialFilenames: Set<String> {
        switch self {
        case .shell:
            return [".bashrc", ".bash_profile", ".bash_login", ".profile",
                    ".zshrc", ".zprofile", ".zlogin", ".zshenv"]
        case .json:
            return [".babelrc", ".eslintrc", ".prettierrc"]
        case .yaml:
            return [".yamllint"]
        default:
            return []
        }
    }

    /// 特殊文件名优先，精确内容类型其次，扩展名兜底（无扩展名的脚本靠内容类型识别）。
    static func resolve(for url: URL, contentType: UTType? = nil) -> SourceLanguage? {
        let filename = url.lastPathComponent.lowercased()
        if let match = allCases.first(where: { $0.specialFilenames.contains(filename) }) {
            return match
        }

        let resourceType = contentType ?? (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
        if let identifier = resourceType?.identifier.lowercased(),
           let match = allCases.first(where: { $0.contentTypes.contains(identifier) }) {
            return match
        }

        let ext = url.pathExtension.lowercased()
        return allCases.first { $0.extensions.contains(ext) }
    }

    /// 截断提示保持为该语言的注释，避免用户误以为看到了完整文件。
    func truncationNotice(limit: Int) -> String {
        let message = "Quick Look preview is limited to the first \(limit / 1_048_576) MiB; remaining source is not shown."
        switch self {
        case .python, .shell, .yaml, .ruby:
            return "# \(message)\n"
        case .xml, .html:
            return "<!-- \(message) -->\n"
        case .css:
            return "/* \(message) */\n"
        case .sql:
            return "-- \(message)\n"
        default:
            return "// \(message)\n"
        }
    }
}
