#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="AirPodsRemap"
APP_BUNDLE="${APP_NAME}.app"
BUNDLE_ID="com.xiabill.airpods-remap"
VERSION="2.0.0"

# 1. 确保图标存在；不存在则现做
if [[ ! -f AppIcon.icns ]]; then
  echo "→ 生成 icon…"
  swiftc -framework Cocoa make-icon.swift -o make-icon
  ./make-icon AppIcon.iconset
  iconutil -c icns AppIcon.iconset -o AppIcon.icns
fi

# 2. 清理上次构建
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 3. 编译 Swift（universal binary：arm64 + x86_64）
echo "→ 编译 arm64…"
swiftc -O -parse-as-library \
  -target arm64-apple-macos13.0 \
  -framework Cocoa -framework SwiftUI -framework CoreGraphics -framework ServiceManagement \
  AirPodsRemap.swift \
  -o /tmp/${APP_NAME}-arm64

echo "→ 编译 x86_64…"
swiftc -O -parse-as-library \
  -target x86_64-apple-macos13.0 \
  -framework Cocoa -framework SwiftUI -framework CoreGraphics -framework ServiceManagement \
  AirPodsRemap.swift \
  -o /tmp/${APP_NAME}-x86_64

echo "→ lipo 合并…"
lipo -create \
  /tmp/${APP_NAME}-arm64 \
  /tmp/${APP_NAME}-x86_64 \
  -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
rm -f /tmp/${APP_NAME}-arm64 /tmp/${APP_NAME}-x86_64
file "$APP_BUNDLE/Contents/MacOS/$APP_NAME" | sed 's/^/   /'

# 4. 拷贝图标
cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# 5. 生成 Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>AirPods Remap</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>© 2026 xiabill</string>
</dict>
</plist>
EOF

# 6. 签名：优先用 self-signed code signing 证书（让辅助功能权限在重编后稳定保留）
#    找不到时 fallback 到 ad-hoc。先跑 ./setup-codesign.sh 一次创建证书。
SIGNING_IDENTITY="${SIGNING_IDENTITY:-AirPodsRemap Self-Signed}"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"${SIGNING_IDENTITY}\""; then
    echo "→ 用 self-signed 证书签名（${SIGNING_IDENTITY}）…"
    codesign --force --deep --sign "${SIGNING_IDENTITY}" "$APP_BUNDLE" >/dev/null
else
    echo "→ ad-hoc 签名（未找到 \"${SIGNING_IDENTITY}\"；要稳定权限请跑 ./setup-codesign.sh）…"
    codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
fi

# 7. 移除可能存在的隔离属性（本地构建一般不会有）
xattr -dr com.apple.quarantine "$APP_BUNDLE" 2>/dev/null || true

# 8. 让 Finder 立刻刷新图标缓存
touch "$APP_BUNDLE"

echo "✅ 构建完成: $PWD/$APP_BUNDLE"
echo "   启动: open '$PWD/$APP_BUNDLE'"
