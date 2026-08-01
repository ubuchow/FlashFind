<p align="center">
  <img src="docs/images/hero.png" width="820" alt="FlashFind">
</p>

<h1 align="center">FlashFind</h1>

<p align="center">
  <strong>⚡ Find Anything. Instantly.</strong><br>
  <strong>⚡ 找到任何文件，就在瞬间。</strong>
</p>

<p align="center">
  A lightweight native file search utility for macOS,<br>
  inspired by the speed and simplicity of Everything.
</p>

<p align="center">
  一款轻量、原生的 macOS 文件搜索工具，<br>
  灵感来自 Everything 的速度与简洁体验。
</p>

<p align="center">
  <a href="https://github.com/ubuchow/FlashFind/stargazers"><img src="https://img.shields.io/github/stars/ubuchow/FlashFind?style=flat&label=Stars" alt="Stars"></a>
  <a href="https://github.com/ubuchow/FlashFind/issues"><img src="https://img.shields.io/github/issues/ubuchow/FlashFind?label=Issues" alt="Issues"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/ubuchow/FlashFind?label=License&color=8E8E93" alt="License"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-black?logo=apple" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/version-1.2.0-0A84FF" alt="Version 1.2.0">
</p>

---

## What is FlashFind? / 这是什么

FlashFind is a **native macOS menu bar app** for fast file lookup. It stays in the background, opens with a global shortcut, and searches an **in-memory filename index** as you type. When you need it, you can also search **inside documents** via macOS Spotlight.

FlashFind 是一款 **macOS 菜单栏原生应用**，用于快速找文件。它常驻后台，用全局快捷键唤起，基于 **内存文件名索引** 实现输入即搜；需要时还可调用 **系统 Spotlight** 搜索文档正文。

- Pure Swift / AppKit — **not** Electron  
- 纯 Swift / AppKit，**不是** Electron  
- Menu bar only (`LSUIElement`) — no Dock icon  
- 菜单栏常驻，不占用 Dock  
- Complements Finder & Spotlight; does not replace them  
- 补充 Finder / Spotlight，而非取代  

---

## Screenshot / 界面截图

![FlashFind main window](docs/images/main-window.png)

> Search your Mac without interrupting your workflow.  
> 无需打断当前工作，即可快速搜索文件。

---

## Why FlashFind / 为什么需要它

| | Finder | Spotlight | FlashFind |
|--|--------|-----------|-----------|
| File browsing / 浏览管理 | Excellent / 强 | Limited / 弱 | Basic / 基础 |
| Fast filename search / 文件名速搜 | Good / 一般 | Good / 一般 | **Core focus / 核心** |
| Content search / 正文 | — | Native / 原生 | Optional via Spotlight / 可选 |
| Menu bar / 菜单栏 | No | No | **Yes** |
| Custom global hotkey / 自定义快捷键 | Limited | System | **Yes** |
| Open source / 开源 | No | No | **MIT** |

Finder is great for browsing. Spotlight is great for system-wide discovery. FlashFind is for the moment you roughly remember a **filename** and want it open in one shortcut.

Finder 适合管理文件，Spotlight 适合系统级检索；FlashFind 面向「大致记得文件名、只想马上打开」的场景。

---

## Features / 功能（与当前代码一致）

### Filename search / 文件名搜索

- In-memory index + multi-core matching  
  内存索引 + 多核匹配  
- Search-as-you-type (no Enter)  
  输入即搜，无需回车  
- Footer shows hit count and elapsed time (ms)  
  底部显示结果数与耗时（毫秒）  
- Typical usage aims for millisecond-level filename results  
  日常使用下，文件名搜索通常可达毫秒级  

### Optional content search / 可选正文搜索

Toolbar dropdown / 工具栏下拉：

| Option | 说明 |
|--------|------|
| **仅搜文件名** / Filename only | Memory index only · 仅内存索引（默认） |
| **可根据正文内容搜索** / Search in file contents | Memory index + Spotlight (`mdfind`) · 文件名 + 正文 |

When content mode is on / 开启正文模式后：

1. Filename hits appear first · 先返回文件名结果  
2. Spotlight content search continues · 后台继续搜正文  
3. Results merge; badges show **文件名 / 正文 / 文件名+正文** · 合并并标记来源  
4. Spinner + footer text while searching · 搜索框转圈 + 底部「正在搜索正文…」  
5. First enable shows a notice that it may be slower · 首次开启弹窗提示可能稍慢  

Content search depends on Spotlight indexing. Unindexed files will not appear as content hits.

