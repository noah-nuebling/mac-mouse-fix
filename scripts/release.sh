#!/usr/bin/env bash

# Mac Mouse Fix Sparkle 自动化发布脚本
# 用法: ./scripts/release.sh <版本号>
# 示例: ./scripts/release.sh 3.1.2

set -euo pipefail

VERSION=${1:-}

if [ -z "$VERSION" ]; then
    echo "错误: 请提供版本号 (例如: 3.1.2)"
    exit 1
fi


# 签名校验函数：确保生成的 EdDSA 签名与 App 内置公钥一致
verify_signature() {
    local zip_path="$1"
    local signature="$2"
    local pubkey="$3"
    local arch="$4"

    echo "正在校验 $arch 的签名是否与内置公钥匹配..."
    
    local verify_result
    verify_result=$(swift - "$zip_path" "$signature" "$pubkey" <<'EOF'
import Foundation
import CryptoKit

let arguments = CommandLine.arguments
guard arguments.count >= 4 else {
    print("Invalid arguments")
    exit(1)
}

let zipPath = arguments[1]
let signatureBase64 = arguments[2]
let publicKeyBase64 = arguments[3]

guard let pubKeyData = Data(base64Encoded: publicKeyBase64) else {
    print("Error: Failed to base64 decode public key.")
    exit(1)
}
guard let sigData = Data(base64Encoded: signatureBase64) else {
    print("Error: Failed to base64 decode signature.")
    exit(1)
}
guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: zipPath)) else {
    print("Error: Failed to read zip file data.")
    exit(1)
}

do {
    let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: pubKeyData)
    if publicKey.isValidSignature(sigData, for: fileData) {
        print("OK")
        exit(0)
    } else {
        print("FAIL")
        exit(1)
    }
} catch {
    print("Error: \(error)")
    exit(1)
}
EOF
)

    if [ "$verify_result" != "OK" ]; then
        echo "===================================================="
        echo "错误: $arch 的签名校验失败！"
        echo "生成的签名与 App 内置的 SUPublicEDKey 不匹配。"
        echo "内置公钥: $pubkey"
        echo "这通常是因为您的 Keychain 中存储了其他项目 (如其他使用 Sparkle 的 App) 的私钥，"
        echo "导致默认的 'ed25519' 账号读取到了错误的私钥。"
        echo "请在 Keychain 中为 Mac Mouse Fix 使用专有的私钥并清理冲突的记录。"
        echo "===================================================="
        exit 1
    else
        echo "$arch 签名校验通过！"
    fi
}

# 1. 配置路径
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$PROJECT_DIR/releases"
APPCAST_FILE="$PROJECT_DIR/appcast.xml"
DMG_ARM64="$RELEASE_DIR/Mac_Mouse_Fix_${VERSION}_arm64.dmg"
DMG_X86_64="$RELEASE_DIR/Mac_Mouse_Fix_${VERSION}_x86_64.dmg"
ZIP_ARM64="$RELEASE_DIR/Mac_Mouse_Fix_${VERSION}_arm64.zip"
ZIP_X86_64="$RELEASE_DIR/Mac_Mouse_Fix_${VERSION}_x86_64.zip"

APP_ARM64="$PROJECT_DIR/Mac Mouse Fix_arm64.app"
APP_X86_64="$PROJECT_DIR/Mac Mouse Fix_x86_64.app"

# Automatically create ZIP if the APP bundle exists
if [ -d "$APP_ARM64" ]; then
    echo "正在将 arm64 app 打包为 ZIP..."
    rm -f "$ZIP_ARM64"
    
    # Use a temporary directory to rename the app to 'Mac Mouse Fix.app'
    # so Sparkle extracts it with the correct name and succeeds.
    STAGE_DIR_ARM64=$(mktemp -d "${TMPDIR:-/tmp}/macmousefix-zip-arm64.XXXXXX")
    cp -R "$APP_ARM64" "${STAGE_DIR_ARM64}/Mac Mouse Fix.app"
    chmod -R u+w "${STAGE_DIR_ARM64}/Mac Mouse Fix.app"
    xattr -cr "${STAGE_DIR_ARM64}/Mac Mouse Fix.app"
    ditto -c -k --sequesterRsrc --keepParent "${STAGE_DIR_ARM64}/Mac Mouse Fix.app" "$ZIP_ARM64"
    rm -rf "$STAGE_DIR_ARM64"
