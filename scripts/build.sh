#!/bin/sh
# 构建 Velmo Viewer。
#   scripts/build.sh            本机调试：Release 构建，签名后放到 build.noindex/Velmo Viewer.app
#   scripts/build.sh install    构建后装到 /Applications，打开一次让系统注册空格预览扩展
#   scripts/build.sh release    做给别人用的 dmg：universal 构建，交给 ~/Documents/macos-release/release-mac.sh 签名、公证；
#                               之后用 scripts/publish.sh 上传并发布自动更新
#   scripts/build.sh appstore   归档并导出给 App Store Connect 的 .pkg（需要在 Xcode 里登录开发者账号）
# 只要装了 Xcode，不要求 xcode-select 指向它。
# 输出目录带 .noindex：Spotlight 不索引，「应用程序」里不会多出一个 Velmo Viewer。
set -e
cd "$(dirname "$0")/.."
OUT=build.noindex
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

if ! xcodebuild -version >/dev/null 2>&1; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
command -v xcodegen >/dev/null && xcodegen -q

build_dev() {
  # 用 Developer ID 证书签名（App Group 需要团队前缀，临时签名下设置共享不了）
  # 额外参数直接传给 xcodebuild
  IDENTITY="${APPLE_SIGNING_IDENTITY:-Developer ID Application}"
  xcodebuild -project VelmoViewer.xcodeproj -scheme VelmoViewer -configuration Release \
    -derivedDataPath $OUT/DerivedData \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" PROVISIONING_PROFILE_SPECIFIER= \
    OTHER_CODE_SIGN_FLAGS=--timestamp "$@" -quiet build
  rm -rf "$OUT/Velmo Viewer.app"
  cp -R "$OUT/DerivedData/Build/Products/Release/Velmo Viewer.app" $OUT/
  # xcodebuild 会把构建产物登记到 LaunchServices，取消掉，免得系统认出好几个 Velmo Viewer、扩展也注册好几份
  "$LSREGISTER" -u "$OUT/DerivedData/Build/Products/Release/Velmo Viewer.app" 2>/dev/null || true
  "$LSREGISTER" -u "$OUT/Velmo Viewer.app" 2>/dev/null || true
}

case "${1:-dev}" in
dev)
  build_dev
  echo "$OUT/Velmo Viewer.app"
  ;;
install)
  build_dev
  osascript -e 'quit app id "ink.velmo.viewer"' 2>/dev/null || true
  rm -rf "/Applications/Velmo Viewer.app"
  ditto "$OUT/Velmo Viewer.app" "/Applications/Velmo Viewer.app"
  "$LSREGISTER" -f "/Applications/Velmo Viewer.app"
  open "/Applications/Velmo Viewer.app"
  echo "/Applications/Velmo Viewer.app"
  ;;
release)
  # 发给别人用的 dmg：universal、去掉 get-task-allow（带着它公证不过），再交给 release-mac.sh 签名、公证、钉票、做 dmg
  RELEASE_MAC="${RELEASE_MAC:-$HOME/Documents/macos-release/release-mac.sh}"
  [ -x "$RELEASE_MAC" ] || { echo "找不到 $RELEASE_MAC，用 RELEASE_MAC=... 指定" >&2; exit 1; }
  build_dev -destination 'generic/platform=macOS' CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO
  APP="$OUT/Velmo Viewer.app"
  APPEX="$APP/Contents/PlugIns/VelmoViewerQuickLook.appex"
  # release-mac.sh 会重签整个包，沙盒和 App Group 要原样带上，不然扩展加载不了。直接从 Xcode 签好的包里取（团队前缀已展开）
  codesign -d --entitlements - --xml "$APP" > $OUT/app.entitlements
  codesign -d --entitlements - --xml "$APPEX" > $OUT/quicklook.entitlements
  if grep -q get-task-allow $OUT/app.entitlements $OUT/quicklook.entitlements; then
    echo "entitlements 里还有 get-task-allow，公证会被拒" >&2; exit 1
  fi
  "$RELEASE_MAC" "$APP" --identity "${APPLE_SIGNING_IDENTITY:-Developer ID Application}" --out $OUT \
    --entitlements $OUT/app.entitlements --entitle VelmoViewerQuickLook.appex=$OUT/quicklook.entitlements
  ;;
appstore)
  # App Store 版是单独的 target：不带 Sparkle，更新交给 App Store
  xcodebuild -project VelmoViewer.xcodeproj -scheme VelmoViewerAppStore -configuration Release \
    -archivePath $OUT/VelmoViewer.xcarchive -allowProvisioningUpdates -quiet archive
  xcodebuild -exportArchive -archivePath $OUT/VelmoViewer.xcarchive \
    -exportOptionsPlist scripts/ExportOptions-AppStore.plist -exportPath $OUT/appstore -allowProvisioningUpdates
  echo "$OUT/appstore —— 用 Transporter 上传，或把上面的 export 换成 destination=upload"
  ;;
*)
  echo "用法：scripts/build.sh [dev|install|release|appstore]" >&2
  exit 1
  ;;
esac
