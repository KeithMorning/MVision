import 'package:flutter/material.dart';

/// Responsive breakpoints and layout utilities for MVision.
class AppBreakpoints {
  AppBreakpoints._();

  /// Below this: mobile layout (bottom nav, single column)
  static const double mobile = 768;

  /// Between mobile and tablet: compact desktop (narrower sidebar)
  static const double tablet = 1024;

  /// Above tablet: full desktop layout
  static const double desktop = 1280;

  /// Wide desktop: extra space for split views
  static const double wide = 1600;
}

/// Extension on BuildContext for responsive helpers.
extension ResponsiveContext on BuildContext {
  /// Current screen width.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Whether the current layout is mobile (< 768px).
  bool get isMobile => screenWidth < AppBreakpoints.mobile;

  /// Whether the current layout is tablet (768-1024px).
  bool get isTablet =>
      screenWidth >= AppBreakpoints.mobile && screenWidth < AppBreakpoints.tablet;

  /// Whether the current layout is desktop (>= 1024px).
  bool get isDesktop => screenWidth >= AppBreakpoints.tablet;

  /// Whether the current layout is wide desktop (>= 1600px).
  bool get isWide => screenWidth >= AppBreakpoints.wide;

  /// Adaptive sidebar width based on screen size.
  double get adaptiveSidebarWidth {
    if (isMobile) return 0;
    if (isTablet) return 220;
    return 280;
  }

  /// Adaptive content max width.
  double get adaptiveContentWidth {
    if (isMobile) return double.infinity;
    if (isTablet) return 700;
    return 860;
  }

  /// Adaptive padding for content areas.
  EdgeInsets get adaptiveContentPadding {
    if (isMobile) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    }
    if (isTablet) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
    return const EdgeInsets.symmetric(horizontal: 40, vertical: 24);
  }
}

/// A widget that adapts its child based on screen size.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < AppBreakpoints.mobile) {
          return mobile(context);
        }
        if (width < AppBreakpoints.tablet) {
          return (tablet ?? mobile)(context);
        }
        return (desktop ?? tablet ?? mobile)(context);
      },
    );
  }
}
