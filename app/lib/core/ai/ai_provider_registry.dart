import 'ai_provider.dart';
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
    final openai = RealOpenAIProvider();
    final gemini = RealGeminiProvider();

    print('=== AI PROVIDER STATUS ===');
    print('OpenAI configured = ${openai.isConfigured}');
    print('Gemini configured = ${gemini.isConfigured}');
    print('==========================');

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
