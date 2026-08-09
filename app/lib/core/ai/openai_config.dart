class OpenAIConfig {
  const OpenAIConfig._();

  static const model = String.fromEnvironment(
    'OPENAI_MODEL',
    defaultValue: 'gpt-5.6-sol',
  );
}
