# ADR-003: 平台 API 抽象

> 状态: 已接受
> 日期: 2026-07-24
> 决策者: 架构团队

---

## 背景

MVision 需要在 5 个平台（iOS、Android、HarmonyOS NEXT、macOS、Windows）上运行。每个平台有不同的原生能力（安全存储、文件访问、网络状态等），需要通过统一接口访问。

## 决策

建立 `platform_api` 包，定义平台抽象接口。所有平台特定实现必须通过这些接口暴露。

## 核心接口

### SecureStorage
安全凭证存储（API Key、Token 等）。

```dart
abstract interface class SecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<bool> containsKey(String key);
}
```

平台实现:
- iOS: Keychain
- Android: Keystore
- macOS: Keychain
- Windows: Credential Manager
- HarmonyOS: Secure Storage

### FileAccess
文件系统访问。

```dart
abstract interface class FileAccess {
  Future<String?> pickDirectory();
  Future<Directory> getAppDocumentsDirectory();
  Future<Uint8List> readAsBytes(String path);
  Future<void> writeAsBytes(String path, Uint8List data);
  // ...
}
```

### ConnectivityMonitor
网络连接状态监控。

```dart
abstract interface class ConnectivityMonitor {
  Future<ConnectivityStatus> getStatus();
  Stream<ConnectivityStatus> get onStatusChanged;
  Future<bool> get isOnline;
}
```

## 规则

1. 平台插件通过 `platform_api` 接口暴露
2. 不直接调用平台代码
3. 优先选择纯 Dart 依赖
4. 引入含原生插件的依赖前，必须记录五平台支持状态

## 影响

- 新增 `packages/platform_api` 包
- 业务代码通过接口访问平台能力
- 便于测试（可 mock 接口）

## 参考

- 需求文档第 9.4 节
