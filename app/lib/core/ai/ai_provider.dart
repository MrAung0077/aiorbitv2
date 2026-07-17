import 'ai_provider_metadata.dart';
import 'ai_chunk.dart';
import 'ai_request.dart';
import 'ai_response.dart';
import 'provider_type.dart';

abstract interface class AIProvider {
  ProviderType get type;

  String get displayName;

  bool get isConfigured;

  AIProviderMetadata get metadata;

  bool supports(AIRequest request);

  Future<AIResponse> complete(AIRequest request);

  Stream<AIChunk> stream(AIRequest request);
}
