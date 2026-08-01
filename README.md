# FlashFind

> macOS 菜单栏**毫秒级**文件名搜索 — 类似 Windows Everything，体积极小、内存极低。

[![平台](https://img.shields.io/badge/平台-macOS%2013%2B-blue)](https://github.com/ubuchow/FlashFind)
[![语言](https://img.shields.io/badge/语言-Swift-orange)](https://www.swift.org)
[![协议](https://img.shields.io/badge/协议-MIT-green)](LICENSE)

纯 Swift 原生应用，无 Electron。菜单栏常驻，全局快捷键一键唤起。

## 界面预览

<p align="center">
  <img src="docs/screenshot.png" alt="FlashFind 主界面" width="820" />
</p>

<p align="center"><sub>侧边栏分类与位置 · 顶部筛选 · 结果列表（大小/时间）· 设置与快捷键</sub></p>

---

## 功能

| 功能 | 说明 |
|------|------|
| 毫秒级搜索 | 内存文件名索引 + 多核匹配 |
| 侧边栏分类 | 全部 / 文件 / 文件夹 / 应用 / 其他（含计数） |
| 位置筛选 | 桌面、文档、下载等；可「添加位置」 |
| 筛选条 | 类型 · 修改时间 · 大小 · 位置 |
| 排序 | 相关性 / 名称 / 类型 / 大小 / 时间 / 路径 |
| 列表视图 | 图标 · 名称 · 路径 · 大小 · 修改时间 |
| 右键 | 打开 / 访达显示 / 定位文件夹 / 复制路径 |
| 设置 | 自定义全局快捷键、默认排序、登录启动 |

---

## 安装

```bash
git clone https://github.com/ubuchow/FlashFind.git
cd FlashFind
./scripts/install.sh
```

应用：`~/Applications/FlashFind.app`

### 卸载

```bash
./scripts/uninstall.sh
```

---

## 快捷键（默认）

| 按键 | 作用 |
|------|------|
| ⌃⌥Space（可改） | 唤起 / 关闭 |
| ↩ | 打开 |
| ⌘↩ | 在访达中显示 |
| ↑↓ | 选择结果 |
| Esc | 关闭窗口 |

---

## 索引范围

默认：桌面、文档、下载、影片、音乐、图片、Applications。  
跳过 `node_modules`、`.git`、Caches、图库包、云盘挂载等。

---

## 许可

[MIT](LICENSE) © 2026 ubuchow
