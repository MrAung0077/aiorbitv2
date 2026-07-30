enum StartupStage {
  preparing,
  loadingDatabase,
  loadingSettings,
  preparingWorkspace,
  ready,
  failed,
}

class StartupState {
  const StartupState({
    this.stage = StartupStage.preparing,
    this.progress = 0,
    this.message = 'Preparing Ovexiq',
    this.errorMessage,
  });

  final StartupStage stage;
  final double progress;
  final String message;
  final String? errorMessage;

  bool get isReady => stage == StartupStage.ready;

  bool get hasError => stage == StartupStage.failed;

  StartupState copyWith({
    StartupStage? stage,
    double? progress,
    String? message,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StartupState(
      stage: stage ?? this.stage,
      progress: (progress ?? this.progress).clamp(0.0, 1.0),
      message: message ?? this.message,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
