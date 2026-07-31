# FlashFind

> macOS 菜单栏**毫秒级**文件名搜索 — 类似 Windows Everything，体积极小、内存极低。

[![平台](https://img.shields.io/badge/平台-macOS%2013%2B-blue)](https://github.com/ubuchow/FlashFind)
[![语言](https://img.shields.io/badge/语言-Swift-orange)](https://www.swift.org)
[![协议](https://img.shields.io/badge/协议-MIT-green)](LICENSE)

纯 Swift 原生应用，无 Electron、无网络依赖。菜单栏常驻，`⌃⌥Space`（可自定义）一键唤起。

## 界面预览

<p align="center">
  <img src="docs/screenshot.png" alt="FlashFind 主界面" width="720" />
</p>

<p align="center"><sub>FlashFind：左上角关闭/缩小 · 搜索栏垂直居中 · 右上角设置 · 多维排序</sub></p>

---

## 功能特性

| 特性 | 说明 |
|------|------|
| 毫秒级搜索 | 内存文件名索引 + 多核并行匹配 |
| 体积极小 | 可执行文件约 400KB 级；图标代码生成 |
| 低内存 | 仅索引文件名与目录 ID，跳过 Caches / 云盘等 |
| 菜单栏 | 矢量放大镜图标，不进 Dock |
| 弹出动画 | 淡入缩放 + 轻弹簧，Esc 动画关闭 |
| 多维排序 | 相关度 / 名称 / 类型 / 大小 / 添加时间 / 修改时间 / 路径 |
| 右键定位 | 打开、访达显示、定位到所在文件夹、复制路径 |
| 设置 | 自定义唤起快捷键、默认排序、登录启动、重建索引 |
| 增量刷新 | FSEvents 监听变更并节流重建 |

---

## 系统要求

- macOS 13+
- [Xcode Command Line Tools](https://developer.apple.com/xcode/)（提供 `swift` / `iconutil`）

```bash
xcode-select --install   # 若尚未安装
```

---

## 安装

```bash
git clone https://github.com/ubuchow/FlashFind.git
cd FlashFind
chmod +x scripts/*.sh
./scripts/install.sh
```

安装后：

- 应用：`~/Applications/FlashFind.app`
- 登录时可自动启动（可在设置中开关）

### 卸载

```bash
./scripts/uninstall.sh
```

---

## 用法

| 操作 | 说明 |
|------|------|
| 菜单栏图标 / 全局热键 | 唤起搜索窗（默认 `⌃⌥Space`） |
| 输入关键字 | 实时过滤文件名（不区分大小写） |
| 排序 | 窗口内下拉切换排序维度 |
| 回车 | 打开 |
| `⌘` + 回车 | 在访达中显示并选中 |
| `⌥` + 回车 / 右键 | 定位到所在文件夹 |
| `⌘C` | 复制路径 |
| Esc | 关闭窗口 |
| 右上角 ⚙ | 打开设置 |

右键菜单栏图标：打开搜索 / 设置 / 重建索引 / 退出。

---

## 索引范围

默认扫描（兼顾速度与覆盖）：

- `~/Desktop` `~/Documents` `~/Downloads`
- `~/Movies` `~/Music` `~/Pictures`
- `~/Applications` `/Applications`

自动跳过：`node_modules`、`.git`、Caches、DerivedData、隐藏目录、Photos 图库包、Google Drive 挂载等。

索引缓存：`~/Library/Application Support/FlashFind/`

---

## 原理简述

Windows Everything 直接读 NTFS MFT；macOS 无公开等价接口。本工具采用：

1. 遍历目录，建立 **文件名 + 父目录 ID** 紧凑内存索引  
2. 搜索时对文件名做 **多线程子串匹配**  
3. **FSEvents** 监听变更并节流刷新  
4. 可选磁盘缓存，二次启动秒开  

---

## 项目结构

```
FlashFind/
├── Package.swift
├── Sources/FlashFind/          # 主程序（Swift）
├── Resources/Info.plist
├── docs/
│   └── screenshot.png          # README 界面截图
├── scripts/
│   ├── build.sh                # 编译 + 生成 AppIcon
│   ├── install.sh / uninstall.sh
│   └── generate_app_icon.swift
├── LICENSE
└── README.md
```

---

## 开发

```bash
swift build -c release
./scripts/build.sh      # 产出 dist/FlashFind.app
```

---

## 许可

[MIT](LICENSE) © 2026 ubuchow
