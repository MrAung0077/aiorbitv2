import 'package:aiorbit/core/ai/ai_provider_registry.dart';
import 'package:aiorbit/core/ai/mock_ai_provider.dart';
import 'package:aiorbit/core/ai/providers/ovexiq_backend_provider.dart';
import 'package:aiorbit/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry follows the configured provider mode', () {
    final providers = AIProviderRegistry.providers();

    expect(providers, hasLength(1));
    if (AppConfig.useMockProviders) {
      expect(providers.single, isA<MockAIProvider>());
    } else {
      expect(providers.single, isA<OvexiqBackendProvider>());
    }
  });
}