正文搜索依赖系统 Spotlight 索引；未被索引的文件不会作为正文命中出现。

### Filters & sort / 筛选与排序

**Sidebar categories / 侧边栏分类（带数量）**

全部结果 · 文件 · 文件夹 · 应用 · 其他  

**Locations / 位置**

全部位置 · Macintosh HD · 桌面 · 文档 · 下载 · 影片 · 音乐 · 图片 · 用户应用 · 系统应用 · 添加位置…  

**Type filter / 类型**

文件夹 · 应用 · PDF · 图片 · 文档 · 表格 · 演示 · 视频 · 音频 · 压缩包 · 代码  

**Modified / 修改时间**

今天 · 近 7 天 · 近 30 天 · 近一年  

**Size / 大小**

&lt; 1 MB · 1–10 MB · 10–100 MB · &gt; 100 MB  

**Sort / 排序**

相关性 · 名称 A→Z / Z→A · 类型 · 大小 大→小 / 小→大 · 添加时间 新→旧 / 旧→新 · 修改时间 新→旧 / 旧→新 · 路径  

### Results & actions / 结果与操作

- List / grid view · 列表 / 网格  
- Icon, name, path, size, modified date · 图标、名称、路径、大小、修改时间  
- Return open · ⌘Return reveal in Finder · Esc close  
- 回车打开 · ⌘回车访达 · Esc 关闭  
- Right-click: Open / Reveal / Copy path · 右键：打开 / 访达 / 复制路径  
- ⌘C copies selected path · ⌘C 复制选中路径  
- Result list is capped (default **200** hits per query)  
  单次结果默认最多 **200** 条  

### Index / 索引

**Default roots / 默认索引目录**

`Desktop` · `Documents` · `Downloads` · `Movies` · `Music` · `Pictures` · `~/Applications` · `/Applications`  

- Add custom folders · 可添加自定义文件夹  
- FSEvents + background refresh · FSEvents 与后台刷新  
- Disk cache under `~/Library/Application Support/FlashFind/` · 磁盘缓存加速下次启动  
- Manual rebuild in Settings / menu · 设置或菜单可「重建索引」  
- Skips noise dirs: `.git`, `node_modules`, Caches, etc. · 跳过噪音目录  
- Does **not** deep-scan the entire disk by default · **默认不**整盘深度扫描  

### Menu bar / 菜单栏

| Action | Behavior | 行为 |
|--------|----------|------|
| Left-click | Toggle search window | 打开 / 关闭搜索窗 |
| Right-click | App menu | 打开菜单 |
| Menu items | Open search · Settings · Rebuild index · About · Quit | 打开搜索 · 设置 · 重建索引 · 关于 · 退出 |

### Settings / 设置

- Language: 中文 / English · 语言  
- Appearance: System / Light / Dark · 跟随系统 / 浅色 / 深色  
- Global hotkey (must include a modifier) · 全局快捷键（需含修饰键）  
- Launch at login · 登录时启动  
- Content search toggle (synced with main window) · 正文搜索开关（与主界面同步）  
- Rebuild index · 立即重建索引  

### UI / 界面

Borderless floating panel, rounded corners, light fade animation, traffic-light close/minimize, hotkey badge, bilingual UI.

无边框浮层、圆角、轻量淡入淡出、关闭/最小化、快捷键徽章、中英界面。

---

## Requirements / 环境要求

| | |
|--|--|
| macOS | **13.0+** (`LSMinimumSystemVersion` / Package platform) |
| Swift | **5.9+** (`swift-tools-version: 5.9`) |
| Tools | Xcode Command Line Tools or Xcode（用于 `swift build`） |

---

## Installation / 安装

> **Current distribution is source-based.** There is no Homebrew cask yet, and GitHub Releases may not ship prebuilt binaries.  
> **当前以源码安装为主。** 尚无 Homebrew Cask；GitHub Releases 可能暂无预编译包。

### Install from source (recommended) / 从源码安装（推荐）

```bash
git clone https://github.com/ubuchow/FlashFind.git
cd FlashFind
./scripts/install.sh
```

What `install.sh` actually does / 脚本实际会做：

1. Run `scripts/build.sh` → `swift build -c release`  
2. Package `dist/FlashFind.app` (binary + `Info.plist` + generated icon)  
3. Install to **`~/Applications/FlashFind.app`**  
4. Register LaunchAgent `com.local.FlashFind` with **RunAtLoad** (login launch)  
5. Start FlashFind if it is not already running  
6. Ad-hoc codesign (`codesign --sign -`) when available — **not** Apple notarized  

安装路径 / Install path:

```text
~/Applications/FlashFind.app
```

