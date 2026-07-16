import 'provider_type.dart';

class AIResponse {
  const AIResponse({
    required this.provider,
    required this.content,
    this.model,
    this.promptTokens,
    this.completionTokens,
    this.estimatedCost,
    this.metadata = const <String, Object?>{},
  });

  final ProviderType provider;
  final String content;
  final String? model;
  final int? promptTokens;
  final int? completionTokens;
  final double? estimatedCost;
  final Map<String, Object?> metadata;

  int? get totalTokens {
    final int? prompt = promptTokens;
    final int? completion = completionTokens;

    if (prompt == null && completion == null) {
      return null;
    }

    return (prompt ?? 0) + (completion ?? 0);
  }
}
