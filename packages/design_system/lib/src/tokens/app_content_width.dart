/// Content width tokens for MVision.
///
/// Used to constrain content width on large screens.
class AppContentWidth {
  const AppContentWidth._();

  static const double xs = 480;
  static const double sm = 640;
  static const double md = 768;
  static const double lg = 1024;
  static const double xl = 1280;
  static const double xxl = 1536;

  // Semantic widths
  static const double reading = 680; // Optimal reading width
  static const double dialog = sm;
  static const double sidebar = 280;
  static const double listPanel = 320;
}
