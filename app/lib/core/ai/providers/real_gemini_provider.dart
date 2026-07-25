import '../ai_chunk.dart';
import '../ai_provider.dart';
import '../ai_provider_metadata.dart';
import '../ai_provider_profiles.dart';
import '../ai_request.dart';
import '../ai_response.dart';
import '../provider_type.dart';
import 'gemini_api_client.dart';
import '../gemini_config.dart';
import 'dart:developer';

class RealGeminiProvider implements AIProvider {
  RealGeminiProvider({GeminiAPIClient? client})
    : _client =
          client ??
          GeminiAPIClient(
            apiKey: GeminiConfig.apiKey,
            defaultModel: GeminiConfig.model,
          );

  final GeminiAPIClient _client;

  @override
  ProviderType get type => ProviderType.gemini;

  @override
  String get displayName => 'Gemini';

  @override
  AIProviderMetadata get metadata => AIProviderProfiles.gemini;

  @override
  bool get isConfigured => _client.isConfigured;

  @override
  bool supports(AIRequest request) {
    return request.messages.isNotEmpty;
  }

  @override
  Future<AIResponse> complete(AIRequest request) async {
    try {
      final result = await _client.createResponse(
        input: request.latestUserPrompt,
        model: request.model,
        maxOutputTokens: request.maxTokens,
      );

      return AIResponse(
        provider: type,
        content: result.text,
        model: result.model,
        promptTokens: result.inputTokens ?? 0,
        completionTokens: result.outputTokens ?? 0,
      );
    } catch (e, stack) {
      log('GEMINI ERROR: $e', stackTrace: stack);
      rethrow;
    }
  }

  @override
  Stream<AIChunk> stream(AIRequest request) async* {
    try {
      final response = await complete(request);

      yield AIChunk.text(provider: type, text: response.content);

      yield AIChunk.done(provider: type);
    } catch (error, stackTrace) {
      log('Gemini stream failed: $error', stackTrace: stackTrace);

      yield AIChunk.error(provider: type, error: error.toString());
    }
  }
}
