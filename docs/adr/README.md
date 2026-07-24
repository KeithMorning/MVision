# Architecture Decision Records (ADR)

本目录包含 MVision 项目的所有架构决策记录。

## ADR 列表

| ADR | 标题 | 状态 |
|-----|------|------|
| [ADR-001](ADR-001-monorepo-structure.md) | Monorepo 结构与 Dart Pub Workspaces | 已接受 |
| [ADR-002](ADR-002-design-tokens.md) | 设计 Token 架构 | 已接受 |
| [ADR-003](ADR-003-platform-api-abstraction.md) | 平台 API 抽象 | 已接受 |
| [ADR-004](ADR-004-storage-connector-architecture.md) | Storage Connector 架构 | 已接受 |
| [ADR-005](ADR-005-knowledge-core-domain-model.md) | Knowledge Core 领域模型 | 已接受 |

## ADR 模板

新 ADR 应包含以下部分：

1. **标题**: ADR-NNN: 简短描述
2. **状态**: 已提议 / 已接受 / 已废弃 / 已取代
3. **日期**: YYYY-MM-DD
4. **背景**: 为什么需要这个决策
5. **决策**: 选择了什么方案
6. **考虑的选项**: 列出所有考虑过的选项
7. **理由**: 为什么选择这个方案
8. **影响**: 这个决策带来的影响
9. **参考**: 相关文档链接

## 何时需要 ADR

根据 AGENTS.md 第 3 节，以下情况必须新增 ADR：

- 更换核心状态管理或数据库
- 引入 Rust
- 改变 Markdown 是唯一事实来源的原则
- 引入自有服务器保存用户正文
- 引入新的跨端 UI 框架
- 使用专有文档格式
- 放弃某个正式平台
- 改变同步冲突策略
