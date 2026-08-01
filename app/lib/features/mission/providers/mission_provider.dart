import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/mission_controller.dart';
import '../models/mission.dart';
import '../services/memory_mission_repository.dart';
import '../services/mission_repository.dart';

final missionRepositoryProvider = Provider<MissionRepository>((ref) {
  return MemoryMissionRepository();
});

final missionControllerProvider = Provider<MissionController>((ref) {
  return MissionController(repository: ref.watch(missionRepositoryProvider));
});

final linkedMissionProvider = FutureProvider.autoDispose
    .family<Mission?, String>((ref, conversationId) {
      return ref
          .watch(missionControllerProvider)
          .getMissionForConversation(conversationId);
    });
