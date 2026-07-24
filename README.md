# MVision

跨端 AI 知识客户端 — 连接用户自己的存储，让 AI 自动把零散资料整理成漂亮、可阅读、可搜索、可持续演进的个人 Wiki。

## 产品定位

知识领域的 Infuse：用户连接自己的本地目录或云存储，应用扫描其中的 Markdown、PDF、图片等资料，在本地建立索引，并由 LLM 将原始资料持续编译为互相链接、可追溯、可审核的个人 Wiki。

## 平台

| 平台 | 状态 |
|------|------|
| iOS / iPadOS | Phase 0 |
| Android | Phase 0 |
| HarmonyOS NEXT | Phase 0 |
| macOS | Phase 0 |
| Windows | Phase 0 |

## 技术栈

| 层 | 技术 |
|----|------|
| UI | Flutter |
| 状态管理 | Riverpod |
| 路由 | go_router |
| 不可变模型 | Freezed / json_serializable |
| 本地数据库 | SQLite + Drift |
| 全文搜索 | SQLite FTS5 |
| 网络 | Dio |
| AI | OpenAI-compatible API |

## 目录结构

```
├── apps/client/       # Flutter 应用入口
├── packages/          # 共享包
│   ├── design_system/     # 设计 Token
│   ├── knowledge_core/    # 领域模型
│   ├── markdown_engine/   # Markdown 解析
│   ├── markdown_reader/   # Markdown 阅读器
│   ├── markdown_editor/   # Markdown 编辑器
│   ├── search_engine/     # FTS5 搜索
│   ├── sync_engine/       # 同步引擎
│   ├── wiki_engine/       # LLM Wiki 编译
│   ├── platform_api/      # 平台抽象
│   └── connectors/        # 数据源连接器
├── docs/              # 文档
│   ├── adr/               # 架构决策记录
│   └── ...
└── tools/             # 工具脚本
```

## 文档

- [需求文档](mvision-development-requirements.md) — 产品需求
- [架构决策记录](docs/adr/) — ADR

## License

待定
