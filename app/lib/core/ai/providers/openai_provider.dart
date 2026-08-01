import '../ai_provider_profiles.dart';
import '../mock_ai_provider.dart';
import '../provider_type.dart';

class OpenAIProvider extends MockAIProvider {
  const OpenAIProvider({super.configured = true})
    : super(
        metadata: AIProviderProfiles.openAI,
        type: ProviderType.openAI,
        displayName: 'OpenAI',
      );
}
