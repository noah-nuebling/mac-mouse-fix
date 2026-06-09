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

# 1. 配置路径
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$PROJECT_DIR/releases"
APPCAST_FILE="$PROJECT_DIR/appcast.xml"
DMG_ARM64="$RELEASE_DIR/Mac_Mouse_Fix_${VERSION}_arm64.dmg"
DMG_X86_64="$RELEASE_DIR/Mac_Mouse_Fix_${VERSION}_x86_64.dmg"

# 定位签名工具。允许通过环境变量覆盖，默认从当前 DerivedData 中查找。
SIGN_TOOL="${SIGN_TOOL:-}"
if [ -z "$SIGN_TOOL" ]; then
    SIGN_TOOL=$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update" -type f 2>/dev/null | head -n 1 || true)
fi
if [ -z "$SIGN_TOOL" ] || [ ! -x "$SIGN_TOOL" ]; then
    echo "错误: 找不到 Sparkle sign_update。请先构建项目或设置 SIGN_TOOL=/path/to/sign_update"
    exit 1
fi

# 检查 DMG 是否存在
if [ ! -f "$DMG_ARM64" ]; then
    echo "错误: 找不到 arm64 DMG 文件：$DMG_ARM64"
    exit 1
fi

HAS_X86=0
if [ -f "$DMG_X86_64" ]; then
    HAS_X86=1
fi

echo "--- 开始为版本 $VERSION 准备发布 ---"

# 2. 从项目设置中获取当前的 Build 号 (sparkle:version)
echo "正在从项目设置中提取流水号 Build 号..."
SPARKLE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "/tmp/MacMouseFix_build/Mac Mouse Fix_arm64.app/Contents/Info.plist" 2>/dev/null || true)

if [ -z "$SPARKLE_VERSION" ]; then
    SPARKLE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PROJECT_DIR/App/SupportFiles/Info.plist" 2>/dev/null || true)
fi

if [ -z "$SPARKLE_VERSION" ]; then
    echo "警告: 无法从项目设置获取 CURRENT_PROJECT_VERSION，回退到日期生成方案..."
    SPARKLE_VERSION=$(date +"%Y%m%d%H")
fi

echo "提取到的 Build 号 (sparkle:version): $SPARKLE_VERSION"

# 3. 生成签名与获取大小
echo "正在为可用架构生成 EdDSA 签名..."
SIG_ARM64=$($SIGN_TOOL "$DMG_ARM64")
SIG_X86_64=""
if [ "$HAS_X86" -eq 1 ]; then
    SIG_X86_64=$($SIGN_TOOL "$DMG_X86_64")
fi

if [ -z "$SIG_ARM64" ] || { [ "$HAS_X86" -eq 1 ] && [ -z "$SIG_X86_64" ]; }; then
    echo "错误: 签名生成失败，请确保 Sparkle 私钥已配置。"
    exit 1
fi

SIZE_ARM64=$(stat -f%z "$DMG_ARM64")
SIZE_X86_64=0
if [ "$HAS_X86" -eq 1 ]; then
    SIZE_X86_64=$(stat -f%z "$DMG_X86_64")
fi
PUB_DATE=$(date -R)

echo "arm64 签名: $SIG_ARM64, 大小: $SIZE_ARM64"
if [ "$HAS_X86" -eq 1 ]; then
    echo "x86_64 签名: $SIG_X86_64, 大小: $SIZE_X86_64"
fi
echo "发布日期: $PUB_DATE"

URL_ARM64="https://github.com/ShawnRn/mac-mouse-fix/releases/download/v$VERSION/Mac_Mouse_Fix_${VERSION}_arm64.dmg"
URL_X86_64="https://github.com/ShawnRn/mac-mouse-fix/releases/download/v$VERSION/Mac_Mouse_Fix_${VERSION}_x86_64.dmg"

echo "arm64 签名: $SIG_ARM64, 大小: $SIZE_ARM64"
echo "x86_64 签名: $SIG_X86_64, 大小: $SIZE_X86_64"
echo "发布日期: $PUB_DATE"

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
    echo "gh release create \"v\$VERSION\" \"$DMG_ARM64\" \"$DMG_X86_64\" --title \"Mac Mouse Fix \$VERSION\" --notes \"Sparkle Update Release\""
else
    echo "gh release create \"v\$VERSION\" \"$DMG_ARM64\" --title \"Mac Mouse Fix \$VERSION\" --notes \"Sparkle Update Release\""
fi
