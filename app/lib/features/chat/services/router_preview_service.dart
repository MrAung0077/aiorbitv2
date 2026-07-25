import '../models/router_decision.dart';

class RouterPreviewService {
  const RouterPreviewService();

  RouterDecision analyze(String prompt) {
    final String text = prompt.trim().toLowerCase();

    if (_containsAny(text, <String>[
      'flutter',
      'dart',
      'widget',
      'code',
      'coding',
      'program',
      'debug',
      'error',
      'api',
    ])) {
      return const RouterDecision(
        task: 'Software Development',
        reasoning: 'Coding and technical reasoning',
        recommendedAi: 'OpenAI',
        complexity: 'Medium',
        confidence: 97,
      );
    }

    if (_containsAny(text, <String>[
      'research',
      'analyze',
      'analysis',
      'latest',
      'compare',
      'investigate',
    ])) {
      return const RouterDecision(
        task: 'Research',
        reasoning: 'Research and information analysis',
        recommendedAi: 'Gemini',
        complexity: 'High',
        confidence: 94,
      );
    }

    if (_containsAny(text, <String>['translate', 'translation', 'ဘာသာပြန်'])) {
      return const RouterDecision(
        task: 'Translation',
        reasoning: 'Multilingual language processing',
        recommendedAi: 'Gemini',
        complexity: 'Medium',
        confidence: 96,
      );
    }

    if (_containsAny(text, <String>['summarize', 'summary', 'အကျဉ်းချုပ်'])) {
      return const RouterDecision(
        task: 'Summarization',
        reasoning: 'Content understanding and condensation',
        recommendedAi: 'Gemini',
        complexity: 'Medium',
        confidence: 95,
      );
    }

    if (_containsAny(text, <String>[
      'image',
      'logo',
      'draw',
      'picture',
      'illustration',
      'ပုံ',
    ])) {
      return const RouterDecision(
        task: 'Image Generation',
        reasoning: 'Visual content creation',
        recommendedAi: 'OpenAI',
        complexity: 'Medium',
        confidence: 98,
      );
    }

    return const RouterDecision(
      task: 'General Assistant',
      reasoning: 'General conversation and assistance',
      recommendedAi: 'OpenAI',
      complexity: 'Low',
      confidence: 82,
    );
  }

  bool _containsAny(String text, List<String> keywords) {
    for (final String keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }

    return false;
  }
}
