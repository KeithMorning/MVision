# ADR-002: 设计 Token 架构

> 状态: 已接受
> 日期: 2026-07-24
> 决策者: 架构团队

---

## 背景

MVision 需要一个统一的设计系统来确保跨平台（iOS、Android、HarmonyOS NEXT、macOS、Windows）的视觉一致性，同时支持深色/浅色主题。

## 决策

建立集中式的设计 Token 系统，所有 UI 必须使用 Token 而非硬编码值。

## 设计 Token 分类

| 类别 | 说明 | 示例 |
|------|------|------|
| Color | 颜色系统 | primary, surface, textPrimary |
| Typography | 字体样式 | displayLarge, bodyMedium, code |
| Spacing | 间距 | 4, 8, 12, 16, 24, 32, 48 |
| Radius | 圆角 | 4, 8, 12, 16, 24 |
| Elevation | 阴影层级 | level0-level5 |
| Motion | 动画时长和曲线 | fast(150ms), normal(250ms) |
| IconSize | 图标尺寸 | 12, 16, 20, 24, 32, 48 |
| ContentWidth | 内容宽度 | reading(680), dialog(640) |

## 实现方式

```dart
// packages/design_system/lib/src/tokens/app_colors.dart
class AppColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color surface = Color(0xFFFAFAFA);
  // ...
}

// packages/design_system/lib/src/theme/app_theme.dart
class AppTheme {
  static ThemeData light() {
    return ThemeData(
      colorScheme: lightColorScheme,
      textTheme: _buildTextTheme(AppColors.textPrimary),
      // ...
    );
  }
}
```

## 规则

1. **业务页面不得直接散落不可追踪的颜色和间距常量**
2. 所有颜色必须通过 `AppColors` 或 `Theme.of(context).colorScheme` 访问
3. 所有间距必须使用 `AppSpacing` 常量
4. 深色模式不是简单反色，需要独立设计

## 影响

- 新增 `packages/design_system` 包
- 所有 UI 包依赖 `design_system`
- 业务代码必须通过 Token 访问设计值

## 参考

- 需求文档第 8.3 节
