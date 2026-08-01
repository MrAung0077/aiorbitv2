import '../mock_ai_provider.dart';
import '../provider_type.dart';

class OllamaProvider extends MockAIProvider {
  const OllamaProvider({super.configured = false})
    : super(type: ProviderType.ollama, displayName: 'Ollama');
}
