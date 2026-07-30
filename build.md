# MVision Build Guide

> [English](build.md) | [简体中文](build.zh-CN.md)

This document describes how to build the MVision client (`apps/client`, Flutter) on each
desktop platform, including build commands and environment setup. For quick builds, use the
scripts at the repository root: `build.ps1` on Windows, `build.sh` on macOS.

> Target platforms: macOS, Windows. Mobile (iOS / Android / HarmonyOS) is not yet in the build phase.

## 1. Prerequisites

### 1.1 Flutter SDK

- **Flutter 3.44.8+ (Dart 3.12.2+)** is a hard requirement (`sdk: ^3.11.0` in `pubspec.yaml`;
  older SDKs cannot resolve the dependency constraints).
- Use the stable channel. Download: <https://docs.flutter.dev/get-started/install>
- After extracting, ensure `<flutter>/bin` is on your `PATH`; verify with `flutter --version`.

### 1.2 Mirrors (Mainland China network)

For the first `flutter pub get` and engine artifact downloads, setting mirrors is recommended
to avoid timeouts:

```bash
# macOS / Linux (add to ~/.zshrc or ~/.bashrc)
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# Windows PowerShell (current session)
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
```

> `build.ps1` and `build.sh` already set these mirrors, so manual configuration is not needed.

## 2. Dependency Setup

Every build starts with dependency resolution. After cloning the repo for the first time:

```bash
cd apps/client
flutter pub get
```

Local path dependencies live under `packages/` (`design_system`, `knowledge_core`,
`platform_api`, etc.) and are resolved together by `flutter pub get`.

---

## 3. Windows Build

### 3.1 Requirements

- **Windows 10 / 11** (x64)
- **Visual Studio 2022** with the **"Desktop development with C++"** workload installed.
  It must include the MSVC v143 compiler (cl.exe / link.exe) and the Windows SDK.
- Flutter 3.44.8+.

> Verify the install with `flutter doctor -v`; the `[!] Visual Studio` line should read `[√]`
> and detect VS 2022.

### 3.2 Quick Build (Recommended)

Run from the repository root:

```powershell
# Default release mode, SDK at the default path
.\build.ps1

# Specify the SDK path
$env:MVISION_FLUTTER_HOME = 'D:\SDKs\flutter'
.\build.ps1 -Mode debug

# Build + create an MSIX installer (release only)
.\build.ps1 -Msix
```

Script parameters:

| Parameter | Values | Description |
|---|---|---|
| `-Platform` | `windows` | Platform (currently windows only) |
| `-Mode` | `release` / `debug` / `profile` | Build mode, default `release` |
| `-Msix` | switch | Produce an MSIX installer; release only |

### 3.3 Manual Build

```powershell
cd apps/client
flutter pub get
flutter build windows --release   # or --debug / --profile
```

### 3.4 Output Location

```
apps/client/build/windows/x64/runner/Release/
├── mvision_client.exe            # main executable
├── flutter_windows.dll           # Flutter engine
├── sqlite3.dll                   # SQLite database
├── sqlite3_flutter_libs_plugin.dll
├── url_launcher_windows_plugin.dll
└── data/                         # Flutter assets (Dart AOT code, fonts, images)
```

Double-click `mvision_client.exe` to run, or use `flutter run -d windows` for debug runs.

### 3.5 MSIX Installer

`msix` is configured in pubspec.yaml (`com.mvision.client`, v1.0.0.0). After a release build:

```powershell
cd apps/client
dart run msix:create
# Output: build/windows/x64/runner/Release/MVision.msix
```

Or run `.\build.ps1 -Msix` to do it in one step.

---

## 4. macOS Build

### 4.1 Requirements

- **macOS 12+** (latest recommended)
- **Xcode 15+** (with Command Line Tools): `xcode-select --install`
- **CocoaPods**: `sudo gem install cocoapods` (or `brew install cocoapods`)
- macOS deployment target: **10.15** (see `macos/Podfile`)
- Flutter 3.44.8+.

### 4.2 Quick Build (Recommended)

```bash
# Default: build macOS release
./build.sh macos release

# Debug mode
./build.sh macos debug
```

Script usage: `./build.sh [macos|windows|all] [release|debug|profile]`

> `build.sh` defaults the Flutter path to `$HOME/development/flutter/bin`; adjust as needed.

### 4.3 Manual Build

```bash
cd apps/client
flutter pub get
flutter build macos --release
```

If you hit CocoaPods errors, run manually:

