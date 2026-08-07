import 'package:aiorbit/core/ai/ai_chunk.dart';
import 'package:aiorbit/core/ai/ai_provider.dart';
import 'package:aiorbit/core/ai/ai_provider_metadata.dart';
import 'package:aiorbit/core/ai/ai_request.dart';
import 'package:aiorbit/core/ai/ai_response.dart';
import 'package:aiorbit/core/ai/ai_router.dart';
import 'package:aiorbit/core/ai/provider_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preferred configured provider is selected when supported', () {
    final openAI = _TestAIProvider(
      type: ProviderType.openAI,
      displayName: 'OpenAI',
      isConfigured: true,
    );

    final gemini = _TestAIProvider(
      type: ProviderType.gemini,
      displayName: 'Gemini',
      isConfigured: true,
    );

    final router = AIRouter(
      providers: <AIProvider>[
        openAI,
        gemini,
      ],
    );

    final result = router.route(
      AIRequest.fromPrompt(
        prompt: 'Hello',
        preferredProvider: ProviderType.gemini,
      ),
    );

    expect(result.provider, same(gemini));
  });

  test('research routes to Gemini when Gemini is available', () {
    final openAI = _TestAIProvider(
      type: ProviderType.openAI,
      displayName: 'OpenAI',
      isConfigured: true,
    );

    final gemini = _TestAIProvider(
      type: ProviderType.gemini,
      displayName: 'Gemini',
      isConfigured: true,
    );

    final router = AIRouter(
      providers: <AIProvider>[
        openAI,
        gemini,
      ],
    );

    final result = router.route(
      AIRequest.fromPrompt(
        prompt: 'Research the latest AI market trends',
      ),
    );

    expect(result.provider, same(gemini));
  });

  test(
    'falls back to another available provider when task and default providers are unavailable',
    () {
      final gemini = _TestAIProvider(
        type: ProviderType.gemini,
        displayName: 'Gemini',
        isConfigured: false,
      );

      final openAI = _TestAIProvider(
        type: ProviderType.openAI,
        displayName: 'OpenAI',
        isConfigured: false,
      );

      final claude = _TestAIProvider(
        type: ProviderType.claude,
        displayName: 'Claude',
        isConfigured: true,
      );

      final router = AIRouter(
        providers: <AIProvider>[
          gemini,
          openAI,
          claude,
        ],
      );

      final result = router.route(
        AIRequest.fromPrompt(
          prompt: 'Research the latest AI market trends',
        ),
      );

      expect(result.provider, same(claude));
    },
  );

  test(
    'skips a configured task provider when it does not support the request',
    () {
      final gemini = _TestAIProvider(
        type: ProviderType.gemini,
        displayName: 'Gemini',
        isConfigured: true,
        isSupported: false,
      );

      final openAI = _TestAIProvider(
        type: ProviderType.openAI,
        displayName: 'OpenAI',
        isConfigured: true,
      );

      final router = AIRouter(
        providers: <AIProvider>[
          gemini,
          openAI,
        ],
      );

      final result = router.route(
        AIRequest.fromPrompt(
          prompt: 'Research the latest AI market trends',
        ),
      );

      expect(result.provider, same(openAI));
    },
  );
}

class _TestAIProvider implements AIProvider {
  const _TestAIProvider({
    required this.type,
    required this.displayName,
    required this.isConfigured,
    this.isSupported = true,
  });

  @override
  final ProviderType type;

  @override
  final String displayName;

  @override
  final bool isConfigured;

  final bool isSupported;

  @override
  AIProviderMetadata get metadata => throw UnimplementedError();

  @override
  bool supports(AIRequest request) => isSupported;

  @override
  Future<AIResponse> complete(AIRequest request) {
    throw UnimplementedError();
  }

  @override
  Stream<AIChunk> stream(AIRequest request) {
    throw UnimplementedError();
  }
}