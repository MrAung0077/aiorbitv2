import 'ai_provider.dart';
import 'providers/claude_provider.dart';
import 'providers/deepseek_provider.dart';
import 'providers/gemini_provider.dart';
import 'providers/grok_provider.dart';
import 'providers/mistral_provider.dart';
import 'providers/ollama_provider.dart';
import 'providers/openai_provider.dart';

class AIProviderRegistry {
  const AIProviderRegistry._();

  static List<AIProvider> mockProviders() {
    return const <AIProvider>[
      OpenAIProvider(),
      GeminiProvider(),
      ClaudeProvider(),
      DeepSeekProvider(),
      GrokProvider(),
      MistralProvider(),
      OllamaProvider(),
    ];
  }
}
