import '../models/mission.dart';
import '../models/mission_suggestion.dart';
import '../services/mission_factory.dart';
import '../services/mission_repository.dart';

class MissionController {
  MissionController({
    required MissionRepository repository,
    MissionFactory? factory,
  }) : _repository = repository,
       _factory = factory ?? const MissionFactory();

  final MissionRepository _repository;
  final MissionFactory _factory;

  Future<Mission> startMission(
    MissionSuggestion suggestion, {
    String? conversationId,
  }) async {
    final mission = _factory.createFromSuggestion(
      suggestion: suggestion,
      conversationId: conversationId,
    );

    await _repository.saveMission(mission);

    return mission;
  }

  Future<List<Mission>> getMissions() {
    return _repository.getAllMissions();
  }

  Future<Mission?> getMission(String id) {
    return _repository.getMission(id);
  }

  Future<void> deleteMission(String id) {
    return _repository.deleteMission(id);
  }
}
