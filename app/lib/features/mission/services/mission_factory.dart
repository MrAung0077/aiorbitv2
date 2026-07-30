import '../models/mission.dart';
import '../models/mission_status.dart';
import '../models/mission_suggestion.dart';
import '../models/mission_task.dart';
import '../models/task_status.dart';

class MissionFactory {
  const MissionFactory();

  Mission createFromSuggestion({
    required MissionSuggestion suggestion,
    String? conversationId,
  }) {
    final createdAt = DateTime.now();
    final missionId = createdAt.microsecondsSinceEpoch.toString();

    final tasks = suggestion.plannedSteps.indexed
        .map((entry) {
          final index = entry.$1;
          final step = entry.$2;

          return MissionTask(
            id: '${missionId}_task_$index',
            missionId: missionId,
            title: step,
            description: step,
            order: index,
            status: TaskStatus.pending,
            taskType: suggestion.category.name,
            createdAt: createdAt,
          );
        })
        .toList(growable: false);

    return Mission(
      id: missionId,
      title: suggestion.title,
      goal: suggestion.goal,
      category: suggestion.category,
      status: MissionStatus.draft,
      createdAt: createdAt,
      updatedAt: createdAt,
      currentTaskIndex: 0,
      progressPercent: 0,
      tasks: tasks,
      conversationId: conversationId,
    );
  }
}
