#!/bin/bash
# 生成 .dmg 安装镜像（含 Applications 拖拽快捷方式）
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="AirPodsRemap"
APP_BUNDLE="${APP_NAME}.app"
VERSION="1.4.0"
DIST_DIR="dist"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
STAGING="${DIST_DIR}/.dmg-staging"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "未找到 $APP_BUNDLE，先跑 ./build.sh"
  exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"

# 拷贝 app
cp -R "$APP_BUNDLE" "$STAGING/"

# 创建 Applications 软链，方便用户拖拽安装
ln -s /Applications "$STAGING/Applications"

# 把使用说明也放进 dmg（单一来源：USAGE.txt）
cp USAGE.txt "$STAGING/使用说明.txt"

# 生成 DMG（UDZO = 压缩 + 只读）
echo "→ 生成 DMG…"
hdiutil create \
  -volname "AirPods Remap ${VERSION}" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

# 清理 staging
rm -rf "$STAGING"

SIZE=$(du -h "$DMG_PATH" | awk '{print $1}')
echo "✅ 已生成: $PWD/$DMG_PATH  ($SIZE)"
