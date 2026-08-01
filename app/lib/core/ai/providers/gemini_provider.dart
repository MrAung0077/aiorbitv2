import '../mock_ai_provider.dart';
import '../provider_type.dart';

class GeminiProvider extends MockAIProvider {
  const GeminiProvider({super.configured = true})
    : super(type: ProviderType.gemini, displayName: 'Gemini');
}
