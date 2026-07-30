import '../../../core/database/isar_service.dart';
import '../models/startup_state.dart';

typedef StartupStateListener = void Function(StartupState state);

class AppInitializer {
  const AppInitializer();

  Future<void> initialize({
    required StartupStateListener onStateChanged,
  }) async {
    try {
      onStateChanged(
        const StartupState(
          stage: StartupStage.preparing,
          progress: 0.1,
          message: 'Preparing Ovexiq',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 250));

      onStateChanged(
        const StartupState(
          stage: StartupStage.loadingDatabase,
          progress: 0.35,
          message: 'Loading your workspace',
        ),
      );

      await IsarService.initialize();

      onStateChanged(
        const StartupState(
          stage: StartupStage.loadingSettings,
          progress: 0.6,
          message: 'Applying your preferences',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));

      onStateChanged(
        const StartupState(
          stage: StartupStage.preparingWorkspace,
          progress: 0.85,
          message: 'Preparing your AI workspace',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 250));

      onStateChanged(
        const StartupState(
          stage: StartupStage.ready,
          progress: 1,
          message: 'Ready',
        ),
      );
    } catch (error) {
      onStateChanged(
        StartupState(
          stage: StartupStage.failed,
          progress: 1,
          message: 'Unable to start Ovexiq',
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
