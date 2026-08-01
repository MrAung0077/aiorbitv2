import '../mock_ai_provider.dart';
import '../provider_type.dart';

class DeepSeekProvider extends MockAIProvider {
  const DeepSeekProvider({super.configured = false})
    : super(type: ProviderType.deepSeek, displayName: 'DeepSeek');
}
