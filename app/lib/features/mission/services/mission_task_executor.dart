import '../models/mission.dart';
import '../models/mission_task.dart';
import '../models/mission_task_execution.dart';

abstract interface class MissionTaskExecutor {
  Future<MissionTaskExecution> execute({
    required Mission mission,
    required MissionTask task,
  });
}
