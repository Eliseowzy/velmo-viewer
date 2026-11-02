# Third-Party Notices

Velmo Viewer 本身的源码按 [Apache License 2.0](LICENSE) 发布。下面这些随仓库或随 App 分发的部分有各自的许可证。

## 预编译的 Markdown 渲染器（非 Apache-2.0）

`QuickLook/web/quicklook.js` 和 `QuickLook/web/quicklook.css` 是预编译的渲染器，源码不公开，**不在 Apache License 2.0 的授权范围内**。

Copyright © 2026 Velmo. 允许你原样（不修改）把这两个文件作为 Velmo Viewer 或其衍生版本构建产物的一部分进行再分发；除此之外保留所有权利。

渲染器里打包了以下开源库，均为 MIT 许可证：

| 库 | 版本 | 许可证 |
| --- | --- | --- |
| [KaTeX](https://github.com/KaTeX/KaTeX)（含字体） | 0.19.1 | MIT |
| [@codemirror/language](https://github.com/codemirror/language) | 6.13.1 | MIT |
| [@codemirror/language-data](https://github.com/codemirror/language-data) 及其引入的各语言包 | 6.5.2 | MIT |
| [@codemirror/state](https://github.com/codemirror/state) | 6.7.6 | MIT |
| [@lezer/common](https://github.com/lezer-parser/common) | 1.5.4 | MIT |
| [@lezer/highlight](https://github.com/lezer-parser/highlight) | 1.2.5 | MIT |

## 随仓库分发的库

| 文件 | 库 | 版本 | 许可证 |
| --- | --- | --- | --- |
| `QuickLook/web/echarts.min.js` | [Apache ECharts](https://github.com/apache/echarts) | 6.1.0 | Apache-2.0 |
| `QuickLook/web/mermaid.min.js` | [Mermaid](https://github.com/mermaid-js/mermaid) 及其打包的依赖 | 12.2.0 | MIT |

Apache ECharts 的 NOTICE：

```
Apache ECharts
Copyright 2017-2026 The Apache Software Foundation

This product includes software developed at
The Apache Software Foundation (https://www.apache.org/).
```

## 构建时拉取的依赖

| 库 | 版本 | 许可证 | 用途 |
| --- | --- | --- | --- |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | 2.10.1 | MIT | 官网直装版的自动更新（App Store 版不链接） |

## 商标

Apache License 2.0 不授予商标使用权（第 6 条）。「Velmo」「Velmo Viewer」名称和 App 图标属于 Velmo。欢迎 fork 和修改，但如果要分发修改过的版本，请换一个名字和图标，以免和官方版本混淆。
