import 'mission_task.dart';

class MissionIntelligenceResult {
  const MissionIntelligenceResult({
    required this.hasIncompleteTasks,
    required this.nextRecommendedTask,
    required this.requiresUserAction,
    required this.isCompleted,
  });

  final bool hasIncompleteTasks;
  final MissionTask? nextRecommendedTask;
  final bool requiresUserAction;
  final bool isCompleted;
}
