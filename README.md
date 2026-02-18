# 🎹 Mac Piano - macOS 键盘钢琴软件

一款专为 macOS 设计的轻量级键盘钢琴应用，使用 Swift 编写，支持使用电脑键盘演奏音乐。

![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
![Swift Version](https://img.shields.io/badge/swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ 功能特性

- 🎵 **实时音频合成** - 使用 AVFoundation 框架进行高质量正弦波合成
- ⌨️ **键盘映射** - 支持键盘上的多个音符同时演奏
- 🎨 **现代化UI** - 清晰的钢琴键盘显示，实时反馈按键状态
- 🔊 **多音符支持** - 可同时播放多个音符
- 🎼 **标准音阶** - 包含从 C3 到 C6 的完整钢琴音阶

## 📋 系统要求

- macOS 13.0 或更高版本
- Swift 5.9+
- 支持 M1/M2/Intel Mac

## 🚀 快速开始

### 编译项目

```bash
# 开发版本（调试模式）
swift build

# 发布版本（优化编译）
swift build -c release
```

### 运行应用

```bash
# 方法 1: 使用脚本运行
bash run.sh

# 方法 2: 直接运行可执行文件
./.build/debug/MacPiano

# 方法 3: 使用 Swift 包管理器
swift run MacPiano
```

### 使用固定采样音色（推荐）

```bash
# 下载钢琴采样（首次一次）
bash scripts/download_piano_samples.sh

# 重新编译并运行
swift build
./.build/debug/MacPiano
```

说明：
- 采样文件存放在 `Sources/MacPiano/Resources/Samples/acoustic_grand_piano/`
- 若采样缺失，程序会自动回退到合成音色

## 🎹 键盘映射

### 第一排 (C4 - B4, 八度4)
| 键 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| 音符 | do | re | mi | fa | so | la | si |

### 第二排 (C5 - B5, 八度5)
| 键 | q | w | e | r | t | y | u |
|---|---|---|---|---|---|---|---|
| 音符 | do | re | mi | fa | so | la | si |

### 第三排 (C3 - B3, 八度3)
| 键 | a | s | d | f | g | h | j |
|---|---|---|---|---|---|---|---|
| 音符 | do | re | mi | fa | so | la | si |

### 第四排 (C6 - B6, 八度6)
| 键 | z | x | c | v | b | n | m |
|---|---|---|---|---|---|---|---|
| 音符 | do | re | mi | fa | so | la | si |

## 🏗️ 项目结构

```
mac-pinao/
├── Sources/
│   └── MacPiano/
│       ├── main.swift              # 应用入口点
│       ├── AppDelegate.swift       # 应用委托，窗口和菜单管理
│       ├── AudioSynthesizer.swift  # 音频合成引擎
│       └── PianoKeyboardView.swift # 钢琴键盘UI视图
├── Package.swift                    # Swift 包管理配置
├── build.sh                        # 编译脚本
├── run.sh                          # 运行脚本
└── README.md                       # 此文件
```

## 📱 架构设计

### AudioSynthesizer
- 管理 AVAudioEngine 和音频缓冲区
- 优先播放本地采样音色（mp3）
- 采样缺失时回退正弦波生成
- 支持多音符同时播放
- 包含包络控制以避免点击声

### AppDelegate
- 创建窗口和主视图
- 安装应用级键盘事件监听
- 将按键事件路由到钢琴视图

### PianoKeyboardView
- 自定义 NSView 子类
- 绘制黑白键风格的钢琴 UI
- 支持 AutoPiano 风格键位映射
- 实时显示按键状态（高亮显示）

## 🎶 音频技术详解

### 频率生成
每个音符对应一个标准的音乐频率。例如：
- A4 (标准调音音符) = 440 Hz
- 相邻半音的频率比为 2^(1/12) ≈ 1.059

### 波形合成
使用正弦波函数生成声波：
```
y(t) = sin(2π × frequency × t)
```

### 包络控制
使用正弦包络避免点击声：
```
amplitude(t) = sin(π × progress) × 0.3
```

## 💡 使用技巧

1. **同时演奏多个音符** - 按下多个键盘按键可以同时发出多个音符
2. **快速弹奏** - 快速按下不同的键可以演奏简单的melody
3. **长音符** - 按住键盘按键，音符会持续约3秒钟

## 🔧 自定义

### 修改音符时长
编辑 `PianoKeyboardView.swift` 中的 `pressKey(id:)`：
```swift
audioSynthesizer.playNote(id: key.id, frequency: key.frequency, duration: 3.0)
```

### 调整音量
编辑 AudioSynthesizer.swift 中的包络控制：
```swift
channelData[0][frame] = amplitude * envelope * 0.3  // 改变 0.3 的值
```

### 添加新的键盘映射
在 `PianoKeyboardView.whiteBindings` 中添加新的键位绑定，并在 `buildKeys()` 中调整映射规则。

## 🐛 已知问题和限制

- 暂不支持 MIDI 输入
- 不提供录音功能
- 不支持自定义音色
- 最多支持同时播放约 10-15 个音符（受硬件性能限制）

## 🚀 未来计划

- [ ] MIDI 设备支持
- [ ] 音乐录制和播放功能
- [ ] 多种音色选择（钢琴、电子琴、吉他等）
- [ ] 歌曲库和练习模式
- [ ] 实时可视化频谱分析
- [ ] 键盘设置自定义
- [ ] 触控板支持

## 📝 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 👨‍💻 开发

### 依赖项
- macOS 13+ SDK
- Swift 5.9+

### 构建步骤

```bash
# 1. 克隆仓库
git clone https://github.com/yourusername/mac-pinao.git
cd mac-pinao

# 2. 编译项目
swift build

# 3. 运行应用
./.build/debug/MacPiano
```

### 调试
```bash
# 使用 lldb 调试
swift build
lldb ./.build/debug/MacPiano
```

## 🙏 鸣谢

- 使用 Swift 的 AVFoundation 框架进行音频处理
- 灵感来自 Web Audio API 和其他键盘钢琴应用

## 📧 反馈和支持

如有问题或建议，欢迎提交 Issue 或 Pull Request。

---

**制作时间**: 2026年2月18日  
**使用者**: Mac 用户  
**特点**: 轻量级、快速、易于使用
