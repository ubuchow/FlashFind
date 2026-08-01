<!--
  FlashFind README
  Maintainer notes:
  - Repo: https://github.com/ubuchow/FlashFind
  - Replace docs/images/* assets when screenshots / GIF are ready
  - Logo: docs/images/logo.png (optional; falls back to text header)
-->

<p align="center">
  <!-- Maintainer: add docs/images/logo.png (128×128+ recommended) -->
  <img src="docs/images/logo.png" width="128" alt="FlashFind Logo">
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
  <a href="https://github.com/ubuchow/FlashFind/releases"><img src="https://img.shields.io/github/v/release/ubuchow/FlashFind?display_name=tag&label=Download&color=0A84FF" alt="Download"></a>
  <a href="https://github.com/ubuchow/FlashFind/releases/latest"><img src="https://img.shields.io/github/v/release/ubuchow/FlashFind?label=Latest%20Release&color=30D158" alt="Latest Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/ubuchow/FlashFind?label=License&color=8E8E93" alt="License"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-black?logo=apple" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white" alt="Swift 5.9+">
  <a href="https://github.com/ubuchow/FlashFind/stargazers"><img src="https://img.shields.io/github/stars/ubuchow/FlashFind?style=flat&label=Stars" alt="Stars"></a>
  <a href="https://github.com/ubuchow/FlashFind/issues"><img src="https://img.shields.io/github/issues/ubuchow/FlashFind?label=Issues" alt="Issues"></a>
</p>

---

## Hero / 主界面

![FlashFind Hero](docs/images/hero.png)

> **Search your Mac without interrupting your workflow.**  
> **无需打断当前工作，即可快速搜索整台 Mac。**

---

## Demo / 演示

![FlashFind Demo](docs/images/demo.gif)

**What the demo should show / 演示应覆盖的流程：**

1. Press the global shortcut / 按下全局快捷键  
2. Search window appears / 搜索窗口弹出  
3. Type a keyword / 输入关键词  
4. Results update live / 结果实时出现  
5. Move with arrow keys / 方向键选择  
6. Enter to open / 回车打开  
7. ⌘Return to reveal in Finder / ⌘回车在访达中显示  
8. Switch to content search / 切换正文搜索  
9. Filename hits first / 先出现文件名结果  
10. Content matches merge in / 再合并正文命中  

> Place a short GIF or screen recording at `docs/images/demo.gif`.  
> 请将演示 GIF / 录屏放到 `docs/images/demo.gif`。

---

## Why FlashFind / 为什么需要 FlashFind

Finder is great for browsing. Spotlight is great for system-wide discovery. FlashFind is built for the moments when you already know roughly what a file is called and want to reach it immediately.

Finder 适合浏览和管理文件，Spotlight 适合系统级信息检索；FlashFind 则专注于另一种高频场景：你大致记得文件名，只想尽快找到并打开它。

FlashFind is not a shell around existing tools, and not an Electron app. It is a small native utility written in pure Swift: menu-bar resident, keyboard-first, designed for speed and focus.

FlashFind 不是现有工具的套壳，也不是 Electron 应用。它是纯 Swift 编写的小型原生工具：菜单栏常驻、键盘优先，为速度与专注而设计。

It complements Finder and Spotlight — it does not try to replace everything the system already does well.

它是 Finder 与 Spotlight 的补充，而不是盲目替代系统已有能力。

**Built for / 适合：** developers, designers, PMs, researchers, and anyone with a crowded Downloads folder.  
**面向：** 开发者、设计师、产品经理、研究人员，以及文件较多的日常用户。

---

## Key Features / 核心功能

### ⚡ In-memory Filename Search / 内存文件名搜索

| English | 中文 |
|---------|------|
| Builds an in-memory filename index | 建立内存文件名索引 |
| Multi-core matching | 多核并行匹配 |
| Search-as-you-type | 输入即搜索 |
| No Enter required | 无需按回车 |
| Result count + elapsed time (ms) | 显示结果数与耗时（毫秒） |
| Millisecond-level search in typical usage | 日常使用通常可达到毫秒级 |

### 🔎 Optional Content Search / 可选正文搜索

| English | 中文 |
|---------|------|
| Uses macOS Spotlight via `mdfind` | 通过 `mdfind` 调用系统 Spotlight |
| Matches text in Word, Excel, PDF and other indexed docs | 可匹配 Word / Excel / PDF 等已索引文档正文 |
| Notice when enabling (may be slower) | 开启时提示可能稍慢 |
| Spinner + footer status while searching | 搜索中显示转圈与底部状态 |
| Filename results first | 优先返回文件名结果 |
| Content hits merged afterward | 随后合并正文命中 |
| Labels: Filename / Content / Filename + Content | 标记：文件名 / 正文 / 文件名 + 正文 |

### ⌨️ Keyboard-first Workflow / 键盘优先

- Global hotkey to show / hide · 全局快捷键唤起或关闭  
- Live query · 实时输入  
- ↑ / ↓ to select · 方向键选择  
- Return to open · 回车打开  
- ⌘Return to show in Finder · ⌘回车在访达中显示  
- Esc to dismiss · Esc 关闭  
- Footer shortcut hints · 底部操作提示  
- Hotkey badge (current shortcut) · 右下角当前快捷键徽章  

### 🍎 Native macOS Experience / 原生 macOS 体验

- Pure Swift · 纯 Swift  
- Native AppKit · 原生 macOS 框架  
- Not Electron · 非 Electron  
- Borderless floating panel · 无边框浮层  
- Rounded corners & shadow · 圆角与阴影  
- Spotlight-like presentation · 类 Spotlight 风格  
- Light / Dark / System · 浅色 / 深色 / 跟随系统  
- Light fade in / out · 轻量淡入淡出  
- Menu bar agent (`LSUIElement`) · 菜单栏常驻，不占用 Dock  

### 📁 Flexible Search Locations / 灵活搜索范围

**Default indexed locations / 默认索引位置：**

Desktop · Documents · Downloads · Movies · Music · Pictures · `~/Applications` · `/Applications`

- Add custom folders · 可添加自定义文件夹  
- Filter by location · 可按位置筛选  
- Sidebar lists indexed roots · 侧边栏展示已索引位置  

> Whole-disk deep scan is not the default. `/` can appear as a location filter entry without walking the entire volume.  
> 默认不深度扫描整盘；`/` 可作为位置筛选入口，不会整盘遍历。

### 🔄 Live Index Updates / 实时索引更新

- FSEvents watches for changes · FSEvents 感知文件变化  
- Incremental / background refresh · 增量与后台刷新  
- Manual full rebuild · 支持手动重建索引  
- Index status in the footer · 底部显示索引状态  
- Smart skips: `.git`, `node_modules`, Caches, and similar noise · 智能跳过 `.git`、`node_modules`、Caches 等噪音目录  

### 🪶 Lightweight by Design / 为轻量而设计

- Menu bar agent — main window only when you need it · 菜单栏模式，不长期霸占主窗口  
- Filename search is the in-memory core · 文件名以内存查询为核心  
- No self-built full-text database · 正文不自建全文库  
- Spotlight only when content mode is on · 仅在正文模式调用系统能力  
- Small, focused product surface · 小而专注的产品理念  

---

## Search Modes / 搜索模式

| Mode | How it works | Best for |
|------|----------------|----------|
| **Filename only** | In-memory index + multi-core matching | Fast everyday search |
| **Search in file contents** | Filename index + macOS Spotlight | Finding text inside documents |

| 模式 | 工作方式 | 适用场景 |
|------|----------|----------|
| **仅搜文件名** | 内存索引与多核匹配 | 日常快速定位文件 |
| **可根据正文内容搜索** | 文件名索引 + 系统 Spotlight | 查找文档内部文字 |

**Two-phase content search / 正文两阶段逻辑：**

1. Filename results return immediately · 文件名结果立即返回  
2. Content search runs via Spotlight · 正文搜索在后台继续  
3. Results merge and de-duplicate · 结束后合并去重  
4. Each hit is labeled by source · 明确标记命中来源  

---

## Filters and Sorting / 筛选与排序

### Sidebar categories / 侧边栏分类

| English | 中文 |
|---------|------|
| All Results | 全部结果 |
| Files | 文件 |
| Folders | 文件夹 |
| Applications | 应用 |
| Other | 其他 |

Each category shows a count. · 每个分类显示数量。

### Search locations / 搜索位置

| English | 中文 |
|---------|------|
| All Locations | 全部位置 |
| Desktop | 桌面 |
| Documents | 文档 |
| Downloads | 下载 |
| Other indexed locations | 其他已索引位置 |

### Filters / 筛选

**Type / 类型**

Folder · Application · PDF · Image · Document · Spreadsheet · Presentation · Video · Audio · Archive · Code  

文件夹 · 应用 · PDF · 图片 · 文档 · 表格 · 演示 · 视频 · 音频 · 压缩包 · 代码  

**Date modified / 修改时间**

Today · Last 7 days · Last 30 days · Last year  

今天 · 近 7 天 · 近 30 天 · 近一年  

**Size / 大小**

Under 1 MB · 1–10 MB · 10–100 MB · Over 100 MB  

小于 1 MB · 1–10 MB · 10–100 MB · 大于 100 MB  

**Location / 位置** — same as indexed sidebar locations · 与侧边栏索引位置一致  

### Sorting / 排序

| English | 中文 |
|---------|------|
| Relevance | 相关性 |
| Name A→Z | 名称 A→Z |
| Name Z→A | 名称 Z→A |
| Type | 类型 |
| Size (largest first) | 大小 大→小 |
| Size (smallest first) | 大小 小→大 |
| Date added | 添加时间 |
| Date modified | 修改时间 |
| Path | 路径 |

---

## Result Views and Actions / 结果展示与操作

### Result information / 结果信息

List rows show · 列表展示：

- File icon · 文件图标  
- Name · 名称  
- Full path · 完整路径  
- Size · 大小  
- Modified date · 修改时间  
- Match source · 命中来源（文件名 / 正文 / 文件名 + 正文）  

### View modes / 展示方式

- **List view** · 列表视图  
- **Grid view** · 网格视图  

### Actions / 操作

| Action | English | 中文 |
|--------|---------|------|
| Open | Return / double-click / context menu | 回车 / 双击 / 右键打开 |
| Reveal in Finder | ⌘Return / context menu | ⌘回车 / 右键在访达中显示 |
| Open containing folder | Context menu | 右键打开所在文件夹 |
| Copy path | Context menu | 复制路径 |
| Navigate | ↑ / ↓ | 上下选择 |
| Close | Esc | 关闭窗口 |

---

## Menu Bar Experience / 菜单栏体验

| Feature | Description |
|---------|-------------|
| Menu bar resident | Left-click toggles the search window |
| Context menu | Right-click opens the app menu |
| Global shortcut | Default **⌃⌥Space** (customizable) |
| Launch at Login | Optional automatic startup |
| Rebuild Index | Available from the menu / settings |
| Settings | Opens preferences |
| About | Project information |
| Quit | Exits FlashFind |

| 功能 | 说明 |
|------|------|
| 菜单栏常驻 | 左键打开或关闭搜索窗口 |
| 右键菜单 | 右键打开应用菜单 |
| 全局快捷键 | 默认 **⌃⌥Space**（可改） |
| 登录启动 | 可选自动启动 |
| 重建索引 | 菜单 / 设置中可用 |
| 设置 | 打开偏好设置 |
| 关于 | 显示项目信息 |
| 退出 | 退出 FlashFind |

---

## Screenshots / 截图

> Paths below are placeholders. Add assets under `docs/images/` when ready.  
> 以下为预留路径，截图就绪后放入 `docs/images/`。

### Main Search Window / 主搜索窗口

![Main Window](docs/images/main-window.png)

### Dark Mode / 深色模式

![Dark Mode](docs/images/dark-mode.png)

### Content Search / 正文搜索

![Content Search](docs/images/content-search.png)

### Filters / 筛选功能

![Filters](docs/images/filters.png)

### Settings / 设置

![Settings](docs/images/settings.png)

### Menu Bar / 菜单栏

![Menu Bar](docs/images/menu-bar.png)

---

## Comparison / 对比

FlashFind is a **complement**, not a universal replacement.

FlashFind 是**补充工具**，不是全能替代品。

| Feature | Finder | Spotlight | FlashFind |
|---------|--------|-----------|-----------|
| File browsing | Excellent | Limited | Basic |
| Fast filename search | Good | Good | **Core focus** |
| Content search | Search UI | Native | Optional Spotlight |
| Menu bar access | No | No | **Yes** |
| Custom global shortcut | Limited | System | **Yes** |
| In-memory filename index | No | System-managed | **Yes** |
| Keyboard-first workflow | Partial | Yes | **Yes** |
| Visual file filters | Yes | Query-based | **Yes** |
| Open source | No | No | **Yes (MIT)** |
| Native macOS UI | Yes | Yes | Yes |

| 能力 | Finder | Spotlight | FlashFind |
|------|--------|-----------|-----------|
| 文件浏览管理 | 优秀 | 有限 | 基础 |
| 快速文件名搜索 | 良好 | 良好 | **核心重点** |
| 正文搜索 | 搜索界面 | 系统原生 | 可选调用 Spotlight |
| 菜单栏入口 | 无 | 无 | **有** |
| 自定义全局快捷键 | 有限 | 系统级 | **有** |
| 内存文件名索引 | 无 | 系统管理 | **有** |
| 键盘优先 | 部分 | 是 | **是** |
| 可视化筛选 | 是 | 查询式 | **是** |
| 开源 | 否 | 否 | **是（MIT）** |
| 原生界面 | 是 | 是 | 是 |

- **Finder** — best for managing files · 更适合管理文件  
- **Spotlight** — best for system-wide discovery · 更适合系统级检索  
- **FlashFind** — best for menu-bar, filename-first, keyboard-driven lookup · 更专注菜单栏、文件名与快捷操作  

---

## Installation / 安装

### Option 1: Download Release / 下载正式版本

Download the latest build from the [Releases](https://github.com/ubuchow/FlashFind/releases) page.

从 [Releases](https://github.com/ubuchow/FlashFind/releases) 页面下载最新版本。

### Option 2: Homebrew / Homebrew（计划中）

```bash
# Planned / 计划支持
brew install --cask flashfind
```

Homebrew installation is **planned** and is **not available** until the cask is published.

Homebrew 安装方式仍在计划中，**只有在 Cask 正式发布后才能使用**。

### Option 3: Build from Source / 从源码构建

**Requirements / 环境要求（已核实）：**

| Item | Value |
|------|--------|
| macOS | **13.0+** |
| Swift | **5.9+** (`swift-tools-version: 5.9`) |
| Xcode / CLT | Command Line Tools or Xcode (for `swift build`) |

```bash
git clone https://github.com/ubuchow/FlashFind.git
cd FlashFind
./scripts/install.sh
```

This compiles a release binary, packages `FlashFind.app`, and installs it to:

上述脚本会编译 release 版本、打包 `FlashFind.app`，并安装到：

```text
~/Applications/FlashFind.app
```

Build only (no install) / 仅构建不安装：

```bash
./scripts/build.sh
# → dist/FlashFind.app
```

Uninstall / 卸载：

```bash
./scripts/uninstall.sh
```

---

## First Launch and Permissions / 首次启动与权限

- On first launch, FlashFind builds a filename index for the default locations.  
  首次启动会为默认目录建立文件名索引。  
- Accessing protected folders may trigger macOS privacy prompts — grant access if you want those folders indexed.  
  访问受保护文件夹时，系统可能弹出权限请求；如需索引请允许。  
- Content search depends on **Spotlight**. Incomplete Spotlight indexes mean incomplete content hits.  
  正文搜索依赖 **Spotlight**；系统索引未完成时，正文结果可能不完整。  
- Indexing status appears in the footer (`Indexing…` / `Indexed N items`).  
  底部会显示索引状态（「索引中…」/「索引 N 项」）。  

**Privacy / 隐私**

FlashFind performs search **locally on your Mac**. It does not upload filenames or document content to a remote server.

FlashFind 的搜索过程在**本机完成**，不会将文件名或文档内容上传到远程服务器。

---

## Usage / 使用

1. Launch FlashFind · 启动 FlashFind  
2. Find the menu bar icon · 在菜单栏看到图标  
3. Press **⌃⌥Space** (or your custom hotkey) · 按 **⌃⌥Space**（或自定义快捷键）  
4. Type a filename keyword · 输入文件名关键词  
5. Use **↑ / ↓** to select · 用方向键选择  
6. Press **Return** to open · 回车打开  
7. Press **⌘Return** to reveal in Finder · ⌘回车在访达中显示  
8. Switch to **Search in file contents** when you need body text · 需要时切换「可根据正文内容搜索」  
9. Narrow with filters and sort · 用筛选与排序缩小结果  

---

## Keyboard Shortcuts / 快捷键

| Shortcut | Action | 操作 |
|----------|--------|------|
| **⌃⌥Space** | Show / hide FlashFind | 唤起 / 关闭 |
| **↑** / **↓** | Move selection | 上下选择 |
| **Return** | Open selected item | 打开选中项 |
| **⌘Return** | Reveal in Finder | 在访达中显示 |
| **Esc** | Close window | 关闭窗口 |
| **⌘C** | Copy path (when focused on results) | 复制路径（结果聚焦时） |

The global hotkey is configurable in **Settings**. It must include at least one modifier (⌘ / ⌥ / ⌃ / ⇧).

全局快捷键可在**设置**中修改，且必须包含至少一个修饰键。

---

## Settings / 设置

| Setting | English | 中文 |
|---------|---------|------|
| Language | Chinese / English | 中文 / English |
| Appearance | System / Light / Dark | 跟随系统 / 浅色 / 深色 |
| Hotkey | Record a custom shortcut | 录制自定义快捷键 |
| Launch at Login | LaunchAgent-based | 登录时自动启动 |
| Content search | Same flag as the main window | 与主界面正文开关同步 |
| Rebuild index | Full reindex | 立即重建索引 |

---

## Architecture Overview / 架构概览

```text
┌─────────────────────────────────────────────┐
│  Menu Bar + Global Hotkey                   │
│  (LSUIElement agent)                       │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│  Search UI (AppKit floating panel)          │
│  filters · sort · list/grid · match badges  │
└─────────────────┬───────────────────────────┘
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
┌─────────────────┐ ┌───────────────────────┐
│ IndexEngine     │ │ ContentSearch         │
│ in-memory names │ │ Spotlight / mdfind    │
│ multi-core scan │ │ on-demand only        │
│ FSEvents + cache│ └───────────────────────┘
└─────────────────┘
```

| Layer | Role | 说明 |
|-------|------|------|
| **IndexEngine** | Filename index in memory | 文件名内存索引、多核匹配、缓存与重建 |
| **FSWatcher** | FSEvents | 目录变化感知 |
| **ContentSearch** | `mdfind` wrapper | 按需正文搜索 |
| **SearchWindow** | UI + keyboard | 搜索窗、筛选、结果操作 |
| **AppPrefs** | Settings + i18n | 语言、外观、快捷键、开关 |
| **LaunchAgent** | Optional login item | 可选登录启动 |

---

## Project Structure / 项目结构

```text
FlashFind/
├── Package.swift              # SPM, macOS 13+, Swift 5.9
├── Sources/FlashFind/         # App sources
│   ├── main.swift
│   ├── AppDelegate.swift
│   ├── IndexEngine.swift      # Filename index + search
│   ├── ContentSearch.swift    # Spotlight content search
│   ├── FSWatcher.swift
│   ├── SearchWindowController.swift
│   ├── SettingsWindowController.swift
│   ├── HotKey.swift
│   ├── AppPrefs.swift
│   └── …
├── Resources/Info.plist       # LSUIElement, version
├── scripts/
│   ├── build.sh
│   ├── install.sh
│   ├── uninstall.sh
│   └── generate_app_icon.swift
├── docs/
│   ├── screenshot.png
│   └── images/                # logo, hero, demo, screenshots
└── LICENSE                    # MIT
```

---

## Development / 开发

```bash
git clone https://github.com/ubuchow/FlashFind.git
cd FlashFind

# Debug build
swift build

# Release app bundle
./scripts/build.sh

# Install to ~/Applications
./scripts/install.sh
```

There is **no** required Xcode project file; the app is a Swift Package executable packaged into `.app` by scripts.

当前以 **Swift Package** 构建，通过脚本打包为 `.app`，不依赖单独的 `.xcodeproj`（如需可自行用 Xcode 打开 Package）。

Contributions welcome: bug reports, screenshots, translations, and PRs.

欢迎提交 Issue、截图、翻译与 Pull Request。

---

## Roadmap / 路线图

| Item | Status | 状态 |
|------|--------|------|
| Core filename search | Available | 已实现 |
| Optional content search | Available | 已实现 |
| Filters, sort, list/grid | Available | 已实现 |
| i18n (zh / en) + themes | Available | 已实现 |
| Homebrew cask | Planned | 计划中 |
| Signed / notarized release | Planned | 计划中 |
| Demo GIF & full screenshot set | In progress | 进行中 |

---

## FAQ / 常见问题

**Is FlashFind a Spotlight replacement?**  
No. It focuses on filename search and optional Spotlight-backed content search.

**FlashFind 会取代 Spotlight 吗？**  
不会。它专注文件名搜索，正文能力按需调用系统 Spotlight。

**Why is content search slower?**  
It shells out to system Spotlight (`mdfind`). Filename mode stays on the in-memory index.

**为什么正文搜索更慢？**  
正文走系统 Spotlight；文件名模式仍用内存索引。

**Does it index my whole disk by default?**  
No. Default roots are common user folders and Applications. You can add locations.

**默认会索引整块硬盘吗？**  
不会。默认是常见用户目录与 Applications，可自行添加位置。

**Is my data uploaded?**  
No. Search runs locally.

**数据会上传吗？**  
不会。搜索在本机完成。

**Where is the app installed?**  
`~/Applications/FlashFind.app`

**应用装在哪？**  
`~/Applications/FlashFind.app`

---

## License / 许可

[MIT](LICENSE) © 2026 [ubuchow](https://github.com/ubuchow)

---

## Credits / 致谢

Inspired by the clarity and speed of [Everything](https://www.voidtools.com/) on Windows — reimagined as a native macOS menu bar tool.

灵感来自 Windows 上 [Everything](https://www.voidtools.com/) 的清晰与速度，并以原生 macOS 菜单栏形态重新实现。

---

<p align="center">
  <sub>FlashFind — Find Anything. Instantly.</sub><br>
  <sub>找到任何文件，就在瞬间。</sub>
</p>
