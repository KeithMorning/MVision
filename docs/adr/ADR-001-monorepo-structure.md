# ADR-001: Monorepo 结构与 Dart Pub Workspaces

> 状态: 已接受
> 日期: 2026-07-24
> 决策者: 架构团队

---

## 背景

MVision 是一个跨平台（iOS、Android、HarmonyOS NEXT、macOS、Windows）的 Flutter 应用。为了管理多个相关包和应用，需要选择合适的 Monorepo 管理方案。

## 决策

采用 **Dart Pub Workspaces** 作为 Monorepo 管理方案。

## 考虑的选项

### 选项 1: Melos
- 优点: 社区标准、功能丰富（自动版本、发布、脚本编排）
- 缺点: 额外依赖、学习成本

### 选项 2: Dart Pub Workspaces
- 优点: 原生支持（Dart 3.6+）、无需额外工具、简单可靠
- 缺点: 功能较基础，无自动版本管理

### 选项 3: 手动管理
- 优点: 无依赖
- 缺点: 无法统一管理依赖版本

## 理由

1. **简单可靠**: Dart Pub Workspaces 是 Dart SDK 原生功能，无需额外安装
2. **满足需求**: P0 阶段不需要复杂的版本管理和发布编排
3. **减少依赖**: 遵循"优先选择纯 Dart 依赖"的原则
4. **易于迁移**: 如需 Melos 功能，后续可无缝迁移

## 影响

- 根目录 `pubspec.yaml` 使用 `workspace:` 字段声明所有包
- 每个包独立维护自己的 `pubspec.yaml`
- 依赖通过 `path:` 引用本地包

## 目录结构

```
mvision/
├── pubspec.yaml          # 工作区根声明
├── apps/
│   └── client/           # Flutter 应用
├── packages/             # 共享包
│   ├── design_system/
│   ├── knowledge_core/
│   ├── markdown_engine/
│   ├── markdown_reader/
│   ├── markdown_editor/
│   ├── search_engine/
│   ├── sync_engine/
│   ├── wiki_engine/
│   ├── platform_api/
│   └── connectors/
│       ├── local_connector/
│       ├── baidu_connector/
│       └── webdav_connector/
├── docs/
├── tools/
└── tests/
```

## 参考

- [Dart Pub Workspaces](https://dart.dev/tools/pub/workspaces)
- 需求文档第 9.3 节
