# ADR-005: Knowledge Core 领域模型

> 状态: 已接受
> 日期: 2026-07-24
> 决策者: 架构团队

---

## 背景

MVision 的核心是知识管理系统。需要一个清晰的领域模型来表示文档、主题、同步状态、Wiki Patch 等概念。

## 决策

在 `knowledge_core` 包中定义核心领域模型，使用 Freezed 生成不可变模型。

## 核心模型

### KnowledgeDocument
知识文档。

```dart
@freezed
class KnowledgeDocument with _$KnowledgeDocument {
  const factory KnowledgeDocument({
    required String id,
    required String sourceId,
    required String path,
    required String title,
    required DocumentKind kind,
    required String contentHash,
    required DateTime modifiedAt,
    @Default(false) bool isAvailableOffline,
  }) = _KnowledgeDocument;
}
```

### KnowledgeTopic
知识主题（跨文件夹、跨数据源）。

```dart
@freezed
class KnowledgeTopic with _$KnowledgeTopic {
  const factory KnowledgeTopic({
    required String id,
    required String title,
    String? summary,
    @Default([]) List<String> documentIds,
    required DateTime updatedAt,
  }) = _KnowledgeTopic;
}
```

### WikiPatch
LLM 生成的 Wiki 更新补丁。

```dart
@freezed
class WikiPatch with _$WikiPatch {
  const factory WikiPatch({
    required String id,
    required List<FilePatch> files,
    required List<SourceReference> references,
    required String summary,
    required PatchRiskLevel riskLevel,
    required DateTime createdAt,
    @Default(false) bool applied,
    DateTime? appliedAt,
  }) = _WikiPatch;
}
```

### SyncConflict
同步冲突记录。

```dart
@freezed
class SyncConflict with _$SyncConflict {
  const factory SyncConflict({
    required String sourceId,
    required String path,
    required String localHash,
    required String remoteHash,
    required DateTime detectedAt,
  }) = _SyncConflict;
}
```

## 设计原则

1. **文档身份与路径分离**: 同一文档可能存在于不同路径
2. **来源引用可以追溯**: SourceReference 可定位到原始来源
3. **Patch 在写入前是独立实体**: 必须先校验再应用
4. **同步状态不写入正文**: 存储在独立表中

## 影响

- 新增 `packages/knowledge_core` 包
- 不依赖 Flutter，可在纯 Dart 环境运行
- 使用 Freezed 保证不可变性

## 参考

- 需求文档第 10 节
