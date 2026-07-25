import 'ai_capability.dart';

class AITaskAnalysisResult {
  const AITaskAnalysisResult({
    required this.task,
    required this.complexity,
    required this.reason,
  });

  final AITaskType task;
  final TaskComplexity complexity;
  final String reason;
}

enum TaskComplexity { low, medium, high }
