import 'ai_capability.dart';
import 'ai_provider_metadata.dart';

class AIProviderProfiles {
  const AIProviderProfiles._();

  static const openAI = AIProviderMetadata(
    supportedTasks: {
      AITaskType.generalChat,
      AITaskType.coding,
      AITaskType.translation,
      AITaskType.summarization,
      AITaskType.imageGeneration,
      AITaskType.imageAnalysis,
      AITaskType.documentAnalysis,
    },
    supportsStreaming: true,
    supportsVision: true,
    supportsTools: true,
    supportsJson: true,
    qualityScore: 95,
    speedScore: 88,
    costScore: 65,
  );

  static const gemini = AIProviderMetadata(
    supportedTasks: {
      AITaskType.generalChat,
      AITaskType.coding,
      AITaskType.translation,
      AITaskType.summarization,
      AITaskType.imageGeneration,
      AITaskType.imageAnalysis,
      AITaskType.documentAnalysis,
    },
    supportsStreaming: true,
    supportsVision: true,
    supportsTools: true,
    supportsJson: true,
    qualityScore: 92,
    speedScore: 90,
    costScore: 85,
  );
}
