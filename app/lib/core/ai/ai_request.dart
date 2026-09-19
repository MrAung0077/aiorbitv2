import 'ai_message.dart';
import 'provider_type.dart';
import '../text/response_language.dart';

class AIRequest {
  const AIRequest({
    required this.messages,
    this.preferredProvider,
    this.model,
    this.temperature = 0.7,
    this.maxTokens,
    this.responseLanguage = ResponseLanguage.auto,
    this.metadata = const <String, Object?>{},
  });

  factory AIRequest.fromPrompt({
    required String prompt,
    ProviderType? preferredProvider,
    String? model,
    double temperature = 0.7,
    int? maxTokens,
    ResponseLanguage responseLanguage = ResponseLanguage.auto,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return AIRequest(
      messages: <AIMessage>[
        AIMessage(role: AIMessageRole.user, content: prompt),
      ],
      preferredProvider: preferredProvider,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      responseLanguage: responseLanguage,
      metadata: metadata,
    );
  }

  final List<AIMessage> messages;
  final ProviderType? preferredProvider;
  final String? model;
  final double temperature;
  final int? maxTokens;
  final ResponseLanguage responseLanguage;
  final Map<String, Object?> metadata;

  String get latestUserPrompt {
    for (final AIMessage message in messages.reversed) {
      if (message.role == AIMessageRole.user) {
        return message.content;
      }
    }
    return '';
  }

  AIRequest copyWith({
    List<AIMessage>? messages,
    ProviderType? preferredProvider,
    bool clearPreferredProvider = false,
    String? model,
    bool clearModel = false,
    double? temperature,
    int? maxTokens,
    bool clearMaxTokens = false,
    ResponseLanguage? responseLanguage,
    Map<String, Object?>? metadata,
  }) {
    return AIRequest(
      messages: messages ?? this.messages,
      preferredProvider: clearPreferredProvider
          ? null
          : preferredProvider ?? this.preferredProvider,
      model: clearModel ? null : model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: clearMaxTokens ? null : maxTokens ?? this.maxTokens,
      responseLanguage: responseLanguage ?? this.responseLanguage,
      metadata: metadata ?? this.metadata,
    );
  }
}
