import '../mock_ai_provider.dart';
import '../provider_type.dart';

class OpenAIProvider extends MockAIProvider {
  const OpenAIProvider({bool configured = true})
    : super(
        type: ProviderType.openAI,
        displayName: 'OpenAI',
        configured: configured,
      );
}
