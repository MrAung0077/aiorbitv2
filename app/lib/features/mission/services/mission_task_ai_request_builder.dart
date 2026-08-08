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

    final missionGoal = mission.goal.trim();
    final userContext = mission.userContext?.trim();
    final inputContext = task.inputContext?.trim();

    final promptLines = <String>[
      'Complete this mission task.',
      '',
      if (missionGoal.isNotEmpty) 'Mission goal: $missionGoal',
      if (userContext != null && userContext.isNotEmpty)
        'User context: $userContext',
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
        'missionGoal': missionGoal,
        'missionCategory': mission.category.name,
        if (userContext != null && userContext.isNotEmpty)
          'userContext': userContext,
      },
    );
  }
}
