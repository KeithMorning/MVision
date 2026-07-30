# MVision Development Rules

> 版本: 1.0 | 日期: 2026-07-24
> 依据: mvision-development-requirements.md 第 16 节

---

## 1. 开始任务前

1. 阅读 `mvision-development-requirements.md` 全文
2. 检查本文件（`AGENTS.md`）
3. 确认目标属于当前 Phase
4. 列出将修改的模块和验收方式
5. 不因实现方便而跨越依赖边界

---

## 2. 实现要求

- 优先小而完整的垂直切片
- 新平台能力先定义接口，再做平台实现
- 新连接器必须通过统一合约测试
- 新的持久化字段必须包含迁移方案
- 新的 AI 写入能力必须包含校验和撤销路径
- 新增第三方依赖必须记录许可证、维护状态和五平台支持
- 不在 UI 中直接编写存储、同步或 LLM 调用
- 涉及动效、手势、画布的交互开发，必须遵循 `docs/design/interaction-principles.md`

---

## 3. 架构决策触发条件

以下情况必须新增 ADR（`docs/adr/`）：

| 条件 | 说明 |
|------|------|
| 更换核心状态管理或数据库 | 如从 Riverpod 换到 Bloc，或从 Drift 换到 sqflite |
| 引入 Rust | 目前 P0 不引入 Rust |
| 改变 Markdown 是唯一事实来源的原则 | 如引入专有格式 |
| 引入自有服务器保存用户正文 | 目前无服务器架构 |
| 引入新的跨端 UI 框架 | 目前使用 Flutter |
| 使用专有文档格式 | 必须使用 Markdown |
| 放弃某个正式平台 | 需明确记录原因 |
| 改变同步冲突策略 | 目前是冲突副本策略 |

---

## 4. 依赖规则

| 规则 | 说明 |
|------|------|
| `knowledge_core` 不依赖 Flutter | 可在纯 Dart 环境运行 |
| `sync_engine` 不依赖具体连接器 | 通过抽象接口交互 |
| `wiki_engine` 不依赖 UI | 纯业务逻辑 |
| `design_system` 不依赖业务模块 | 只依赖 Flutter |
| 平台插件通过 `platform_api` 接口暴露 | 不直接调用平台代码 |
| UI 不直接调用百度网盘、WebDAV 或 SQLite | 通过抽象层访问 |
| 优先选择纯 Dart 依赖 | 减少原生插件兼容性问题 |
| 引入含原生插件的依赖前，必须记录五平台支持状态 | iOS/Android/HarmonyOS/macOS/Windows |

---

## 5. 完成定义

一个功能只有同时满足以下条件才算完成：

- [ ] 行为符合需求
- [ ] 包含必要测试
- [ ] 五平台影响已评估
- [ ] HarmonyOS 插件差异已处理或记录
- [ ] 错误与空状态完整
- [ ] 不输出敏感日志
- [ ] 文档和 ADR 已更新
- [ ] 验收步骤可由另一位开发者复现

---

## 6. 目录结构

```
mvision/
├── apps/
│   └── client/           # Flutter 应用
│       ├── lib/mobile/   # 移动端布局
│       ├── lib/desktop/  # 桌面端布局
│       ├── lib/shared/   # 共享 UI 组件
│       ├── android/      # Android 平台工程
│       ├── ios/          # iOS 平台工程
│       ├── macos/        # macOS 平台工程
│       ├── windows/      # Windows 平台工程
│       └── ohos/         # HarmonyOS NEXT 平台工程
├── packages/
│   ├── design_system/    # 设计 Token、主题
│   ├── knowledge_core/   # 领域模型、扫描/索引
│   ├── markdown_engine/  # Markdown AST 解析
│   ├── markdown_reader/  # Markdown 渲染
│   ├── markdown_editor/  # Markdown 编辑
│   ├── search_engine/    # FTS5 搜索
│   ├── sync_engine/      # 同步状态机
│   ├── wiki_engine/      # LLM Wiki 编译
│   ├── platform_api/     # 平台抽象接口
│   └── connectors/       # 数据源连接器
│       ├── local_connector/
│       ├── baidu_connector/
│       └── webdav_connector/
├── docs/
│   ├── adr/              # 架构决策记录
│   ├── architecture/     # 架构文档
│   └── product/          # 产品文档
├── tools/                # 工具脚本
└── tests/                # 集成测试
```
