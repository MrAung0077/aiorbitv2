import '../mock_ai_provider.dart';
import '../provider_type.dart';

class GrokProvider extends MockAIProvider {
  const GrokProvider({bool configured = false})
    : super(
        type: ProviderType.grok,
        displayName: 'Grok',
        configured: configured,
      );
}
