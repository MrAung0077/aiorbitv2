import '../mock_ai_provider.dart';
import '../provider_type.dart';

class MistralProvider extends MockAIProvider {
  const MistralProvider({super.configured = false})
    : super(type: ProviderType.mistral, displayName: 'Mistral');
}
