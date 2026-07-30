import '../config/app_config.dart';
import 'ai_provider.dart';
import 'mock_ai_provider.dart';
import 'provider_type.dart';
import 'providers/claude_provider.dart';
import 'providers/deepseek_provider.dart';
import 'providers/grok_provider.dart';
import 'providers/mistral_provider.dart';
import 'providers/ollama_provider.dart';
import 'providers/real_gemini_provider.dart';
import 'providers/real_openai_provider.dart';

class AIProviderRegistry {
  const AIProviderRegistry._();

  static List<AIProvider> providers() {
    if (AppConfig.useMockProviders) {
      return <AIProvider>[
        const MockAIProvider(
          type: ProviderType.openAI,
          displayName: 'Ovexiq Mock',
        ),
      ];
    }

    final openai = RealOpenAIProvider();
    final gemini = RealGeminiProvider();

    return <AIProvider>[
      openai,
      gemini,
      const ClaudeProvider(),
      const DeepSeekProvider(),
      const GrokProvider(),
      const MistralProvider(),
      const OllamaProvider(),
    ];
  }
}
