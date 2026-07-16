import '../models/router_decision.dart';

class RouterPreviewService {
  const RouterPreviewService();

  RouterDecision analyze(String prompt) {
    final text = prompt.toLowerCase();

    if (text.contains('flutter') ||
        text.contains('dart') ||
        text.contains('widget')) {
      return const RouterDecision(
        task: 'Flutter Development',
        reasoning: 'Code generation',
        recommendedAi: 'GPT-5.5',
        complexity: 'Medium',
        confidence: 98,
      );
    }

    if (text.contains('python')) {
      return const RouterDecision(
        task: 'Python Development',
        reasoning: 'Programming',
        recommendedAi: 'GPT-5.5',
        complexity: 'Medium',
        confidence: 96,
      );
    }

    if (text.contains('image') ||
        text.contains('logo') ||
        text.contains('draw')) {
      return const RouterDecision(
        task: 'Image Generation',
        reasoning: 'Visual creation',
        recommendedAi: 'Image Model',
        complexity: 'Low',
        confidence: 99,
      );
    }

    if (text.contains('research') || text.contains('analyze')) {
      return const RouterDecision(
        task: 'Research',
        reasoning: 'Long-form reasoning',
        recommendedAi: 'Reasoning Model',
        complexity: 'High',
        confidence: 94,
      );
    }

    return const RouterDecision(
      task: 'General Assistant',
      reasoning: 'Conversation',
      recommendedAi: 'Auto',
      complexity: 'Low',
      confidence: 75,
    );
  }
}
