# Velmo Viewer

English | [简体中文](README_CN.md)

Select a `.md` file in Finder, press Space, and read it as a typeset article instead of a screen of raw text.

Velmo Viewer is a macOS Quick Look extension, plus a small host app for setup and settings. It runs on macOS 13 and later.

![Previewing Markdown in Quick Look](appstore/screenshots/en/1-ql-kyoto.png)

## Why

Markdown is now one of the most common ways people write: READMEs, notes, meeting minutes, design docs, AI-generated reports. Yet on a Mac, just *looking* at a `.md` file is awkward:

- Built-in Quick Look treats it as plain text. Every `#`, `**` and `|---|` is on display, and tables, math and charts are unreadable.
- Double-clicking launches an editor, when most of the time you only want to read, not edit.
- Existing preview plugins are either rough-looking, lack math and chart support, or are unmaintained and no longer install on current macOS.

What we wanted: select a file anywhere, press Space, and get the same result as a carefully designed reader. Press Space again and it's gone, with nothing else disturbed.

## Features

**What it renders**

- Headings, bold, italic, strikethrough, links and inline code
- Task lists, tables, block quotes and footnotes
- Syntax highlighting in code blocks
- Source-file previews for Swift, C/C++, Objective-C, Java, Python, JavaScript/TypeScript, Go, Rust, Ruby, PHP, shell, HTML/CSS, SQL, JSON/JSONL, XML and YAML
- LaTeX math, inline and display
- ` ```echarts ` blocks: an ECharts option written as JSON, drawn as a chart
- ` ```mermaid ` blocks: flowcharts, sequence diagrams and anything else Mermaid supports
- Local images next to the document; web images optionally

**What you can adjust**

- Theme: light, dark or follow the system
- Font size and text width
- Soft-wrap long lines in code blocks
- Whether to load web images

The settings window has a live preview on the right. Changes show immediately and apply the next time you press Space.

**Onboarding**

On first launch a three-step guide shows where to turn on the extension in System Settings. Click **Test** and the app opens a Quick Look panel and checks that the extension is really the one in use.

| Settings and live preview | First-launch guide |
| --- | --- |
| ![Settings](appstore/screenshots/en/5-app-settings.png) | ![Onboarding](appstore/screenshots/en/6-app-onboarding.png) |

## Highlights

- **What you see is what you get.** The live preview in Settings and the Space-bar preview use the same renderer and the same styles, so there's no "looks right in Settings, different in Finder".
- **Fully local, no data collected.** Everything renders on your Mac. Files are never uploaded, and there's no analytics or tracking. The only network access is fetching images from the addresses in a document, and only if you turn on **Load web images**.
- **Safe by default.** A preview can be a file from anywhere, so the renderer blocks scripts, event-handler attributes and `javascript:` links in documents. ECharts accepts JSON only and never runs functions; Mermaid runs at its strict security level, which strips HTML from labels.
- **Loaded on demand.** ECharts and Mermaid are large, so they load only when a document actually contains such a block. Ordinary documents open fast.
- **Sandboxed throughout.** Both the app and the extension use App Sandbox and no private APIs, so it can ship on the Mac App Store.
- **Localized.** The interface and sample document are available in English, Simplified Chinese, Traditional Chinese, Japanese and Korean.

## Design notes

**Quick Look is the best place to read.** Reading happens in Finder, in the Downloads folder, in a zip someone sent you. Rather than build a reader you have to "open", we put reading into an action the system already has: Space. So the product is the extension; the app is just its settings page and manual.

**The app does only what it must.** Many people will install it, set it up once and never open it again. So the app has no file browser, no editing and no account, only onboarding, settings and a preview. To stay out of the way it doesn't claim it can open `.md` files, so it never takes over your default editor, and it doesn't run in the background.

**Typography comes first.** Turning Markdown into HTML is easy; turning it into something *pleasant to read* is not. Font size, line length, heading hierarchy, code blocks and tables are all tuned for long-form reading rather than borrowing a generic GitHub stylesheet.

**Charts and math are part of the document.** More and more Markdown carries formulas, data and diagrams, especially technical docs and AI-generated reports. A preview that only shows the source inside those code blocks isn't much of a preview. But charts can't come at the cost of safety, so they're supported as data only, never as executable code.

**Be honest about system limits.** macOS picks a single Quick Look extension per file type, and the choice is the system's; the extension's sandbox is read-only. These limits can't be worked around, so the app explains them (guiding you to turn off other Markdown extensions) and offers a **Test** button that actually verifies the result, instead of pretending everything is fine.

## Download

