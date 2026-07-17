enum AITaskType {
  generalChat,
  coding,
  research,
  summarization,
  translation,
  imageGeneration,
  imageAnalysis,
  documentAnalysis,
}

extension AITaskTypeX on AITaskType {
  String get id {
    switch (this) {
      case AITaskType.generalChat:
        return 'general_chat';
      case AITaskType.coding:
        return 'coding';
      case AITaskType.research:
        return 'research';
      case AITaskType.summarization:
        return 'summarization';
      case AITaskType.translation:
        return 'translation';
      case AITaskType.imageGeneration:
        return 'image_generation';
      case AITaskType.imageAnalysis:
        return 'image_analysis';
      case AITaskType.documentAnalysis:
        return 'document_analysis';
    }
  }

  String get displayName {
    switch (this) {
      case AITaskType.generalChat:
        return 'General Chat';
      case AITaskType.coding:
        return 'Coding';
      case AITaskType.research:
        return 'Research';
      case AITaskType.summarization:
        return 'Summarization';
      case AITaskType.translation:
        return 'Translation';
      case AITaskType.imageGeneration:
        return 'Image Generation';
      case AITaskType.imageAnalysis:
        return 'Image Analysis';
      case AITaskType.documentAnalysis:
        return 'Document Analysis';
    }
  }

  bool get requiresVision {
    return this == AITaskType.imageAnalysis;
  }

  bool get producesImage {
    return this == AITaskType.imageGeneration;
  }
}
