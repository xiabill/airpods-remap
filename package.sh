#!/bin/bash
# 一键生成所有发行产物：zip + dmg
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="AirPodsRemap"
APP_BUNDLE="${APP_NAME}.app"
VERSION="1.4.0"
DIST_DIR="dist"
PAYLOAD_DIR="${DIST_DIR}/${APP_NAME}-${VERSION}"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.zip"

# 1. 构建（universal binary）
./build.sh

# 2. 准备 zip payload
rm -rf "$DIST_DIR"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_BUNDLE" "$PAYLOAD_DIR/"

# 使用说明（单一来源：USAGE.txt）
cp USAGE.txt "$PAYLOAD_DIR/使用说明.txt"

echo "→ 打包 zip…"
ditto -c -k --sequesterRsrc --keepParent "$PAYLOAD_DIR" "$ZIP_PATH"
ZIP_SIZE=$(du -h "$ZIP_PATH" | awk '{print $1}')

# 3. 生成 dmg（make-dmg.sh 不依赖 PAYLOAD_DIR，直接用根目录的 .app）
./make-dmg.sh
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
DMG_SIZE=$(du -h "$DMG_PATH" | awk '{print $1}')

echo ""
echo "═══════════════════════════════════════════════"
echo "✅ 发行产物已就绪："
echo "   • $ZIP_PATH  ($ZIP_SIZE)   ← 解压即用"
echo "   • $DMG_PATH  ($DMG_SIZE)   ← 双击挂载，拖拽到 Applications 安装"
echo "═══════════════════════════════════════════════"