- Mac App Store: search for "Velmo Viewer"
- Direct download with automatic updates: [velmo.md/viewer](https://velmo.md/viewer)
- GitHub: get the dmg from [Releases](https://github.com/Eliseowzy/velmo-viewer/releases/latest). It's the same file as the direct download and updates itself the same way

After installing, open the app once and follow the guide to enable Velmo Viewer in **System Settings → General → Login Items & Extensions → Quick Look** (on macOS 13 and 14: **Privacy & Security → Extensions → Quick Look**). If you have other Markdown Quick Look extensions installed, turn them off; the system uses only one.

## Contributing

Issues and pull requests are welcome: rendering bugs, style improvements, new languages and support for new macOS versions are all valuable. When reporting a rendering problem, the snippet of Markdown that reproduces it helps a lot.

### Requirements

- macOS 13+ and Xcode (`xcode-select` doesn't need to point to it; the scripts look for `/Applications/Xcode.app`)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`. The Xcode project is generated from `project.yml`; regenerate it after changing that file or adding or removing source files

### Build and run

```bash
scripts/build.sh install
```

This builds the app, installs it to `/Applications` and opens it once so the extension registers with the system. To build without installing, run `scripts/build.sh`; output goes to `build.noindex/` (not indexed by Spotlight, so no extra copy shows up in Applications).

Settings are shared through an App Group, and App Group identifiers carry the development team prefix, so you need a real signing certificate. Ad-hoc signing runs too, but settings then apply only inside the app and the extension can't read them. If you're not on the original team, create `Signing.local.xcconfig` in the repository root (it's git-ignored) with one line:

```
DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

Then build with your own certificate. `scripts/build.sh` looks for a Developer ID certificate in your keychain by default; with a free account, use a development certificate instead: `APPLE_SIGNING_IDENTITY="Apple Development" scripts/build.sh install`.

### Layout

```
App/          Host app (SwiftUI): onboarding, settings, live preview, sample document, icon
QuickLook/    Quick Look extension
  web/        Render page: quicklook.js/css is built from the independent velmo-render project;
              vv-echarts.js and vv-mermaid.js handle their code blocks;
              echarts.min.js and mermaid.min.js are npm dist files, replaced as-is on upgrade
Shared/       Shared by both: settings (ViewerSettings.swift), rendering (MarkdownRenderer.swift), localized strings
design/       Icon sources
appstore/     App Store listing copy and screenshots
release/      Auto-update feed appcast.xml and per-version release notes
scripts/      Build and release scripts (release process in RELEASING.md, in Chinese)
project.yml   XcodeGen project spec
```

There are two app targets. `VelmoViewer` is the direct-download build with [Sparkle](https://sparkle-project.org) auto-update (that code compiles only under `DIRECT_DISTRIBUTION`); `VelmoViewerAppStore` is updated by the App Store and doesn't link Sparkle. Use the former for day-to-day development.

### Non-obvious implementation details

- **One renderer, two uses.** `MarkdownRenderer` loads `QuickLook/web/index.html` in a WKWebView. The extension uses it for the Space-bar preview and the app for its live preview; the app reads `web/` straight from the embedded extension bundle instead of shipping a second copy. Markdown parsing and syntax highlighting come from the versioned `velmo-render` npm package. Update its version in `package.json`, then run `npm run sync-renderer` to sync the two vendored files from the locked package.
- **How settings are shared.** The app writes `settings.json` to the App Group container and the extension rereads it on every preview. `UserDefaults(suiteName:)` isn't used because a long-lived process would read stale cached values.
- **The extension can't write files.** A Quick Look extension's sandbox is read-only, App Group container included. So the **Test** button works like this: after rendering, the extension posts a Darwin notification (`ink.velmo.viewer.previewed`), and if the app receives it within a few seconds, the extension is active.
- **Loading local resources.** A sandboxed WKWebView content process can't read arbitrary local files, so the render page and images next to the document go through a custom `vv-asset://` scheme; the host process reads them and hands them to the page.
- **Restyle without re-rendering.** Changing font size, width or theme just swaps the override styles in the page. Only settings that affect loading, such as web images, trigger a full re-render.

### Debugging tips

- With several Markdown Quick Look extensions installed, the system decides which one runs. Turn the others off in System Settings before debugging, or what you're looking at may not be your build at all.
- `qlmanage -r` resets the Quick Look cache, and `qlmanage -p file.md` opens a preview straight from the command line.
- The "Open with X" button in the top-right of the Quick Look panel shows the default app for `.md`, which has nothing to do with which extension rendered the preview.

## License

This repository is released under the [Apache License 2.0](LICENSE), with one exception:

- The "Velmo" and "Velmo Viewer" names and icon aren't licensed. Forks are welcome, but please use a different name and icon if you distribute a modified version.

`QuickLook/web/quicklook.js` and `quicklook.css` are built from the Apache-2.0-licensed `velmo-render` source.

Third-party licenses are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
