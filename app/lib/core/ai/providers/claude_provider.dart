import '../mock_ai_provider.dart';
import '../provider_type.dart';

class ClaudeProvider extends MockAIProvider {
  const ClaudeProvider({bool configured = false})
    : super(
        type: ProviderType.claude,
        displayName: 'Claude',
        configured: configured,
      );
}
