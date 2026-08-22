import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/chat_mission_coordinator.dart';
import 'mission_execution_provider.dart';
import 'mission_provider.dart';
import 'mission_task_execution_provider.dart';

final chatMissionCoordinatorProvider = Provider<ChatMissionCoordinator>((ref) {
  return ChatMissionCoordinator(
    missionController: ref.watch(missionControllerProvider),
    restoreExecutions: (missionId) {
      return ref
          .read(missionTaskExecutionProvider.notifier)
          .restoreMissionExecutions(missionId);
    },
    runMission: (missionId) {
      return ref
          .read(missionExecutionProvider.notifier)
          .runMission(missionId: missionId);
    },
  );
});
