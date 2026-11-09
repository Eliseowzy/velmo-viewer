#!/bin/sh
# 从 package-lock.json 锁定的 npm 包同步 Quick Look 页面产物。
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
RENDERER="$ROOT/node_modules/velmo-render"

cd "$ROOT"
npm ci --ignore-scripts
cp "$RENDERER/dist/quicklook.js" "$ROOT/QuickLook/web/quicklook.js"
cp "$RENDERER/dist/quicklook.css" "$ROOT/QuickLook/web/quicklook.css"

VERSION=$(node -p "require('$RENDERER/package.json').version")
echo "Synced velmo-render $VERSION from npm"
