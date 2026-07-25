import '../mock_ai_provider.dart';
import '../provider_type.dart';

class MistralProvider extends MockAIProvider {
  const MistralProvider({bool configured = false})
    : super(
        type: ProviderType.mistral,
        displayName: 'Mistral',
        configured: configured,
      );
}
