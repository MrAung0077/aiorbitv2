import '../../../core/ai/ai_service.dart';
import '../models/execution_status.dart';
import '../models/mission.dart';
import '../models/mission_execution.dart';
import '../models/mission_task.dart';
import '../models/mission_task_execution.dart';
import 'mission_task_ai_request_builder.dart';
import 'mission_task_executor.dart';

class AIServiceMissionTaskExecutor implements MissionTaskExecutor {
  AIServiceMissionTaskExecutor(
    this._aiService, {
    MissionTaskAIRequestBuilder? requestBuilder,
    DateTime Function()? clock,
  }) : _requestBuilder = requestBuilder ?? const MissionTaskAIRequestBuilder(),
       _clock = clock ?? DateTime.now;

  final AIService _aiService;
  final MissionTaskAIRequestBuilder _requestBuilder;
  final DateTime Function() _clock;

  @override
  Future<MissionTaskExecution> execute({
    required Mission mission,
    required MissionTask task,
  }) async {
    final request = _requestBuilder.build(mission: mission, task: task);
    final startedAt = _clock();
    final runningExecution = MissionExecution(
      id: 'task-${mission.id}-${task.id}-${startedAt.microsecondsSinceEpoch}',
      missionId: mission.id,
      status: ExecutionStatus.running,
      progress: 0,
      startedAt: startedAt,
      currentTaskId: task.id,
    );

    try {
      final response = await _aiService.complete(request);
      final outputText = response.content.trim();

      if (outputText.isEmpty) {
        throw StateError('Task execution returned empty output.');
      }

      final finishedAt = _clock();

      return MissionTaskExecution(
        execution: runningExecution.copyWith(
          status: ExecutionStatus.completed,
          progress: 1,
          finishedAt: finishedAt,
        ),
        outputText: outputText,
      );
    } catch (error) {
      final finishedAt = _clock();

      return MissionTaskExecution(
        execution: runningExecution.copyWith(
          status: ExecutionStatus.failed,
          finishedAt: finishedAt,
        ),
        failureMessage: _failureMessage(error),
      );
    }
  }

  String _failureMessage(Object error) {
    final message = error.toString().trim();

    if (message.isEmpty) {
      return 'Task execution failed.';
    }

    return message;
  }
}
