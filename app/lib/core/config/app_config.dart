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
  // OpenAI
  // ---------------------------------------------------------------------------

  static const String openAiApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );

  static const String openAiModel = String.fromEnvironment(
    'OPENAI_MODEL',
    defaultValue: 'gpt-5.6-sol',
  );

  static bool get hasOpenAiKey => openAiApiKey.trim().isNotEmpty;

  // ---------------------------------------------------------------------------
  // Future Providers
  // ---------------------------------------------------------------------------

  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String claudeApiKey = String.fromEnvironment(
    'CLAUDE_API_KEY',
    defaultValue: '',
  );

  static const String deepSeekApiKey = String.fromEnvironment(
    'DEEPSEEK_API_KEY',
    defaultValue: '',
  );

  static const String grokApiKey = String.fromEnvironment(
    'GROK_API_KEY',
    defaultValue: '',
  );
}
