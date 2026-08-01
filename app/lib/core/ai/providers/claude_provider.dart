import '../mock_ai_provider.dart';
import '../provider_type.dart';

class ClaudeProvider extends MockAIProvider {
  const ClaudeProvider({super.configured = false})
    : super(type: ProviderType.claude, displayName: 'Claude');
}
