import '../models/mission.dart';
import '../models/mission_intelligence_result.dart';
import '../models/mission_task.dart';
import '../models/task_status.dart';

class MissionIntelligenceService {
  const MissionIntelligenceService();

  MissionIntelligenceResult analyze(Mission mission) {
    final isCompleted = mission.taskProgress.isComplete;
    final hasIncompleteTasks = mission.tasks.any(
      (task) => task.status != TaskStatus.completed,
    );

    return MissionIntelligenceResult(
      hasIncompleteTasks: hasIncompleteTasks,
      nextRecommendedTask: _nextRecommendedTask(mission.tasks),
      requiresUserAction: !isCompleted,
      isCompleted: isCompleted,
    );
  }

  MissionTask? _nextRecommendedTask(List<MissionTask> tasks) {
    final orderedTasks = tasks.indexed.toList(growable: false)
      ..sort((left, right) {
        final orderComparison = left.$2.order.compareTo(right.$2.order);

        return orderComparison != 0
            ? orderComparison
            : left.$1.compareTo(right.$1);
      });

    for (final entry in orderedTasks) {
      if (_isRecommendable(entry.$2.status)) {
        return entry.$2;
      }
    }

    return null;
  }

  bool _isRecommendable(TaskStatus status) {
    return status == TaskStatus.pending || status == TaskStatus.inProgress;
  }
}
