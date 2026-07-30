import '../models/mission.dart';

abstract class MissionRepository {
  Future<void> saveMission(Mission mission);

  Future<Mission?> getMission(String id);

  Future<List<Mission>> getAllMissions();

  Future<void> deleteMission(String id);
}