```bash
cd apps/client/macos
pod install
cd ..
flutter build macos --release
```

### 4.4 Output Location

```
apps/client/build/macos/Build/Products/Release/mvision_client.app
```

Double-click the `.app` to run, or use `flutter run -d macos`.

### 4.5 Signing & Entitlements

The current entitlements (`macos/Runner/DebugProfile.entitlements`, `Release.entitlements`)
disable App Sandbox and enable: network client/server (debug) and user-selected file
read/write. Before distribution, configure a developer certificate:

```bash
open macos/Runner.xcworkspace
# In Xcode -> Signing & Capabilities, set Team and Bundle ID
```

---

## 5. Build Modes

| Mode | Use case | Characteristics |
|---|---|---|
| `debug` | Development & debugging | JIT, hot reload, breakpoints; large size, lower perf |
| `profile` | Profiling | Near-release perf, keeps analysis tools |
| `release` | Distribution | AOT compiled; small size, best perf; used for MSIX / distribution |

Use `--debug` + `flutter run` during development; use `--release` to produce a distributable package.

---

## 6. Troubleshooting

### 6.1 Windows: "Building native assets failed" / cl.exe not found

**Cause**: A corrupted MSVC toolset directory (missing `cl.exe` / `link.exe`). Flutter's native
asset builder picks the highest-version toolset directory; if that one is incomplete, it fails.

**Diagnose**:

```powershell
# List installed MSVC toolsets
ls 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC'

# Check whether a version is complete (should have both cl.exe and link.exe)
ls '...\VC\Tools\MSVC\<version>\bin\Hostx64\x64\cl.exe'
ls '...\VC\Tools\MSVC\<version>\bin\Hostx64\x64\link.exe'
```

**Fix**: Delete the incomplete toolset directory that lacks `cl.exe` (admin privileges required),
keeping the complete versions. If that doesn't help, run **Repair** on VS 2022 via the VS Installer.

### 6.2 Windows: CMake reports "could not find any instance of Visual Studio"

**Cause**: The Visual Studio SetupConfiguration COM server is broken, so CMake cannot enumerate
VS instances.

**Verify**: vswhere and the COM server are independent paths; check both:

```powershell
# vswhere usually still works (independent of the COM server)
& 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe' -latest -products *

# If vswhere works but flutter build fails -> the COM server is broken
```

**Fix**: Run **Repair** on VS 2022 via the VS Installer; it reinstalls the Setup Configuration component.

### 6.3 Windows: "Unknown CMake command 'apply_standard_settings'"

**Cause**: Visual Studio IDE was pointed directly at `apps/client/windows/runner/CMakeLists.txt`
as the root. `apply_standard_settings` is defined in the **parent** `windows/CMakeLists.txt`, so it
is undefined when the runner subdirectory is opened on its own.

**Fix**: In the VS IDE, open the **`apps/client/windows` folder** (i.e. the top-level
`windows/CMakeLists.txt`) as the CMake root, not the `runner/` subdirectory.

### 6.4 Dependency resolution failure / pub get timeout

- Make sure mirrors are set (see 1.2).
- Delete `apps/client/.dart_tool` and `pubspec.lock`, then re-run `flutter pub get`.
- Confirm Flutter version ≥ 3.44.8 (`flutter --version`).

### 6.5 Windows: flutter doctor does not detect VS

Make sure VS 2022 was installed with the **"Desktop development with C++"** workload checked
(the .NET workload alone is not enough). Re-run `flutter doctor -v` after adding it.

### 6.6 macOS: pod install errors

- Upgrade CocoaPods: `sudo gem install cocoapods`.
- Clean and reinstall:

  ```bash
  cd apps/client/macos
  rm -rf Pods Podfile.lock
  pod install --repo-update
  ```

### 6.7 Persistent PATH setup

To avoid setting it every time, add Flutter to your system PATH:

- **Windows**: add `<flutter>\bin` to the system `Path` environment variable.
- **macOS**: add `export PATH="$HOME/development/flutter/bin:$PATH"` to `~/.zshrc`.

---

## 7. Build Flow Overview

```
flutter pub get          # resolve deps (incl. packages/ local packages)
       │
       ├── Windows: flutter build windows --<mode>  ->  .exe + .dll + data/
       │            └─ (optional) dart run msix:create  ->  .msix
       │
       └── macOS:   flutter build macos --<mode>    ->  .app
                    └─ (first time / plugin change) cd macos && pod install
```

For issues not covered here, see `apps/client/README.md` or open an Issue.
