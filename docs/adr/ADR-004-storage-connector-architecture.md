# ADR-004: Storage Connector 架构

> 状态: 已接受
> 日期: 2026-07-24
> 决策者: 架构团队

---

## 背景

MVision 需要支持多种数据源（本地目录、百度网盘、WebDAV、未来的阿里云盘、S3 等）。UI 和 Wiki 引擎不得直接依赖具体厂商 SDK。

## 决策

定义统一的 `StorageConnector` 接口，所有数据源必须实现该接口。

## 核心接口

```dart
abstract interface class StorageConnector {
  String get sourceId;
  Future<ConnectionResult> connect();
  Future<List<StorageEntry>> list(String path);
  Future<Uint8List> read(String path);
  Future<WriteResult> write(String path, Uint8List data);
  Future<void> move(String from, String to);
  Future<void> delete(String path);
  Future<StorageMetadata> metadata(String path);
}
```

## 连接器列表

| 连接器 | 优先级 | 说明 |
|--------|--------|------|
| LocalConnector | P0 | 本地目录访问 |
| BaiduConnector | P0 | 百度网盘 |
| WebdavConnector | P0 | WebDAV 协议 |
| AliyunConnector | P1 | 阿里云盘 |
| S3Connector | P1 | S3 兼容存储 |
| GitConnector | P1 | Git 仓库 |
| SmbConnector | P1 | SMB/NAS |

## 设计原则

1. **UI 不直接调用具体连接器**: 通过抽象接口交互
2. **合约测试**: 所有连接器必须通过统一合约测试
3. **错误恢复**: API 限流、授权失效、网络错误必须有可恢复状态
4. **安全**: Token 存储在平台安全存储，禁止日志输出

## 影响

- 新增 `packages/connectors/` 目录
- 每个连接器独立包
- 便于添加新连接器

## 参考

- 需求文档第 6.1 节 FR-SOURCE-001