fi

if [ -d "$APP_X86_64" ]; then
    echo "正在将 x86_64 app 打包为 ZIP..."
    rm -f "$ZIP_X86_64"
    
    # Use a temporary directory to rename the app to 'Mac Mouse Fix.app'
    # so Sparkle extracts it with the correct name and succeeds.
    STAGE_DIR_X86_64=$(mktemp -d "${TMPDIR:-/tmp}/macmousefix-zip-x86_64.XXXXXX")
    cp -R "$APP_X86_64" "${STAGE_DIR_X86_64}/Mac Mouse Fix.app"
    chmod -R u+w "${STAGE_DIR_X86_64}/Mac Mouse Fix.app"
    xattr -cr "${STAGE_DIR_X86_64}/Mac Mouse Fix.app"
    ditto -c -k --sequesterRsrc --keepParent "${STAGE_DIR_X86_64}/Mac Mouse Fix.app" "$ZIP_X86_64"
    rm -rf "$STAGE_DIR_X86_64"
fi

# 定位签名工具。允许通过环境变量覆盖，默认从当前 DerivedData 中查找。
SIGN_TOOL="${SIGN_TOOL:-}"
if [ -z "$SIGN_TOOL" ]; then
    SIGN_TOOL=$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update" -type f 2>/dev/null | head -n 1 || true)
fi
if [ -z "$SIGN_TOOL" ] || [ ! -x "$SIGN_TOOL" ]; then
    echo "错误: 找不到 Sparkle sign_update。请先构建项目或设置 SIGN_TOOL=/path/to/sign_update"
    exit 1
fi

# 检查 ZIP 是否存在
if [ ! -f "$ZIP_ARM64" ]; then
    echo "错误: 找不到 arm64 ZIP 文件：$ZIP_ARM64"
    exit 1
fi

HAS_X86=0
if [ -f "$ZIP_X86_64" ]; then
    HAS_X86=1
fi

echo "--- 开始为版本 $VERSION 准备发布 ---"

# 2. 从项目设置中获取当前的 Build 号 (sparkle:version)
echo "正在从项目设置中提取流水号 Build 号..."
SPARKLE_VERSION=""
if [ -f "/tmp/MacMouseFix_build/Mac Mouse Fix_arm64.app/Contents/Info.plist" ]; then
    SPARKLE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "/tmp/MacMouseFix_build/Mac Mouse Fix_arm64.app/Contents/Info.plist" 2>/dev/null || true)
fi

if [ -z "$SPARKLE_VERSION" ] || [[ "$SPARKLE_VERSION" == *"Doesn't Exist"* ]]; then
    SPARKLE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PROJECT_DIR/App/SupportFiles/Info.plist" 2>/dev/null || true)
fi

if [ -z "$SPARKLE_VERSION" ]; then
    echo "警告: 无法从项目设置获取 CURRENT_PROJECT_VERSION，回退到日期生成方案..."
    SPARKLE_VERSION=$(date +"%Y%m%d%H")
fi

echo "提取到的 Build 号 (sparkle:version): $SPARKLE_VERSION"

# 3. 生成签名与获取大小
echo "正在为可用架构生成 EdDSA 签名..."
SIG_ARM64=$($SIGN_TOOL "$ZIP_ARM64")
SIG_X86_64=""
if [ "$HAS_X86" -eq 1 ]; then
    SIG_X86_64=$($SIGN_TOOL "$ZIP_X86_64")
fi

if [ -z "$SIG_ARM64" ] || { [ "$HAS_X86" -eq 1 ] && [ -z "$SIG_X86_64" ]; }; then
    echo "错误: 签名生成失败，请确保 Sparkle 私钥已配置。"
    exit 1
