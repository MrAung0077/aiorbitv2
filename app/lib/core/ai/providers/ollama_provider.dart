import '../mock_ai_provider.dart';
import '../provider_type.dart';

class OllamaProvider extends MockAIProvider {
  const OllamaProvider({bool configured = true})
    : super(
        type: ProviderType.ollama,
        displayName: 'Ollama',
        configured: configured,
      );
}
