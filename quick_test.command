#!/bin/bash
# NetSignal 一键测试：关闭旧版本 → 编译 → 替换 → 启动

# 脚本所在目录（双击 .command 时用绝对路径）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

APP_NAME="NetSignal"
APP_PATH="/Applications/${APP_NAME}.app"
BUILD_DIR="${SCRIPT_DIR}/.build/release"

echo "=== NetSignal 快速测试 ==="
echo ""

# 1. 关闭旧版本
echo "[1/3] 关闭旧版本..."
if killall "${APP_NAME}" 2>/dev/null; then
    echo "  ✓ 已关闭"
    sleep 1
else
    echo "  - 未在运行"
fi

# 2. 编译
echo "[2/3] 编译..."
cd "${SCRIPT_DIR}"
if swift build --disable-sandbox -c release 2>&1 | tail -1; then
    echo "  ✓ 编译完成"
else
    echo "  ✗ 编译失败，请检查代码"
    echo ""
    read -p "按回车键退出..."
    exit 1
fi

# 3. 替换到 /Applications
echo "[3/3] 安装并启动..."
rm -rf "${APP_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS"
mkdir -p "${APP_PATH}/Contents/Resources"

if ! cp "${BUILD_DIR}/${APP_NAME}" "${APP_PATH}/Contents/MacOS/${APP_NAME}"; then
    echo "  ✗ 复制失败，未找到编译产物"
    read -p "按回车键退出..."
    exit 1
fi

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
if [ ! -f "${APP_PATH}/Contents/Resources/AppIcon.icns" ] || [ ! -f "${APP_PATH}/Contents/Resources/AppIcon.png" ]; then
    python3 "${SCRIPT_DIR}/generate_icon.py" 2>/dev/null
    cp "${SCRIPT_DIR}/Resources/AppIcon.icns" "${APP_PATH}/Contents/Resources/" 2>/dev/null
    cp "${SCRIPT_DIR}/Resources/AppIcon.png" "${APP_PATH}/Contents/Resources/" 2>/dev/null
fi

# 启动
open "${APP_PATH}"
echo "  ✓ 启动完成"
echo ""
echo "测试完毕后，关闭终端窗口即可。"
sleep 3
