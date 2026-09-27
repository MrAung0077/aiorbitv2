import '../../../core/ai/ai_service.dart';
import '../../../core/ai/ai_request.dart';
import '../../../core/ai/ai_request_failure.dart';
import '../../../core/text/burmese_mission_output_quality_gate.dart';
import '../../../core/text/response_language.dart';
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
    BurmeseMissionOutputQualityGate? outputQualityGate,
    DateTime Function()? clock,
  }) : _requestBuilder = requestBuilder ?? const MissionTaskAIRequestBuilder(),
       _outputQualityGate =
           outputQualityGate ?? const BurmeseMissionOutputQualityGate(),
       _clock = clock ?? DateTime.now;

  final AIService _aiService;
  final MissionTaskAIRequestBuilder _requestBuilder;
  final BurmeseMissionOutputQualityGate _outputQualityGate;
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
      final outputText = await _acceptedOutput(
        mission: mission,
        task: task,
        request: request,
        output: response.content,
      );

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

  Future<String> _acceptedOutput({
    required Mission mission,
    required MissionTask task,
    required AIRequest request,
    required String output,
  }) async {
    final outputText = output.trim();

    if (outputText.isEmpty) {
      throw StateError('Task execution returned empty output.');
    }

    if (request.responseLanguage != ResponseLanguage.burmese) {
      return outputText;
    }

    final assessment = _outputQualityGate.assess(
      outputText,
      allowUnexpectedForeignScripts: _allowsForeignScripts(mission, task),
    );
    if (assessment.isAcceptable) {
      return outputText;
    }

    final repairResponse = await _aiService.complete(
      _requestBuilder.buildQualityRepair(
        mission: mission,
        task: task,
        rejectedOutput: outputText,
      ),
    );
    final repairedOutput = repairResponse.content.trim();
    final repairedAssessment = _outputQualityGate.assess(
      repairedOutput,
      allowUnexpectedForeignScripts: _allowsForeignScripts(mission, task),
    );

    if (repairedOutput.isNotEmpty && repairedAssessment.isAcceptable) {
      return repairedOutput;
    }

    final qualityFailure = const AIRequestFailure(
      category: AIRequestFailureCategory.invalidResponse,
      retryable: true,
      executionStage: 'mission_output_quality',
      diagnosticReason: 'burmese_quality_repair_invalid',
    );
    // This is the terminal Mission failure boundary for a completed provider
    // response that did not meet the deterministic Burmese quality contract.
    // It contains only fixed metadata, never task content.
    // ignore: avoid_print
    print(qualityFailure.releaseDiagnosticLine);
    throw qualityFailure;
  }

  bool _allowsForeignScripts(Mission mission, MissionTask task) {
    final context = <String>[
      mission.goal,
      mission.userContext ?? '',
      task.inputContext ?? '',
    ].join('\n');

    return RegExp(
      r'\b(?:write|reply|respond|translate|return|provide)\b[^\n.]{0,48}'
      r'\b(?:in\s+)?(?:armenian|korean|chinese|japanese|thai|arabic)\b|'
      r'(?:အာမေးနီးယား|ကိုရီးယား|တရုတ်|ဂျပန်|ထိုင်း|အာရဗီ)'
      r'(?:လို|ဘာသာ(?:နဲ့|ဖြင့်)?|စာ)?\s*(?:ရေး|ပြော|ဖြေ|ဘာသာပြန်|ပေး)',
      caseSensitive: false,
    ).hasMatch(context);
  }

  String _failureMessage(Object error) {
    final message = error.toString().trim();

    if (message.isEmpty) {
      return 'Task execution failed.';
    }

    return message;
  }
}
