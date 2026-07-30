import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/startup_state.dart';
import '../services/app_initializer.dart';

final appInitializerProvider = Provider<AppInitializer>((ref) {
  return const AppInitializer();
});

final startupControllerProvider =
    StateNotifierProvider<StartupController, StartupState>((ref) {
      final initializer = ref.watch(appInitializerProvider);

      return StartupController(initializer);
    });

class StartupController extends StateNotifier<StartupState> {
  StartupController(this._initializer) : super(const StartupState());

  final AppInitializer _initializer;

  bool _hasStarted = false;

  Future<void> initialize() async {
    if (_hasStarted) {
      return;
    }

    _hasStarted = true;

    await _initializer.initialize(
      onStateChanged: (nextState) {
        state = nextState;
      },
    );
  }

  Future<void> retry() async {
    _hasStarted = false;

    state = const StartupState(
      stage: StartupStage.preparing,
      progress: 0,
      message: 'Preparing Ovexiq',
    );

    await initialize();
  }
}
