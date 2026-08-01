import 'package:aiorbit/core/ai/ai_capability.dart';
import 'package:aiorbit/core/ai/ai_chunk.dart';
import 'package:aiorbit/core/ai/ai_message.dart';
import 'package:aiorbit/core/ai/ai_provider.dart';
import 'package:aiorbit/core/ai/ai_provider_metadata.dart';
import 'package:aiorbit/core/ai/ai_request.dart';
import 'package:aiorbit/core/ai/ai_response.dart';
import 'package:aiorbit/core/ai/ai_router.dart';
import 'package:aiorbit/core/ai/ai_service.dart';
import 'package:aiorbit/core/ai/provider_type.dart';
import 'package:aiorbit/features/mission/models/execution_status.dart';
import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:aiorbit/features/mission/services/ai_service_mission_task_executor.dart';
import 'package:aiorbit/features/mission/services/mission_task_ai_request_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final startedAt = DateTime(2026, 2, 2, 10);
  final finishedAt = DateTime(2026, 2, 2, 10, 3);

  test('MissionTask is converted to a provider-agnostic AI request', () {
    final mission = _mission();
    final request = const MissionTaskAIRequestBuilder().build(
      mission: mission,
      task: mission.tasks.single,
    );

    expect(request.messages, hasLength(1));
    expect(request.messages.single.role, AIMessageRole.user);
    expect(
      request.messages.single.content,
      'Complete this mission task.\n'
      '\n'
      'Title: Research sources\n'
      'Description: Find credible primary sources.\n'
      'Task type: research\n'
      'Input context: Focus on official documentation.',
    );
    expect(request.preferredProvider, isNull);
    expect(request.model, isNull);
    expect(request.metadata, <String, Object?>{
      'missionId': 'mission',
      'taskId': 'task',
      'taskType': 'research',
    });
  });

  test('successful AI output completes task execution', () async {
    final mission = _mission();
    final provider = _RecordingAIProvider(
      response: const AIResponse(
        provider: ProviderType.openAI,
        content: 'Provider-agnostic result',
      ),
    );
    final executor = AIServiceMissionTaskExecutor(
      _aiService(provider),
      clock: _clock(startedAt, finishedAt),
    );

    final result = await executor.execute(
      mission: mission,
      task: mission.tasks.single,
    );

    expect(provider.receivedRequest, isNotNull);
    expect(result.status, ExecutionStatus.completed);
    expect(result.missionId, mission.id);
    expect(result.taskId, mission.tasks.single.id);
    expect(result.startedAt, startedAt);
    expect(result.finishedAt, finishedAt);
    expect(result.outputText, 'Provider-agnostic result');
    expect(result.failureMessage, isNull);
    expect(result.execution.progress, 1);
  });

  test('whitespace-only AI output fails task execution', () async {
    final mission = _mission();
    final provider = _RecordingAIProvider(
      response: const AIResponse(
        provider: ProviderType.openAI,
        content: '  \n\t ',
      ),
    );
    final executor = AIServiceMissionTaskExecutor(
      _aiService(provider),
      clock: _clock(startedAt, finishedAt),
    );

    final result = await executor.execute(
      mission: mission,
      task: mission.tasks.single,
    );

    expect(result.status, ExecutionStatus.failed);
    expect(result.missionId, mission.id);
    expect(result.taskId, mission.tasks.single.id);
    expect(result.startedAt, startedAt);
    expect(result.finishedAt, finishedAt);
    expect(result.outputText, isNull);
    expect(result.failureMessage, contains('empty output'));
  });

  test('AI failure returns failed execution with useful information', () async {
    final mission = _mission();
    final provider = _RecordingAIProvider(error: StateError('stub AI failure'));
    final executor = AIServiceMissionTaskExecutor(
      _aiService(provider),
      clock: _clock(startedAt, finishedAt),
    );

    final result = await executor.execute(
      mission: mission,
      task: mission.tasks.single,
    );

    expect(result.status, ExecutionStatus.failed);
    expect(result.missionId, mission.id);
    expect(result.taskId, mission.tasks.single.id);
    expect(result.startedAt, startedAt);
    expect(result.finishedAt, finishedAt);
    expect(result.outputText, isNull);
    expect(result.failureMessage, contains('stub AI failure'));
    expect(result.execution.progress, 0);
  });

  test('execution does not mutate task status or mission progress', () async {
    final mission = _mission();
    final task = mission.tasks.single;
    final provider = _RecordingAIProvider(
      response: const AIResponse(
        provider: ProviderType.openAI,
        content: 'Provider-agnostic result',
      ),
    );
    final executor = AIServiceMissionTaskExecutor(
      _aiService(provider),
      clock: _clock(startedAt, finishedAt),
    );

    await executor.execute(mission: mission, task: task);

    expect(task.status, TaskStatus.pending);
    expect(task.output, isNull);
    expect(mission.taskProgress.percentage, 0);
    expect(mission.taskProgress.isComplete, isFalse);
  });
}

AIService _aiService(AIProvider provider) {
  return AIService(router: AIRouter(providers: <AIProvider>[provider]));
}

DateTime Function() _clock(DateTime startedAt, DateTime finishedAt) {
  var callCount = 0;

  return () {
    callCount += 1;
    return callCount == 1 ? startedAt : finishedAt;
  };
}

class _RecordingAIProvider implements AIProvider {
  _RecordingAIProvider({this.response, this.error});

  final AIResponse? response;
  final Object? error;

  AIRequest? receivedRequest;

  @override
  String get displayName => 'Recording AI';

  @override
  bool get isConfigured => true;

  @override
  AIProviderMetadata get metadata => const AIProviderMetadata(
    supportedTasks: <AITaskType>{AITaskType.generalChat},
  );

  @override
  ProviderType get type => ProviderType.openAI;

  @override
  bool supports(AIRequest request) => true;

  @override
  Future<AIResponse> complete(AIRequest request) async {
    receivedRequest = request;

    final failure = error;
    if (failure != null) {
      throw failure;
    }

    return response!;
  }

  @override
  Stream<AIChunk> stream(AIRequest request) {
    return const Stream<AIChunk>.empty();
  }
}

Mission _mission() {
  final createdAt = DateTime(2026, 2, 2, 9);

  return Mission(
    id: 'mission',
    title: 'Research mission',
    goal: 'Produce a sourced report',
    category: MissionCategory.education,
    status: MissionStatus.active,
    createdAt: createdAt,
    updatedAt: createdAt,
    currentTaskIndex: 0,
    progressPercent: 0,
    tasks: <MissionTask>[
      MissionTask(
        id: 'task',
        missionId: 'mission',
        title: 'Research sources',
        description: 'Find credible primary sources.',
        order: 0,
        status: TaskStatus.pending,
        taskType: 'research',
        inputContext: ' Focus on official documentation. ',
        createdAt: createdAt,
      ),
    ],
  );
}
