#!/bin/bash

# Mac Piano - 运行脚本
# 此脚本将直接运行开发版本的应用

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"

echo "🎹 Mac Piano - 启动应用..."

# 检查是否已构建
if [ ! -f "$BUILD_DIR/debug/MacPiano" ]; then
    echo "应用尚未构建，正在构建..."
    swift build -C "$PROJECT_DIR"
fi

EXECUTABLE="$BUILD_DIR/debug/MacPiano"

if [ -f "$EXECUTABLE" ]; then
    echo "✨ 启动 Mac Piano..."
    "$EXECUTABLE"
else
    echo "❌ 找不到可执行文件"
    exit 1
fi
