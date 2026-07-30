import '../models/mission.dart';
import 'mission_repository.dart';

class MemoryMissionRepository implements MissionRepository {
  final Map<String, Mission> _missions = {};

  @override
  Future<void> saveMission(Mission mission) async {
    _missions[mission.id] = mission;
  }

  @override
  Future<Mission?> getMission(String id) async {
    return _missions[id];
  }

  @override
  Future<List<Mission>> getAllMissions() async {
    return _missions.values.toList();
  }

  @override
  Future<void> deleteMission(String id) async {
    _missions.remove(id);
  }
}
