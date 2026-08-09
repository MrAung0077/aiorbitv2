import '../config/app_config.dart';
import 'ai_provider.dart';
import 'mock_ai_provider.dart';
import 'provider_type.dart';
import 'providers/ovexiq_backend_api_client.dart';
import 'providers/ovexiq_backend_provider.dart';

class AIProviderRegistry {
  const AIProviderRegistry._();

  static List<AIProvider> providers() {
    if (AppConfig.useMockProviders) {
      return <AIProvider>[
        const MockAIProvider(
          type: ProviderType.openAI,
          displayName: 'Ovexiq Mock',
        ),
      ];
    }

    return <AIProvider>[
      OvexiqBackendProvider(
        OvexiqBackendApiClient(
          baseUrl: AppConfig.ovexiqApiBaseUrl,
          betaAccessToken: AppConfig.ovexiqBetaAccessToken,
        ),
      ),
    ];
  }
}