### Build only / 仅构建

```bash
./scripts/build.sh
# → dist/FlashFind.app
```

### Uninstall / 卸载

```bash
./scripts/uninstall.sh
```

This stops the app, removes the LaunchAgent, deletes `~/Applications/FlashFind.app`, and removes `~/Library/Application Support/FlashFind`.

会结束进程、移除 LaunchAgent、删除应用与本地索引缓存目录。

### Homebrew / Homebrew（未提供）

```bash
# Planned — not available yet
# 计划中，目前不可用
# brew install --cask flashfind
```

### First launch / 首次启动

1. A menu bar icon appears · 菜单栏出现图标  
2. Index builds for default folders (footer: 索引中… / 索引 N 项) · 默认目录建索引  
3. Press **⌃⌥Space** to open search · 默认快捷键唤起  
4. macOS may ask for folder access for protected locations · 受保护目录可能弹出权限  
5. Content search needs Spotlight; incomplete indexes ⇒ incomplete content hits · 正文依赖 Spotlight  

**Privacy / 隐私：** Search runs **locally**. Filenames and document content are **not** uploaded to a remote server.  
搜索在**本机**完成，**不会**上传文件名或正文到远程服务器。

---

## Usage / 使用

1. Launch FlashFind (or log in if LaunchAgent is enabled) · 启动应用  
2. Click the menu bar icon or press **⌃⌥Space** · 点菜单栏或按快捷键  
3. Type a keyword · 输入关键词  
4. **↑ / ↓** select · **Return** open · **⌘Return** Finder · **Esc** close  
5. Switch dropdown to **可根据正文内容搜索** when needed · 需要时切换正文搜索  
6. Use sidebar + filters to narrow results · 用侧边栏与筛选缩小范围  

---

## Keyboard shortcuts / 快捷键

| Shortcut | Action | 操作 |
|----------|--------|------|
| **⌃⌥Space** | Show / hide (default, configurable) | 唤起 / 关闭（默认，可改） |
| **↑** / **↓** | Move selection | 上下选择 |
| **Return** | Open | 打开 |
| **⌘Return** | Reveal in Finder | 在访达中显示 |
| **⌘C** | Copy path | 复制路径 |
| **Esc** | Close window | 关闭窗口 |

---

## Project layout / 项目结构

```text
FlashFind/
├── Package.swift                 # SPM · macOS 13+ · Swift 5.9
├── Sources/FlashFind/            # App sources
│   ├── IndexEngine.swift         # Filename index + search
│   ├── ContentSearch.swift       # Spotlight / mdfind
│   ├── FSWatcher.swift           # FSEvents
│   ├── SearchWindowController.swift
│   ├── SettingsWindowController.swift
│   ├── HotKey.swift
│   ├── AppPrefs.swift
│   └── …
├── Resources/Info.plist          # v1.2.0 · LSUIElement
├── scripts/
│   ├── build.sh                  # release → dist/FlashFind.app
│   ├── install.sh                # build + install + LaunchAgent
│   ├── uninstall.sh
│   └── generate_app_icon.swift
├── docs/images/                  # screenshots
└── LICENSE                       # MIT
```

No Xcode project is required; packaging is done by shell scripts around the SPM executable.

无需 `.xcodeproj`；通过脚本将 SPM 可执行文件打成 `.app`。

---

## Development / 开发

```bash
git clone https://github.com/ubuchow/FlashFind.git
cd FlashFind
swift build                  # debug
./scripts/build.sh           # release .app
./scripts/install.sh         # install + launch
```

Issues and PRs welcome. · 欢迎 Issue 与 PR。

---

## Known limitations / 已知限制

| Topic | Reality | 实际情况 |
|-------|---------|----------|
| Prebuilt installers | Source install is the supported path | 以源码安装为主 |
| Code signing | Ad-hoc only in `install.sh` | 仅 ad-hoc 签名，未公证 |
| Content search | Depends on Spotlight | 依赖 Spotlight 索引质量 |
| Result cap | ~200 per query | 单次约 200 条 |
| Whole-disk index | Not default | 默认不整盘深扫 |

---

## License / 许可

[MIT](LICENSE) © 2026 [ubuchow](https://github.com/ubuchow)

Inspired by [Everything](https://www.voidtools.com/) on Windows — rebuilt as a native macOS menu bar tool.

灵感来自 Windows 上的 Everything，以原生 macOS 菜单栏形态实现。

---

<p align="center">
  <sub>FlashFind · Find Anything. Instantly. · 找到任何文件，就在瞬间。</sub>
</p>
