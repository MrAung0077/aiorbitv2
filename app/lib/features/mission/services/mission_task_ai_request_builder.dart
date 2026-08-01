import '../../../core/ai/ai_request.dart';
import '../models/mission.dart';
import '../models/mission_task.dart';

class MissionTaskAIRequestBuilder {
  const MissionTaskAIRequestBuilder();

  AIRequest build({required Mission mission, required MissionTask task}) {
    if (task.missionId != mission.id) {
      throw ArgumentError.value(
        task.missionId,
        'task.missionId',
        'Task does not belong to the mission.',
      );
    }

    final inputContext = task.inputContext?.trim();
    final promptLines = <String>[
      'Complete this mission task.',
      '',
      'Title: ${task.title.trim()}',
      'Description: ${task.description.trim()}',
      'Task type: ${task.taskType.trim()}',
      if (inputContext != null && inputContext.isNotEmpty)
        'Input context: $inputContext',
    ];

    return AIRequest.fromPrompt(
      prompt: promptLines.join('\n'),
      metadata: <String, Object?>{
        'missionId': mission.id,
        'taskId': task.id,
        'taskType': task.taskType,
      },
    );
  }
}
