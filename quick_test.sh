#!/bin/bash
# 一键测试脚本：关闭旧版本 → 替换 → 重启
set -e

APP_NAME="NetSignal"
APP_PATH="/Applications/${APP_NAME}.app"
BUILD_DIR="$(cd "$(dirname "$0")" && pwd)/.build/release"

echo "=== NetSignal 快速测试 ==="

# 1. 关闭旧版本
echo "[1/3] 关闭旧版本..."
killall "${APP_NAME}" 2>/dev/null && echo "  已关闭" || echo "  未在运行"

# 2. 编译
echo "[2/3] 编译..."
cd "$(dirname "$0")"
swift build --disable-sandbox -c release 2>&1 | tail -1

# 3. 替换到 /Applications 并启动
echo "[3/3] 安装并启动..."
rm -rf "${APP_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS"
mkdir -p "${APP_PATH}/Contents/Resources"
cp "${BUILD_DIR}/${APP_NAME}" "${APP_PATH}/Contents/MacOS/${APP_NAME}"

# 生成 Info.plist
VERSION="1.0.0"
cat > "${APP_PATH}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.netsignal.app</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# 生成图标（如果不存在）
if [ ! -f "${APP_PATH}/Contents/Resources/AppIcon.icns" ]; then
    python3 "$(dirname "$0")/generate_icon.py" "${APP_PATH}/Contents/Resources/AppIcon.icns" 2>/dev/null
fi

# 启动
open "${APP_PATH}"
echo "✅ 启动完成"
