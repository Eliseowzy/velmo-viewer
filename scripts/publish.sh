#!/bin/sh
# 把 scripts/build.sh release 做好的 dmg 发到官网下载和自动更新渠道（Cloudflare R2 的 velmo-media，域名 media.velmo.md）。
#   scripts/publish.sh             只准备：复制改名、算 sha256、EdDSA 签名、把新版本写进 release/appcast.xml。不上传
#   scripts/publish.sh --upload    准备好后上传：先传 dmg 和 .sha256，再覆盖固定下载地址 viewer/latest/Velmo-Viewer.dmg，
#                                  最后传 appcast.xml（老用户的 App 读它发现新版本）
#
# 发版前要准备：
#   - project.yml 里的 MARKETING_VERSION 和 CURRENT_PROJECT_VERSION 都加一。Sparkle 比较的是构建号，必须递增
#   - release/notes/<版本>.md 写更新说明（英文，必须有），可选 <版本>.zh-Hans.md / .zh-Hant.md / .ja.md / .ko.md
#   - 跑完 scripts/build.sh release
# 上传后：提交 release/appcast.xml，打 tag vX.Y.Z。官网下载按钮指向固定的 latest 地址，不用改也不用重新部署。
#
# EdDSA 私钥在本机钥匙串里（账户 ink.velmo.viewer），公钥写在 project.yml 的 VV_UPDATE_PUBLIC_KEY。
# 私钥丢了，已安装的用户就再也收不到更新：用 generate_keys --account ink.velmo.viewer -x <文件> 导出备份。
set -e
cd "$(dirname "$0")/.."
OUT=build.noindex
APP="$OUT/Velmo Viewer.app"
BUCKET=velmo-media
HOST=https://media.velmo.md
SPARKLE_BIN=$OUT/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin
# 官网下载按钮用的固定地址，每次发版覆盖成新版本的 dmg
LATEST_KEY=viewer/latest/Velmo-Viewer.dmg
UPLOAD=0
[ "${1:-}" = --upload ] && UPLOAD=1

die() { echo "$1" >&2; exit 1; }
plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$APP/Contents/Info.plist"; }

[ -d "$APP" ] || die "没有 $APP，先跑 scripts/build.sh release"
[ -x "$SPARKLE_BIN/sign_update" ] || die "找不到 Sparkle 工具（$SPARKLE_BIN），先跑一次 scripts/build.sh 让 Xcode 拉取 Sparkle"
VERSION=$(plist CFBundleShortVersionString)
BUILD=$(plist CFBundleVersion)
MINOS=$(plist LSMinimumSystemVersion)
[ -n "$(plist SUPublicEDKey)" ] || die "Info.plist 里没有 SUPublicEDKey，这不是直装版构建"

SRC="$OUT/Velmo Viewer_${VERSION}_universal.dmg"
[ -f "$SRC" ] || die "没有 $SRC，先跑 scripts/build.sh release"
xcrun stapler validate -q "$SRC" || die "$SRC 没有公证票据，重新跑 scripts/build.sh release"
NOTES=release/notes/$VERSION.md
[ -f "$NOTES" ] || die "没有更新说明 $NOTES"

NAME="Velmo-Viewer-$VERSION.dmg"
KEY="viewer/$VERSION/$NAME"
STAGE="$OUT/publish/$VERSION"
rm -rf "$STAGE" && mkdir -p "$STAGE"
cp "$SRC" "$STAGE/$NAME"
(cd "$STAGE" && shasum -a 256 "$NAME" > "$NAME.sha256")
# 输出形如 sparkle:edSignature="..." length="..."
SIGNATURE=$("$SPARKLE_BIN/sign_update" --account ink.velmo.viewer "$STAGE/$NAME")
echo "== $VERSION（构建 $BUILD）：$STAGE/$NAME"

cp release/appcast.xml "$STAGE/appcast.before.xml"
restore() { cp "$STAGE/appcast.before.xml" release/appcast.xml; }
# 新版本插到 appcast 最前面；同一个构建号已经在里面就停下，已发布的版本不能覆盖
python3 - "$VERSION" "$BUILD" "$MINOS" "$HOST/$KEY" "$SIGNATURE" <<'EOF'
import email.utils, glob, os, re, sys
version, build, minos, url, signature = sys.argv[1:]
path = "release/appcast.xml"
xml = open(path, encoding="utf-8").read()
if re.search(r"<sparkle:version>%s</sparkle:version>" % re.escape(build), xml):
    sys.exit(f"appcast 里已经有构建 {build}：发新版要先把 project.yml 的版本号和构建号加一")
notes = []
for f in sorted(glob.glob(f"release/notes/{version}*.md")):
    lang = os.path.basename(f)[len(version):-3].lstrip(".") or "en"
    text = open(f, encoding="utf-8").read().strip()
    notes.append(f'      <description xml:lang="{lang}" sparkle:format="markdown"><![CDATA[\n{text}\n]]></description>')
item = f"""    <item>
      <title>{version}</title>
      <pubDate>{email.utils.formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{minos}</sparkle:minimumSystemVersion>
{chr(10).join(notes)}
      <enclosure url="{url}" type="application/x-apple-diskimage" {signature}/>
    </item>
"""
marker = "    <!-- 新版本插在这里 -->\n"
open(path, "w", encoding="utf-8").write(xml.replace(marker, marker + item, 1))
EOF
xmllint --noout release/appcast.xml
cp release/appcast.xml "$STAGE/appcast.xml"
echo "== 已写进 release/appcast.xml"

if [ $UPLOAD = 0 ]; then
  echo "没有上传。确认无误后运行：scripts/publish.sh --upload"
  restore   # 只是预览，下次运行还会重新生成
  exit 0
fi

wrangler() { npx --yes wrangler "$@"; }
# 不能直接请求 media.velmo.md 上还没有的地址判断存不存在：Cloudflare 会把 404 缓存几个小时
if wrangler r2 object get "$BUCKET/$KEY.sha256" --remote --pipe >/dev/null 2>&1; then
  restore
  die "R2 上已经有 $KEY，已发布的版本不能覆盖，请升版本号"
fi
IMMUTABLE="public, max-age=31536000, immutable"
wrangler r2 object put "$BUCKET/$KEY" --remote --file "$STAGE/$NAME" \
  --content-type application/x-apple-diskimage --cache-control "$IMMUTABLE"
wrangler r2 object put "$BUCKET/$KEY.sha256" --remote --file "$STAGE/$NAME.sha256" \
  --content-type text/plain --cache-control "$IMMUTABLE"
# latest 和 appcast 是会被覆盖的两个文件，缓存要短（最多 5 分钟后才看到新版本）。
# latest 带 Content-Disposition，下载下来的文件名仍是带版本号的
wrangler r2 object put "$BUCKET/$LATEST_KEY" --remote --file "$STAGE/$NAME" \
  --content-type application/x-apple-diskimage --cache-control "public, max-age=300" \
  --content-disposition "attachment; filename=\"$NAME\""
# dmg 先传完再传 appcast，App 看到新版本时一定下载得到
wrangler r2 object put "$BUCKET/viewer/appcast.xml" --remote --file "$STAGE/appcast.xml" \
  --content-type application/xml --cache-control "public, max-age=300"
echo "== 已上传 $HOST/$KEY、$HOST/$LATEST_KEY 和 $HOST/viewer/appcast.xml"
echo "== 还要：git add release/appcast.xml && git commit && git tag v$VERSION"
