# MVision

> [English](README.md) | [简体中文](README.zh-CN.md)

跨端 AI 知识客户端 - 连接用户自己的存储，让 AI 自动把零散资料整理成漂亮、可阅读、可搜索、可持续演进的个人 Wiki。

## 产品定位

知识领域的 Infuse：用户连接自己的本地目录或云存储，应用扫描其中的 Markdown、PDF、图片等资料，在本地建立索引，并由 LLM 将原始资料持续编译为互相链接、可追溯、可审核的个人 Wiki。

## 功能特性

### 核心知识库 (Obsidian-like)

- **Vault 模型** - 单知识库目录，替代多源架构
- **文件浏览器** - 树形侧边栏，展开/折叠、右键菜单
- **反向链接** - 链接提及 + 出站链接面板
- **标签系统** - `#tag` 解析 + YAML frontmatter + 标签面板
- **快速切换器** - `⌘O` 模糊搜索 + 最近文件
- **命令面板** - `⌘K` 可扩展命令注册
- **关系图谱** - 力导向图可视化，缩放/平移/点击交互

### 编辑器

- Markdown 语法高亮（标题、粗体、斜体、代码、链接）
- `[[Wiki 链接自动补全]]` 弹出笔记列表
- 并排编辑/预览分屏模式
- 字数统计 + 阅读时间
- `![[embed]]` 嵌入其他笔记内容
- 编辑历史（自动快照 + 回滚）

### AI 功能 (BYOK)

- **Wiki 编译** - 选择源文档，AI 生成结构化 Wiki，支持 Patch 应用
- **知识问答** - 基于 FTS 检索相关文档，AI 引用来源回答
- **流式响应** - SSE 逐 token 实时显示
- 支持任意 OpenAI-compatible API

### 其他

- 每日日记 (`daily/YYYY-MM-DD.md`)
- 模板插入 (`templates/` 文件夹)
- 收藏/星标笔记
- 分屏视图（拖拽分割线）
- 重命名自动更新所有引用链接
- 百度网盘同步（OAuth / BDUSS 双模式）

## 平台

| 平台 | 状态 |
|------|------|
| macOS | ✅ 主要开发平台 |
| Windows | ✅ 支持 |
| iOS / iPadOS | ✅ 移动端 Shell |
| Android | ✅ 移动端 Shell |
| HarmonyOS NEXT | 待定 |

## 技术栈

| 层 | 技术 |
|----|------|
| UI | Flutter (Material 3) |
| 状态管理 | Riverpod (StateNotifier) |
| 路由 | go_router |
| 本地数据库 | SQLite (sqlite3) + FTS5 |
| 网络 | Dio |
| AI | OpenAI-compatible API (BYOK) |
| 安全存储 | flutter_secure_storage |
| 设计系统 | 自定义 Token (AppColors, AppSpacing, AppRadius) |

## 目录结构

```
├── apps/client/           # Flutter 应用入口
│   ├── lib/
│   │   ├── app/               # 路由、Providers
│   │   ├── desktop/           # 桌面端页面和组件
│   │   │   ├── pages/         # 页面 (home, reader, editor, graph, ai...)
│   │   │   └── widgets/       # 组件 (file_explorer, backlinks, palette...)
│   │   ├── mobile/            # 移动端 Shell
│   │   ├── services/          # 服务 (database, scanner, ai, sync)
│   │   └── shared/            # 共享工具 (responsive, animations)
├── packages/              # 共享包
│   ├── design_system/         # 设计 Token
│   ├── knowledge_core/        # 领域模型
│   ├── markdown_engine/       # Markdown 解析
│   ├── markdown_reader/       # Markdown 阅读器
│   ├── markdown_editor/       # Markdown 编辑器
│   ├── search_engine/         # FTS5 搜索
│   ├── sync_engine/           # 同步引擎
│   ├── wiki_engine/           # LLM Wiki 编译
│   ├── platform_api/          # 平台抽象
│   └── connectors/            # 数据源连接器 (baidu_connector)
├── docs/                  # 文档
│   ├── adr/                   # 架构决策记录
│   └── ...
└── pubspec.yaml           # Workspace 配置
```

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| `⌘O` | 快速切换器 |
| `⌘K` | 命令面板 |
| `⌘N` | 新建笔记 |
| `⌘S` | 保存 |
| `⌘\` | 切换侧边栏 |
| `⌘,` | 设置 |
| `⌘⇧F` | 全局搜索 |
| `⌘Z` / `⌘⇧Z` | 撤销 / 重做 |

## 开发

```bash
# 安装依赖
cd apps/client && flutter pub get

# 运行 (macOS)
flutter run -d macos

# 分析
flutter analyze
```

## 文档

- [需求文档](mvision-development-requirements.md) - 产品需求（中文）
- [架构决策记录](docs/adr/) - ADR（中文）
- [构建指南](build.zh-CN.md) - 各平台构建说明

## License

待定
