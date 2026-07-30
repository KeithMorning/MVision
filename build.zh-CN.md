# MVision 构建指南

> [English](build.md) | [简体中文](build.zh-CN.md)

本文件说明 MVision 客户端（`apps/client`，Flutter）在各桌面平台的编译命令与环境配置。
快速构建可直接使用仓库根目录的脚本：Windows 用 `build.ps1`，macOS 用 `build.sh`。

> 目标平台：macOS、Windows。移动端（iOS / Android / HarmonyOS）尚未进入构建阶段。

## 1. 前置要求

### 1.1 Flutter SDK

- **Flutter 3.44.8+（Dart 3.12.2+）** 是本项目的硬性要求（`pubspec.yaml` 中 `sdk: ^3.11.0`，
  旧版 SDK 无法解析依赖约束）。
- 推荐使用 stable 通道。下载：<https://docs.flutter.dev/get-started/install>
- 解压后确保 `<flutter>/bin` 在 `PATH` 中，可用 `flutter --version` 验证。

### 1.2 国内镜像（中国大陆网络环境）

首次 `flutter pub get` 和下载引擎产物时建议设置镜像，否则可能超时：

```bash
# macOS / Linux（写入 ~/.zshrc 或 ~/.bashrc）
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# Windows PowerShell（当前会话）
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
```

> `build.ps1` 与 `build.sh` 已内置设置上述镜像，无需手动配置。

## 2. 依赖准备

所有构建都从依赖解析开始。首次克隆仓库后必须执行：

```bash
cd apps/client
flutter pub get
```

本地路径依赖位于 `packages/` 下（`design_system`、`knowledge_core`、`platform_api` 等），
`flutter pub get` 会一并解析。

---

## 3. Windows 构建

### 3.1 环境要求

- **Windows 10 / 11**（x64）
- **Visual Studio 2022**，安装 **"使用 C++ 的桌面开发"（Desktop development with C++）** 工作负载。
  需包含 MSVC v143 编译器（cl.exe / link.exe）与 Windows SDK。
- Flutter 3.44.8+。

> 验证安装：`flutter doctor -v`，`[!] Visual Studio` 一行需显示为 `[√]` 并识别到 VS 2022。

### 3.2 快速构建（推荐）

从仓库根目录执行：

```powershell
# 默认 release 模式，SDK 位于默认路径
.\build.ps1

# 指定 SDK 路径
$env:MVISION_FLUTTER_HOME = 'D:\SDKs\flutter'
.\build.ps1 -Mode debug

# 构建 + 打包 MSIX 安装包（仅 release）
.\build.ps1 -Msix
```

脚本参数：

| 参数 | 取值 | 说明 |
|---|---|---|
| `-Platform` | `windows` | 平台（当前仅 windows） |
| `-Mode` | `release` / `debug` / `profile` | 构建模式，默认 `release` |
| `-Msix` | 开关 | 生成 MSIX 安装包，仅 release 生效 |

### 3.3 手动构建

```powershell
cd apps/client
flutter pub get
flutter build windows --release   # 或 --debug / --profile
```

### 3.4 产物位置

```
apps/client/build/windows/x64/runner/Release/
├── mvision_client.exe            # 主程序
├── flutter_windows.dll           # Flutter 引擎
├── sqlite3.dll                   # SQLite 数据库
├── sqlite3_flutter_libs_plugin.dll
├── url_launcher_windows_plugin.dll
└── data/                         # Flutter 资产（Dart AOT 代码、字体、图片）
```

双击 `mvision_client.exe` 即可运行；或用 `flutter run -d windows` 调试运行。

### 3.5 MSIX 安装包

pubspec.yaml 中已配置 `msix`（`com.mvision.client`，v1.0.0.0）。release 构建后：

```powershell
cd apps/client
dart run msix:create
# 产物：build/windows/x64/runner/Release/MVision.msix
```

或直接 `.\build.ps1 -Msix` 一步完成。

---

## 4. macOS 构建

### 4.1 环境要求

- **macOS 12+**（建议最新版）
- **Xcode 15+**（含 Command Line Tools）：`xcode-select --install`
- **CocoaPods**：`sudo gem install cocoapods`（或 `brew install cocoapods`）
- macOS 部署目标：**10.15**（见 `macos/Podfile`）
- Flutter 3.44.8+。

### 4.2 快速构建（推荐）

```bash
# 默认构建 macOS release
./build.sh macos release

# debug 模式
./build.sh macos debug
```

脚本用法：`./build.sh [macos|windows|all] [release|debug|profile]`

> `build.sh` 默认 Flutter 路径为 `$HOME/development/flutter/bin`，按需调整。

### 4.3 手动构建

```bash
cd apps/client
flutter pub get
flutter build macos --release
```

如遇 CocoaPods 相关报错，手动执行：