fi

# 4. 严格签名强校验
echo "正在从项目设置中提取 SUPublicEDKey 公钥..."
PUBLIC_KEY=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$PROJECT_DIR/App/SupportFiles/Info.plist" 2>/dev/null || true)
if [ -z "$PUBLIC_KEY" ]; then
    echo "错误: 无法从 $PROJECT_DIR/App/SupportFiles/Info.plist 中提取 SUPublicEDKey。"
    exit 1
fi
echo "项目内置公钥: $PUBLIC_KEY"

ED_SIG_ARM64=$(echo "$SIG_ARM64" | sed -E 's/.*sparkle:edSignature="([^"]+)".*/\1/')
verify_signature "$ZIP_ARM64" "$ED_SIG_ARM64" "$PUBLIC_KEY" "arm64"

if [ "$HAS_X86" -eq 1 ]; then
    ED_SIG_X86_64=$(echo "$SIG_X86_64" | sed -E 's/.*sparkle:edSignature="([^"]+)".*/\1/')
    verify_signature "$ZIP_X86_64" "$ED_SIG_X86_64" "$PUBLIC_KEY" "x86_64"
fi

SIZE_ARM64=$(stat -f%z "$ZIP_ARM64")
SIZE_X86_64=0
if [ "$HAS_X86" -eq 1 ]; then
    SIZE_X86_64=$(stat -f%z "$ZIP_X86_64")
fi
PUB_DATE=$(date -R)

echo "arm64 签名: $SIG_ARM64, 大小: $SIZE_ARM64"
if [ "$HAS_X86" -eq 1 ]; then
    echo "x86_64 签名: $SIG_X86_64, 大小: $SIZE_X86_64"
fi
echo "发布日期: $PUB_DATE"

URL_ARM64="https://github.com/ShawnRn/mac-mouse-fix/releases/download/v$VERSION/Mac_Mouse_Fix_${VERSION}_arm64.zip"
URL_X86_64="https://github.com/ShawnRn/mac-mouse-fix/releases/download/v$VERSION/Mac_Mouse_Fix_${VERSION}_x86_64.zip"

# 5. 更新 appcast.xml (单 item 多 enclosure)
echo "正在更新 appcast.xml..."

cat <<EOF > "$APPCAST_FILE"
<?xml version="1.0" encoding="utf-8"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>Mac Mouse Fix</title>
        <item>
            <title>$VERSION</title>
            <pubDate>$PUB_DATE</pubDate>
            <sparkle:version>${SPARKLE_VERSION//./}</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>10.15</sparkle:minimumSystemVersion>
            <enclosure url="$URL_ARM64" type="application/octet-stream" sparkle:os="macos" sparkle:nativeArchitecture="arm64" $SIG_ARM64/>
EOF

if [ "$HAS_X86" -eq 1 ]; then
    cat <<EOF >> "$APPCAST_FILE"
            <enclosure url="$URL_X86_64" type="application/octet-stream" sparkle:os="macos" sparkle:nativeArchitecture="x86_64" $SIG_X86_64/>
EOF
fi

cat <<EOF >> "$APPCAST_FILE"
        </item>
    </channel>
</rss>
EOF

# 6. 完成提示
echo "--- 准备完成！ ---"
echo "appcast.xml 已更新。"
echo "请执行:"
if [ "$HAS_X86" -eq 1 ]; then
    echo "gh release create \"v\$VERSION\" \"$DMG_ARM64\" \"$ZIP_ARM64\" \"$DMG_X86_64\" \"$ZIP_X86_64\" --title \"Mac Mouse Fix \$VERSION\" --notes \"Sparkle Update Release\""
else
    echo "gh release create \"v\$VERSION\" \"$DMG_ARM64\" \"$ZIP_ARM64\" --title \"Mac Mouse Fix \$VERSION\" --notes \"Sparkle Update Release\""
fi
