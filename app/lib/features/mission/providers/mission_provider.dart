import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../../core/database/isar_service.dart';
import '../controllers/mission_controller.dart';
import '../models/mission.dart';
import '../services/isar_mission_repository.dart';
import '../services/isar_mission_task_execution_repository.dart';
import '../services/mission_repository.dart';
import '../services/mission_task_execution_repository.dart';

final sharedIsarProvider = Provider<Isar>((ref) {
  return IsarService.instance;
});

final missionRepositoryProvider = Provider<MissionRepository>((ref) {
  return IsarMissionRepository(isar: ref.watch(sharedIsarProvider));
});

final missionTaskExecutionRepositoryProvider =
    Provider<MissionTaskExecutionRepository>((ref) {
      return IsarMissionTaskExecutionRepository(
        isar: ref.watch(sharedIsarProvider),
      );
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
