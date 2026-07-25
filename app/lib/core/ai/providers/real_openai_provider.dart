import '../ai_chunk.dart';
import '../ai_provider.dart';
import '../ai_provider_metadata.dart';
import '../ai_provider_profiles.dart';
import '../ai_request.dart';
import '../ai_response.dart';
import '../provider_type.dart';
import 'openai_api_client.dart';
import '../openai_config.dart';

class RealOpenAIProvider implements AIProvider {
  RealOpenAIProvider({OpenAIAPIClient? client})
    : _client =
          client ??
          OpenAIAPIClient(
            apiKey: OpenAIConfig.apiKey,
            defaultModel: OpenAIConfig.model,
          );

  final OpenAIAPIClient _client;

  @override
  ProviderType get type => ProviderType.openAI;

  @override
  String get displayName => 'OpenAI';

  @override
  bool get isConfigured => _client.isConfigured;

  @override
  AIProviderMetadata get metadata => AIProviderProfiles.openAI;

  @override
  bool supports(AIRequest request) {
    return request.messages.isNotEmpty &&
        request.latestUserPrompt.trim().isNotEmpty;
  }

  @override
  Future<AIResponse> complete(AIRequest request) async {
    _validate(request);

    final result = await _client.createResponse(
      input: request.latestUserPrompt,
      model: request.model,
      maxOutputTokens: request.maxTokens,
    );

    return AIResponse(
      provider: type,
      content: result.text,
      model: result.model,
      promptTokens: result.inputTokens,
      completionTokens: result.outputTokens,
      metadata: <String, Object?>{'responseId': result.id, 'mock': false},
    );
  }

  @override
  Stream<AIChunk> stream(AIRequest request) async* {
    _validate(request);

    yield AIChunk.status(
      provider: type,
      text: 'OpenAI is generating a response.',
    );

    final response = await complete(request);

    yield AIChunk.text(provider: type, text: response.content);

    yield AIChunk.usage(
      provider: type,
      promptTokens: response.promptTokens ?? 0,
      completionTokens: response.completionTokens ?? 0,
    );

    yield AIChunk.done(provider: type);
  }

  void _validate(AIRequest request) {
    if (!isConfigured) {
      throw StateError('The OpenAI API key is not configured.');
    }

    if (!supports(request)) {
      throw ArgumentError('The OpenAI request is not supported.');
    }
  }

  void close() {
    _client.close();
  }
}
