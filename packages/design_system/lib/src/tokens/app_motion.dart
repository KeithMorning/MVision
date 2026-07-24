/// Motion tokens for MVision.
class AppMotion {
  const AppMotion._();

  // Durations (in milliseconds)
  static const Duration instant = Duration(milliseconds: 50);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration verySlow = Duration(milliseconds: 600);

  // Curves
  static const String easeIn = 'easeIn';
  static const String easeOut = 'easeOut';
  static const String easeInOut = 'easeInOut';

  // Spring physics (for natural feel)
  static const double springStiffness = 300;
  static const double springDamping = 25;
}
