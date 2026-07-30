# MVision 客户端

MVision 的 Flutter 客户端。当前 Windows 端处于 Phase 0 平台接入阶段；
桌面 UI 的本地知识阅读器切片在 `lib/desktop/` 中。

## Windows 开发环境

- Flutter 3.44.8+（Dart 3.12.2+）
- Visual Studio 2022，并安装 **Desktop development with C++** workload
- Windows runner 需先由匹配版本的 Flutter SDK 生成：

  ```powershell
  cd apps/client
  flutter create --platforms=windows .
  ```

## 构建与验证

从仓库根目录执行：

```powershell
# SDK 位于默认路径 E:\Web\Flutter\flutter_windows_3.44.8-stable\flutter 时
.\build.ps1

# SDK 位于其他位置时
$env:MVISION_FLUTTER_HOME = 'D:\SDKs\flutter'
.\build.ps1 -Mode debug
```

构建脚本会执行依赖解析并产出 `build/windows/x64/runner/<mode>/mvision_client.exe`。
Windows runner 生成后还应运行：

```powershell
cd apps/client
flutter test
flutter analyze
flutter build windows --debug
```
