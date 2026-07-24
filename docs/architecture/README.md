# MVision 架构文档

本目录包含 MVision 的技术架构文档。

## 目录

- [ADR](../adr/) - 架构决策记录
- [Product](../product/) - 产品文档

## 架构概述

MVision 是一个跨平台 AI 知识客户端，采用分层架构：

```
┌─────────────────────────────────────────────────────────┐
│                        UI Layer                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │   Mobile    │  │   Desktop   │  │     Shared      │  │
│  │   Layout    │  │   Layout    │  │    Widgets      │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
├─────────────────────────────────────────────────────────┤
│                     Package Layer                        │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌───────────────┐  │
│  │design_  │ │markdown │ │ search  │ │    wiki       │  │
│  │system   │ │_engine  │ │_engine  │ │   _engine     │  │
│  └─────────┘ └─────────┘ └─────────┘ └───────────────┘  │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌───────────────┐  │
│  │knowledge│ │ sync    │ │platform │ │  connectors   │  │
│  │_core    │ │_engine  │ │_api     │ │               │  │
│  └─────────┘ └─────────┘ └─────────┘ └───────────────┘  │
├─────────────────────────────────────────────────────────┤
│                    Platform Layer                        │
│     iOS    Android    HarmonyOS    macOS    Windows      │
└─────────────────────────────────────────────────────────┘
```

## 依赖规则

1. `knowledge_core` 不依赖 Flutter
2. `sync_engine` 不依赖具体连接器
3. `wiki_engine` 不依赖 UI
4. `design_system` 不依赖业务模块
5. 平台插件通过 `platform_api` 接口暴露
6. UI 不直接调用百度网盘、WebDAV 或 SQLite

## 技术栈

| 层 | 技术 |
|----|------|
| UI | Flutter |
| 状态管理 | Riverpod |
| 路由 | go_router |
| 不可变模型 | Freezed |
| 本地数据库 | SQLite + Drift |
| 全文搜索 | SQLite FTS5 |
| 网络 | Dio |
| AI | OpenAI-compatible API |

## 参考

- [需求文档](../../mvision-development-requirements.md)
- [AGENTS.md](../../AGENTS.md)
