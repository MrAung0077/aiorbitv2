class OpenAIConfig {
  const OpenAIConfig._();

  static const apiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );

  static const model = String.fromEnvironment(
    'OPENAI_MODEL',
    defaultValue: 'gpt-5',
  );
}
