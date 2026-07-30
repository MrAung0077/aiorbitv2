abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);

  // Startup experience
  static const Duration brandReveal = Duration(milliseconds: 900);
  static const Duration glowPulse = Duration(milliseconds: 1400);
  static const Duration statusTransition = Duration(milliseconds: 280);
  static const Duration startupExit = Duration(milliseconds: 650);
}
