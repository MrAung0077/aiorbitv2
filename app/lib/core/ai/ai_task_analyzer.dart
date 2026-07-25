import 'ai_capability.dart';
import 'ai_task_analysis_result.dart';

class AITaskAnalyzer {
  const AITaskAnalyzer();

  AITaskAnalysisResult analyze(String prompt) {
    final text = prompt.toLowerCase();

    if (_containsAny(text, [
      'code',
      'dart',
      'flutter',
      'python',
      'javascript',
      'bug',
      'error',
    ])) {
      return const AITaskAnalysisResult(
        task: AITaskType.coding,
        complexity: TaskComplexity.medium,
        reason: 'Programming related request detected.',
      );
    }

    if (_containsAny(text, ['research', 'compare', 'latest', 'analyze'])) {
      return const AITaskAnalysisResult(
        task: AITaskType.research,
        complexity: TaskComplexity.high,
        reason: 'Research request detected.',
      );
    }

    if (_containsAny(text, ['translate', 'translation', 'translate to'])) {
      return const AITaskAnalysisResult(
        task: AITaskType.translation,
        complexity: TaskComplexity.low,
        reason: 'Translation request detected.',
      );
    }

    return const AITaskAnalysisResult(
      task: AITaskType.generalChat,
      complexity: TaskComplexity.low,
      reason: 'General conversation detected.',
    );
  }

  bool _containsAny(String text, List<String> words) {
    return words.any(text.contains);
  }
}
