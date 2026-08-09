class GeminiConfig {
  const GeminiConfig._();

  static const model = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.5-flash',
  );
}
