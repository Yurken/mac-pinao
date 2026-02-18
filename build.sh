#!/bin/bash

# Mac Piano - 构建脚本
# 此脚本将编译Swift项目并生成可执行文件

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"

echo "🎹 Mac Piano - 开始构建..."

# 清理之前的构建
echo "清理之前的构建..."
rm -rf "$BUILD_DIR"

# 构建项目
echo "编译Swift项目..."
cd "$PROJECT_DIR"
swift build -c release

# 获取可执行文件路径
EXECUTABLE="$BUILD_DIR/release/MacPiano"

if [ -f "$EXECUTABLE" ]; then
    echo "✅ 构建成功！"
    echo "可执行文件位于: $EXECUTABLE"
    echo ""
    echo "运行应用:"
    echo "  $EXECUTABLE"
else
    echo "❌ 构建失败"
    exit 1
fi
