import 'package:aiorbit/core/ai/ai_chunk.dart';
import 'package:aiorbit/core/ai/ai_provider.dart';
import 'package:aiorbit/core/ai/ai_provider_metadata.dart';
import 'package:aiorbit/core/ai/ai_request.dart';
import 'package:aiorbit/core/ai/ai_response.dart';
import 'package:aiorbit/core/ai/ai_router.dart';
import 'package:aiorbit/core/ai/ai_service.dart';
import 'package:aiorbit/core/ai/provider_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'complete falls back when selected provider throws before completion',
    () async {
      final gemini = _TestAIProvider(
        type: ProviderType.gemini,
        displayName: 'Gemini',
        isConfigured: true,
        completeHandler: (_) async {
          throw StateError('Gemini failed');
        },
      );

      final openAI = _TestAIProvider(
        type: ProviderType.openAI,
        displayName: 'OpenAI',
        isConfigured: true,
        completeHandler: (_) async {
          return const AIResponse(
            provider: ProviderType.openAI,
            content: 'OpenAI fallback result',
          );
        },
      );

      final service = AIService(
        router: AIRouter(
          providers: <AIProvider>[
            gemini,
            openAI,
          ],
        ),
      );

      final response = await service.complete(
        AIRequest.fromPrompt(
          prompt: 'Research the latest AI market trends',
        ),
      );

      expect(response.provider, ProviderType.openAI);
      expect(response.content, 'OpenAI fallback result');

      expect(gemini.completeCallCount, 1);
      expect(openAI.completeCallCount, 1);
    },
  );

  test(
    'stream switches provider when selected provider fails before text',
    () async {
      final gemini = _TestAIProvider(
        type: ProviderType.gemini,
        displayName: 'Gemini',
        isConfigured: true,
        streamHandler: (_) async* {
          yield const AIChunk.error(
            provider: ProviderType.gemini,
            error: 'Gemini unavailable',
          );
        },
      );

      final openAI = _TestAIProvider(
        type: ProviderType.openAI,
        displayName: 'OpenAI',
        isConfigured: true,
        streamHandler: (_) async* {
          yield const AIChunk.text(
            provider: ProviderType.openAI,
            text: 'Fallback stream result',
          );

          yield const AIChunk.done(
            provider: ProviderType.openAI,
          );
        },
      );

      final service = AIService(
        router: AIRouter(
          providers: <AIProvider>[
            gemini,
            openAI,
          ],
        ),
      );

      final chunks = await service
          .stream(
            AIRequest.fromPrompt(
              prompt: 'Research the latest AI market trends',
            ),
          )
          .toList();

      expect(gemini.streamCallCount, 1);
      expect(openAI.streamCallCount, 1);

      expect(
        chunks.any(
          (chunk) =>
              chunk.type == AIChunkType.status &&
              chunk.provider == ProviderType.openAI &&
              chunk.text == 'Switching to OpenAI...',
        ),
        isTrue,
      );

      expect(
        chunks.any(
          (chunk) =>
              chunk.type == AIChunkType.text &&
              chunk.provider == ProviderType.openAI &&
              chunk.text == 'Fallback stream result',
        ),
        isTrue,
      );

      expect(
        chunks.any(
          (chunk) =>
              chunk.type == AIChunkType.done &&
              chunk.provider == ProviderType.openAI,
        ),
        isTrue,
      );

      expect(
        chunks.where((chunk) => chunk.type == AIChunkType.error),
        isEmpty,
      );
    },
  );

  test(
    'stream does not switch providers after text has already been emitted',
    () async {
      final gemini = _TestAIProvider(
        type: ProviderType.gemini,
        displayName: 'Gemini',
        isConfigured: true,
        streamHandler: (_) async* {
          yield const AIChunk.text(
            provider: ProviderType.gemini,
            text: 'Partial Gemini result',
          );

          throw StateError('Gemini failed after text');
        },
      );

      final openAI = _TestAIProvider(
        type: ProviderType.openAI,
        displayName: 'OpenAI',
        isConfigured: true,
        streamHandler: (_) async* {
          yield const AIChunk.text(
            provider: ProviderType.openAI,
            text: 'This should never be used',
          );
        },
      );

      final service = AIService(
        router: AIRouter(
          providers: <AIProvider>[
            gemini,
            openAI,
          ],
        ),
      );

      final chunks = await service
          .stream(
            AIRequest.fromPrompt(
              prompt: 'Research the latest AI market trends',
            ),
          )
          .toList();

      expect(gemini.streamCallCount, 1);
      expect(openAI.streamCallCount, 0);

      expect(
        chunks.any(
          (chunk) =>
              chunk.type == AIChunkType.text &&
              chunk.provider == ProviderType.gemini &&
              chunk.text == 'Partial Gemini result',
        ),
        isTrue,
      );

      expect(
        chunks.any(
          (chunk) =>
              chunk.type == AIChunkType.error &&
              chunk.provider == ProviderType.gemini,
        ),
        isTrue,
      );

      expect(
        chunks.any(
          (chunk) => chunk.provider == ProviderType.openAI,
        ),
        isFalse,
      );
    },
  );
}

typedef _CompleteHandler = Future<AIResponse> Function(
  AIRequest request,
);

typedef _StreamHandler = Stream<AIChunk> Function(
  AIRequest request,
);

class _TestAIProvider implements AIProvider {
  _TestAIProvider({
    required this.type,
    required this.displayName,
    required this.isConfigured,
    this.isSupported = true,
    _CompleteHandler? completeHandler,
    _StreamHandler? streamHandler,
  })  : _completeHandler = completeHandler,
        _streamHandler = streamHandler;

  @override
  final ProviderType type;

  @override
  final String displayName;

  @override
  final bool isConfigured;

  final bool isSupported;

  final _CompleteHandler? _completeHandler;
  final _StreamHandler? _streamHandler;

  int completeCallCount = 0;
  int streamCallCount = 0;

  @override
  AIProviderMetadata get metadata => throw UnimplementedError();

  @override
  bool supports(AIRequest request) => isSupported;

  @override
  Future<AIResponse> complete(AIRequest request) {
    completeCallCount += 1;

    final handler = _completeHandler;

    if (handler == null) {
      throw StateError(
        '$displayName complete handler was not configured.',
      );
    }

    return handler(request);
  }

  @override
  Stream<AIChunk> stream(AIRequest request) {
    streamCallCount += 1;

    final handler = _streamHandler;

    if (handler == null) {
      throw StateError(
        '$displayName stream handler was not configured.',
      );
    }

    return handler(request);
  }
}