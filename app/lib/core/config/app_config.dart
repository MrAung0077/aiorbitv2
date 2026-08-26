// AIOrbit Global Configuration
//
// This class is the single source of truth for
// application-wide configuration.
//
// Never access String.fromEnvironment()
// directly from feature code.

import 'package:flutter/foundation.dart' show kReleaseMode;

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

  /// Verifies that a beta release has the minimum safe gateway configuration
  /// before the app starts. Values are deliberately never included in errors.
  static void validateStartupConfiguration({
    String? environment,
    String? apiBaseUrl,
    String? betaAccessToken,
    bool? isReleaseBuild,
  }) {
    final resolvedEnvironment = environment ?? AppConfig.environment;
    final resolvedApiBaseUrl = (apiBaseUrl ?? ovexiqApiBaseUrl).trim();
    final resolvedBetaAccessToken = (betaAccessToken ?? ovexiqBetaAccessToken)
        .trim();

    if ((isReleaseBuild ?? kReleaseMode) &&
        resolvedEnvironment != 'production') {
      throw const AppConfigurationException(
        'Release builds require APP_ENV=production.',
      );
    }

    if (resolvedEnvironment != 'production') {
      return;
    }

    if (resolvedApiBaseUrl.isEmpty) {
      throw const AppConfigurationException(
        'Production configuration requires OVEXIQ_API_BASE_URL.',
      );
    }

    final gatewayUri = Uri.tryParse(resolvedApiBaseUrl);
    if (gatewayUri == null ||
        gatewayUri.scheme != 'https' ||
        gatewayUri.host.isEmpty) {
      throw const AppConfigurationException(
        'Production configuration requires OVEXIQ_API_BASE_URL to be an HTTPS URL.',
      );
    }

    if (resolvedBetaAccessToken.isEmpty) {
      throw const AppConfigurationException(
        'Production configuration requires OVEXIQ_BETA_ACCESS_TOKEN.',
      );
    }
  }
}

class AppConfigurationException implements Exception {
  const AppConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}
