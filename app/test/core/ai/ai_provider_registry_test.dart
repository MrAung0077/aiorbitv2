import 'package:aiorbit/core/ai/ai_message.dart';
import 'package:aiorbit/core/ai/ai_provider_registry.dart';
import 'package:aiorbit/core/ai/ai_request.dart';
import 'package:aiorbit/core/ai/mock_ai_provider.dart';
import 'package:aiorbit/core/ai/providers/ovexiq_backend_api_client.dart';
import 'package:aiorbit/core/ai/providers/ovexiq_backend_provider.dart';
import 'package:aiorbit/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry follows the configured provider mode', () {
    final providers = AIProviderRegistry.providers();

    expect(providers, hasLength(1));
    if (AppConfig.useMockProviders) {
      expect(providers.single, isA<MockAIProvider>());
      expect(providers.single, isNot(isA<OvexiqBackendProvider>()));
    } else {
      expect(providers.single, isA<OvexiqBackendProvider>());
      expect(providers.single, isNot(isA<MockAIProvider>()));
    }
  });

  test('missing gateway configuration fails safely', () async {
    final provider = OvexiqBackendProvider(
      OvexiqBackendApiClient(baseUrl: '', betaAccessToken: ''),
    );
    addTearDown(provider.close);

    expect(provider.isConfigured, isFalse);

    await expectLater(
      provider.complete(
        const AIRequest(
          messages: <AIMessage>[
            AIMessage(role: AIMessageRole.user, content: 'Test request'),
          ],
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'safe message',
          contains('Ovexiq AI is not configured.'),
        ),
      ),
    );
  });
}
