# 发版（维护者用）

以下步骤需要 Velmo 团队的签名证书、Sparkle 私钥和 R2 权限，fork 用不上。

## 官网直装版和自动更新

两个渠道：App Store 版（target `VelmoViewerAppStore`）由 App Store 更新，不带任何自更新代码；官网 dmg 直装版（target `VelmoViewer`）用 [Sparkle](https://sparkle-project.org) 自动更新。更新相关代码在 `App/Updater.swift`，只在直装版编译（`DIRECT_DISTRIBUTION`）。

直装版每次启动检查 `https://media.velmo.md/viewer/appcast.xml`，有新版本就在后台下载，App 退出时安装。用户很少打开这个 App，所以没有常驻检查。设置页和菜单栏都有「检查更新…」。

发一个新版本：

1. `project.yml` 里 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION` 都加一（Sparkle 比较的是构建号，必须递增）
2. 写 `release/notes/<版本>.md`（英文，必须有），可以再加 `<版本>.zh-Hans.md`、`.zh-Hant.md`、`.ja.md`、`.ko.md`，Sparkle 按用户的系统语言选
3. `scripts/build.sh release`：签名、公证、做 dmg
4. `scripts/publish.sh`：签名并预览 appcast；确认后 `scripts/publish.sh --upload` 上传到 R2，同时覆盖固定下载地址 `viewer/latest/Velmo-Viewer.dmg`
5. 提交 `release/appcast.xml`，打 tag

官网下载按钮指向固定的 `https://media.velmo.md/viewer/latest/Velmo-Viewer.dmg`（缓存 5 分钟，下载的文件名带版本号），发版不用再改官网。

更新包用 EdDSA 签名，私钥在发版这台 Mac 的钥匙串里（账户 `ink.velmo.viewer`），公钥在 `project.yml` 的 `VV_UPDATE_PUBLIC_KEY`。**私钥丢了，已安装的用户就收不到更新了**，务必备份：`generate_keys --account ink.velmo.viewer -x <文件>`（工具在 `build.noindex/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin`）。

## App Store 版

先在 Xcode → Settings → Accounts 登录团队 68DH8M43U8 的账号，然后：

```bash
scripts/build.sh appstore
```

脚本会自动签名并生成描述文件，导出到 `build.noindex/appstore`（导出选项在 `scripts/ExportOptions-AppStore.plist`），再用 Transporter 上传。也可以直接在 Xcode 里 Product → Archive → Distribute。上架文案和截图在 `appstore/`。