```bash
cd apps/client/macos
pod install
cd ..
flutter build macos --release
```

### 4.4 产物位置

```
apps/client/build/macos/Build/Products/Release/mvision_client.app
```

双击 `.app` 运行，或 `flutter run -d macos`。

### 4.5 签名与权限

当前 entitlements（`macos/Runner/DebugProfile.entitlements`、`Release.entitlements`）已关闭 App Sandbox，
并启用：网络客户端/服务端（debug）、用户选定文件读写权限。分发前需配置开发者证书：

```bash
open macos/Runner.xcworkspace
# 在 Xcode -> Signing & Capabilities 中配置 Team 与 Bundle ID
```

---

## 5. 构建模式

| 模式 | 用途 | 特点 |
|---|---|---|
| `debug` | 开发调试 | 支持 JIT、热重载、断点；体积大、性能低 |
| `profile` | 性能分析 | 接近 release 性能，保留分析工具 |
| `release` | 发布分发 | AOT 编译，体积小、性能最优；用于 MSIX / 分发 |

开发阶段用 `--debug` + `flutter run`；产出可分发包用 `--release`。

---

## 6. 常见问题排查

### 6.1 Windows: "Building native assets failed" / 找不到 cl.exe

**原因**：MSVC 工具集目录损坏（`cl.exe` / `link.exe` 缺失）。Flutter 原生资源构建会选取版本号最高的工具集目录，若该目录残缺即报错。

**排查**：

```powershell
# 列出已安装的 MSVC 工具集
ls 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC'

# 检查某版本是否完整（应同时有 cl.exe 和 link.exe）
ls '...\VC\Tools\MSVC\<版本>\bin\Hostx64\x64\cl.exe'
ls '...\VC\Tools\MSVC\<版本>\bin\Hostx64\x64\link.exe'
```

**修复**：删除缺少 `cl.exe` 的残缺工具集目录（需管理员权限），保留完整版本。
仍不行则用 VS Installer 对 VS 2022 执行 **修复（Repair）**。

### 6.2 Windows: CMake 报 "could not find any instance of Visual Studio"

**原因**：Visual Studio 的 SetupConfiguration COM 服务器损坏，导致 CMake 无法枚举 VS 实例。

**验证**：vswhere 与 COM 是独立路径，可分别验证：

```powershell
# vswhere 通常仍可工作（独立于 COM 服务器）
& 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe' -latest -products *

# 若 vswhere 正常但 flutter build 失败 -> COM 服务器损坏
```

**修复**：用 VS Installer 对 VS 2022 执行 **修复（Repair）**，会重装 Setup Configuration 组件。

### 6.3 Windows: "Unknown CMake command 'apply_standard_settings'"

**原因**：用 Visual Studio IDE 直接打开了 `apps/client/windows/runner/CMakeLists.txt` 作为根目录。
`apply_standard_settings` 函数定义在**父级** `windows/CMakeLists.txt` 中，runner 子目录单独打开时该函数未定义。

**修复**：在 VS IDE 中以 **`apps/client/windows` 文件夹**（即顶层 `windows/CMakeLists.txt`）作为 CMake 根打开，而非 `runner/` 子目录。

### 6.4 依赖解析失败 / pub get 超时

- 确认已设置国内镜像（见 1.2）。
- 删除 `apps/client/.dart_tool` 与 `pubspec.lock` 后重新 `flutter pub get`。
- 确认 Flutter 版本 ≥ 3.44.8（`flutter --version`）。

### 6.5 Windows: flutter doctor 显示 VS 未识别

确保安装 VS 2022 时勾选了 **"使用 C++ 的桌面开发"** 工作负载（仅装 .NET 工作负载不够）。
补装后重新运行 `flutter doctor -v`。

### 6.6 macOS: pod install 报错

- 升级 CocoaPods：`sudo gem install cocoapods`。
- 清理后重装：

  ```bash
  cd apps/client/macos
  rm -rf Pods Podfile.lock
  pod install --repo-update
  ```

### 6.7 运行环境（PATH 持久化）

为避免每次手动设置，建议将 Flutter 加入系统 PATH：

- **Windows**：将 `<flutter>\bin` 加入系统环境变量 `Path`。
- **macOS**：在 `~/.zshrc` 加入 `export PATH="$HOME/development/flutter/bin:$PATH"`。

---

## 7. 构建流程一览

```
flutter pub get          # 解析依赖（含 packages/ 本地包）
       │
       ├── Windows: flutter build windows --<mode>  ->  .exe + .dll + data/
       │            └─ (可选) dart run msix:create  ->  .msix
       │
       └── macOS:   flutter build macos --<mode>    ->  .app
                    └─ (首次/插件变更) cd macos && pod install
```

如构建过程中遇到本文件未覆盖的问题，可参照 `apps/client/README.md` 或提交 Issue。
