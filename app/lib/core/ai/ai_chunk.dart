import 'provider_type.dart';

enum AIChunkType { text, status, usage, error, done }

class AIChunk {
  const AIChunk({
    required this.type,
    required this.provider,
    this.text = '',
    this.promptTokens,
    this.completionTokens,
    this.error,
  });

  const AIChunk.text({required ProviderType provider, required String text})
    : this(type: AIChunkType.text, provider: provider, text: text);

  const AIChunk.status({required ProviderType provider, required String text})
    : this(type: AIChunkType.status, provider: provider, text: text);

  const AIChunk.usage({
    required ProviderType provider,
    int? promptTokens,
    int? completionTokens,
  }) : this(
         type: AIChunkType.usage,
         provider: provider,
         promptTokens: promptTokens,
         completionTokens: completionTokens,
       );

  const AIChunk.error({required ProviderType provider, required String error})
    : this(type: AIChunkType.error, provider: provider, error: error);

  const AIChunk.done({required ProviderType provider})
    : this(type: AIChunkType.done, provider: provider);

  final AIChunkType type;
  final ProviderType provider;
  final String text;
  final int? promptTokens;
  final int? completionTokens;
  final String? error;
}
