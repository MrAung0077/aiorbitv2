// AIOrbit Global Configuration
//
// This class is the single source of truth for
// application-wide configuration.
//
// Never access String.fromEnvironment()
// directly from feature code.

class AppConfig {
  const AppConfig._();

  // ---------------------------------------------------------------------------
  // App
  // ---------------------------------------------------------------------------

  static const String appName = 'Ovexiq';

  static const String appVersion = '1.0.0';

  // ---------------------------------------------------------------------------
  // Environment
  // ---------------------------------------------------------------------------

  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static bool get isDevelopment => environment == 'development';

  static bool get isProduction => environment == 'production';

  // ---------------------------------------------------------------------------
  // AI Provider Mode
  // ---------------------------------------------------------------------------

  static const bool _mockProvidersEnabled = bool.fromEnvironment(
    'USE_MOCK_AI',
    defaultValue: false,
  );

  static bool get useMockProviders => isDevelopment && _mockProvidersEnabled;

  // ---------------------------------------------------------------------------
  // Ovexiq AI Gateway
  // ---------------------------------------------------------------------------

  static const String ovexiqApiBaseUrl = String.fromEnvironment(
    'OVEXIQ_API_BASE_URL',
    defaultValue: '',
  );

  /// Identifies a revocable private-beta tester to the gateway.
  ///
  /// This value is shipped in the app and is therefore not a secret. The
  /// gateway must rate-limit it and must never treat it as authority for
  /// unlimited provider spend.
  static const String ovexiqBetaAccessToken = String.fromEnvironment(
    'OVEXIQ_BETA_ACCESS_TOKEN',
    defaultValue: '',
  );
}
