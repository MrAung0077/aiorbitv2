import '../ai_capability.dart';
import '../ai_chunk.dart';
import '../ai_provider.dart';
import '../ai_provider_metadata.dart';
import '../ai_request.dart';
import '../ai_response.dart';
import '../provider_type.dart';
import 'ovexiq_backend_api_client.dart';

class OvexiqBackendProvider implements AIProvider {
  OvexiqBackendProvider(this._client);

  final OvexiqBackendApiClient _client;

  // The backend is the sole production provider. Keeping the existing default
  // type avoids expanding the provider enum into Chat and Mission metadata.
  @override
  ProviderType get type => ProviderType.openAI;

  @override
  String get displayName => 'Ovexiq';

  @override
  bool get isConfigured => _client.isConfigured;

  @override
  AIProviderMetadata get metadata => const AIProviderMetadata(
    supportedTasks: <AITaskType>{
      AITaskType.generalChat,
      AITaskType.coding,
      AITaskType.research,
      AITaskType.summarization,
      AITaskType.translation,
    },
    supportsStreaming: false,
  );

  @override
  bool supports(AIRequest request) {
    return request.messages.isNotEmpty &&
        request.latestUserPrompt.trim().isNotEmpty;
  }

  @override
  Future<AIResponse> complete(AIRequest request) async {
    _validate(request);
    final result = await _client.complete(request);

    return AIResponse(
      provider: type,
      content: result.content,
      model: result.model,
      promptTokens: result.promptTokens,
      completionTokens: result.completionTokens,
      metadata: <String, Object?>{
        if (result.requestId != null) 'requestId': result.requestId,
        'backend': true,
      },
    );
  }

  @override
  Stream<AIChunk> stream(AIRequest request) async* {
    _validate(request);

    yield AIChunk.status(
      provider: type,
      text: 'Ovexiq is preparing your result.',
    );

    final response = await complete(request);

    yield AIChunk.text(provider: type, text: response.content);

    if (response.promptTokens != null || response.completionTokens != null) {
      yield AIChunk.usage(
        provider: type,
        promptTokens: response.promptTokens,
        completionTokens: response.completionTokens,
      );
    }

    yield AIChunk.done(provider: type);
  }

  void _validate(AIRequest request) {
    if (!isConfigured) {
      throw StateError('Ovexiq AI is not configured.');
    }

    if (!supports(request)) {
      throw ArgumentError('The Ovexiq AI request is not supported.');
    }
  }

  void close() {
    _client.close();
  }
}
