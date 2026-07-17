import 'ai_capability.dart';

class AIProviderMetadata {
  const AIProviderMetadata({
    required this.supportedTasks,
    this.supportsStreaming = true,
    this.supportsVision = false,
    this.supportsTools = false,
    this.supportsJson = false,
    this.qualityScore = 50,
    this.speedScore = 50,
    this.costScore = 50,
  });

  final Set<AITaskType> supportedTasks;

  final bool supportsStreaming;
  final bool supportsVision;
  final bool supportsTools;
  final bool supportsJson;

  /// Higher is better (0–100)
  final int qualityScore;

  /// Higher is faster (0–100)
  final int speedScore;

  /// Higher is cheaper (0–100)
  final int costScore;
}
