.PHONY: build run debug release clean help

# 默认目标
help:
	@echo "🎹 Mac Piano - 构建命令"
	@echo ""
	@echo "可用的命令:"
	@echo "  make build       - 编译调试版本"
	@echo "  make run         - 编译并运行应用"
	@echo "  make debug       - 使用LLDB调试"
	@echo "  make release     - 编译发布版本（优化）"
	@echo "  make clean       - 清理构建文件"
	@echo "  make help        - 显示此帮助信息"

# 编译调试版本
build:
	@echo "📦 编译调试版本..."
	swift build
	@echo "✅ 编译完成！"

# 编译并运行
run: build
	@echo "🎵 启动应用..."
	./.build/debug/MacPiano

# 调试模式
debug: build
	@echo "🐛 启动调试器..."
	lldb ./.build/debug/MacPiano

# 编译发布版本
release:
	@echo "📦 编译发布版本..."
	swift build -c release
	@echo "✅ 编译完成！"
	@echo "可执行文件: ./.build/release/MacPiano"

# 清理
clean:
	@echo "🧹 清理构建文件..."
	rm -rf .build/
	@echo "✅ 清理完成！"

# 执行脚本
build-script:
	@bash build.sh

run-script:
	@bash run.sh
