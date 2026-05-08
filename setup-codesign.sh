#!/bin/bash
# 一次性创建本地 self-signed code signing 证书并导入登录钥匙串。
#
# 为什么要这个？
#   ad-hoc 签名（codesign --sign -）每次重编后 cdhash 变化，导致 macOS
#   的 designated requirement 变化，TCC（辅助功能权限数据库）认为是新 app，
#   每次都要重新授权一次。
#
#   用一个稳定的 self-signed 证书签名后，DR 包含的是证书指纹（不变），
#   重编不影响。从此辅助功能授权一次，永久保留。
#
# 工作原理：
#   1. openssl 生成 RSA 私钥 + X.509 自签名证书（带 Code Signing EKU）
#   2. 用 PKCS#12 打包，导入登录钥匙串
#   3. 标记为 trusted（仅限 codesign 用途，不会影响其他系统信任）
#
# 用法：
#   ./setup-codesign.sh                  # 默认名 "AirPodsRemap Self-Signed"
#   ./setup-codesign.sh "我的标识"       # 自定义证书 CN
#
# 跑一次就行。已存在同名证书时会跳过。

set -euo pipefail

CN="${1:-AirPodsRemap Self-Signed}"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
DAYS=3650
TMP_DIR="$(mktemp -d)"
trap "rm -rf '$TMP_DIR'" EXIT

echo "→ 检查是否已有同名 code signing 证书…"
if security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "\"$CN\""; then
    echo "✅ 已存在证书 \"$CN\"，跳过创建。"
    echo ""
    echo "   build.sh 已经能直接用它签名。"
    exit 0
fi

echo "→ 生成 X.509 配置…"
cat > "$TMP_DIR/cert.conf" <<EOF
[req]
distinguished_name = dn
prompt = no
req_extensions = v3_req
[dn]
CN = $CN
[v3_req]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
EOF

echo "→ 生成 RSA 2048 私钥 + 自签名证书（有效期 ${DAYS} 天）…"
openssl req -new -x509 -days "$DAYS" -nodes \
    -newkey rsa:2048 \
    -keyout "$TMP_DIR/cert.key" \
    -out "$TMP_DIR/cert.crt" \
    -config "$TMP_DIR/cert.conf" \
    -extensions v3_req \
    2>/dev/null

echo "→ 打包成 PKCS#12（临时密码 'tmp'，用 legacy 模式兼容 macOS Security framework）…"
PASS="tmp"
# OpenSSL 3.x 默认用 PBES2/SHA256 MAC，macOS Security framework 不支持。
# -legacy 启用旧 PBE 算法；-macalg SHA1 让 MAC 用 SHA1，确保 macOS 能验证。
openssl pkcs12 -export -legacy \
    -macalg SHA1 \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES \
    -inkey "$TMP_DIR/cert.key" \
    -in "$TMP_DIR/cert.crt" \
    -out "$TMP_DIR/cert.p12" \
    -password "pass:$PASS" \
    -name "$CN" \
    2>/dev/null

echo "→ 导入登录钥匙串…"
# -A 让所有应用都能访问这个证书（codesign 才能用）
# -T /usr/bin/codesign 限定只让 codesign 用（更安全的写法，但 -A 简单且本机工具）
security import "$TMP_DIR/cert.p12" \
    -P "$PASS" \
    -A \
    -k "$KEYCHAIN" \
    > /dev/null

echo "→ 标记为可信（仅 codeSign 策略）…"
# -p codeSign 限定只让它做代码签名信任，不会影响 SSL/邮件等其他系统信任
# 这一步会弹出输入电脑密码授权（修改钥匙串信任设置需要）
security add-trusted-cert \
    -d \
    -r trustRoot \
    -p codeSign \
    -k "$KEYCHAIN" \
    "$TMP_DIR/cert.crt" \
    2>&1 | grep -v "SecTrustSettingsSetTrustSettings: The authorization was canceled by the user." || true

echo ""
echo "→ 验证 codesign 能找到这个 identity…"
if security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "\"$CN\""; then
    echo "✅ 证书已就绪：\"$CN\""
    echo ""
    echo "下一步："
    echo "  ./build.sh         # build 时会自动用这个证书签名"
    echo ""
    echo "首次用这个证书签名后，需要重新授权辅助功能一次（因为签名身份变了）。"
    echo "之后任意 ./build.sh 不会再丢权限。"
else
    echo "⚠️  导入似乎成功但 codesign 找不到。可能需要："
    echo "   1. 打开 Keychain Access → 登录 → 找到 \"$CN\""
    echo "   2. 右键 → 显示简介 → Trust → 「使用此证书时」选「始终信任」"
    echo "   3. 关闭窗口（会要求电脑密码）"
    exit 1
fi
