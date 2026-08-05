import '../models/mission_task_execution.dart';

abstract class MissionTaskExecutionRepository {
  Future<void> saveExecution(MissionTaskExecution execution);

  Future<MissionTaskExecution?> getExecution({
    required String missionId,
    required String taskId,
  });

  Future<List<MissionTaskExecution>> getExecutionsForMission(String missionId);

  Future<void> deleteExecution({
    required String missionId,
    required String taskId,
  });

  Future<void> deleteExecutionsForMission(String missionId);
}
