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
import 'package:aiorbit/core/text/response_language.dart';
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

    final prompt = request.messages.single.content;

    expect(prompt, contains('Complete this mission task.'));
    expect(prompt, contains('Output policy:'));
    expect(
      prompt,
      contains(
        'Complete only the current task. Do not pre-complete future mission tasks',
      ),
    );
    expect(prompt, contains('Default to a concise 100–180-word result'));
    expect(prompt, contains('give the usable finished result first'));
    expect(prompt, contains('Use plain, beginner-friendly language.'));
    expect(prompt, contains('not consultant reports.'));
    expect(prompt, contains('Mission goal: Produce a sourced report'));
    expect(prompt, contains('Title: Research sources'));
    expect(prompt, contains('Description: Find credible primary sources.'));
    expect(prompt, contains('Task type: research'));
    expect(prompt, contains('Input context: Focus on official documentation.'));

    expect(request.preferredProvider, isNull);
    expect(request.model, isNull);

    expect(request.metadata, <String, Object?>{
      'missionId': 'mission',
      'taskId': 'task',
      'taskType': 'research',
      'missionGoal': 'Produce a sourced report',
      'missionCategory': MissionCategory.education.name,
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

  test('AI failure returns a sanitized failed execution', () async {
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
    expect(result.failureMessage, 'Ovexiq AI is temporarily unavailable.');
    expect(result.failureMessage, isNot(contains('stub AI failure')));
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

  test(
    'repairs one invalid Burmese Mission output without expanding task scope',
    () async {
      final mission = _burmeseMission();
      final provider = _QueuedAIProvider(
        responses: <AIResponse>[
          const AIResponse(
            provider: ProviderType.openAI,
            content: 'Reserved upcoming task scopes: Caption writing\nԵթե',
          ),
          const AIResponse(
            provider: ProviderType.openAI,
            content: 'ပစ်မှတ်ပရိသတ်က အလုပ်လုပ်နေသော မိဘများဖြစ်သည်။',
          ),
        ],
      );
      final executor = AIServiceMissionTaskExecutor(
        _aiService(provider),
        clock: _clock(startedAt, finishedAt),
      );

      final result = await executor.execute(
        mission: mission,
        task: mission.tasks[1],
      );

      expect(result.status, ExecutionStatus.completed);
      expect(
        result.outputText,
        'ပစ်မှတ်ပရိသတ်က အလုပ်လုပ်နေသော မိဘများဖြစ်သည်။',
      );
      expect(provider.requests, hasLength(2));

      final repairRequest = provider.requests.last;
      final repairContext = repairRequest.messages
          .map((message) => message.content)
          .join('\n');
      expect(repairRequest.responseLanguage, ResponseLanguage.burmese);
      expect(repairRequest.metadata['qualityRepair'], isTrue);
      expect(
        repairRequest.latestUserPrompt,
        contains('Rewrite only this task output in natural Burmese.'),
      );
      expect(
        repairRequest.latestUserPrompt,
        contains('Do not add new claims, new tasks, or new deliverables.'),
      );
      expect(
        repairRequest.latestUserPrompt,
        contains('Do not mention internal Mission or task instructions.'),
      );
      expect(repairContext, contains('Internal future-task ownership notes'));
      expect(repairContext, contains('Caption writing'));
    },
  );

  test(
    'fails safely after one invalid Burmese repair without looping',
    () async {
      final mission = _burmeseMission();
      final provider = _QueuedAIProvider(
        responses: const <AIResponse>[
          AIResponse(provider: ProviderType.openAI, content: 'Եթե'),
          AIResponse(provider: ProviderType.openAI, content: '아니면'),
        ],
      );
      final executor = AIServiceMissionTaskExecutor(
        _aiService(provider),
        clock: _clock(startedAt, finishedAt),
      );

      final result = await executor.execute(
        mission: mission,
        task: mission.tasks[1],
      );

      expect(result.status, ExecutionStatus.failed);
      expect(result.outputText, isNull);
      expect(result.failureMessage, 'Ovexiq AI returned an invalid response.');
      expect(provider.requests, hasLength(2));
      expect(mission.tasks.first.output, 'အလုပ်လုပ်နေသော မိဘများ');
      expect(mission.tasks.first.status, TaskStatus.completed);
      expect(mission.tasks[2].status, TaskStatus.pending);
    },
  );

  test('accepts clean Burmese Mission output without a repair call', () async {
    final mission = _burmeseMission();
    final provider = _QueuedAIProvider(
      responses: const <AIResponse>[
        AIResponse(
          provider: ProviderType.openAI,
          content: 'Facebook Reel အတွက် ပစ်မှတ်ပရိသတ်ကို သတ်မှတ်ပါ။',
        ),
      ],
    );
    final executor = AIServiceMissionTaskExecutor(
      _aiService(provider),
      clock: _clock(startedAt, finishedAt),
    );

    final result = await executor.execute(
      mission: mission,
      task: mission.tasks[1],
    );

    expect(result.status, ExecutionStatus.completed);
    expect(provider.requests, hasLength(1));
  });

  test(
    'allows a foreign script only when the Mission explicitly requests it',
    () async {
      final mission = _burmeseMission().copyWith(
        goal: 'ကိုရီးယားလို ရေးပေးပါ။',
      );
      final provider = _QueuedAIProvider(
        responses: const <AIResponse>[
          AIResponse(provider: ProviderType.openAI, content: '안녕하세요'),
        ],
      );
      final executor = AIServiceMissionTaskExecutor(
        _aiService(provider),
        clock: _clock(startedAt, finishedAt),
      );

      final result = await executor.execute(
        mission: mission,
        task: mission.tasks[1],
      );

      expect(result.status, ExecutionStatus.completed);
      expect(result.outputText, '안녕하세요');
      expect(provider.requests, hasLength(1));
    },
  );
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

class _QueuedAIProvider implements AIProvider {
  _QueuedAIProvider({required List<AIResponse> responses})
    : _responses = List<AIResponse>.of(responses);

  final List<AIResponse> _responses;
  final List<AIRequest> requests = <AIRequest>[];

  @override
  String get displayName => 'Queued AI';

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
    requests.add(request);
    return _responses.removeAt(0);
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

Mission _burmeseMission() {
  final createdAt = DateTime(2026, 2, 2, 9);

  return Mission(
    id: 'burmese-mission',
    title: 'Facebook အကြောင်းအရာအစီအစဉ်',
    goal: 'Facebook အတွက် မြန်မာလို အကြောင်းအရာအစီအစဉ် ပြင်ဆင်ပေးပါ။',
    category: MissionCategory.socialMedia,
    status: MissionStatus.active,
    createdAt: createdAt,
    updatedAt: createdAt,
    currentTaskIndex: 1,
    progressPercent: 0.33,
    tasks: <MissionTask>[
      MissionTask(
        id: 'audience',
        missionId: 'burmese-mission',
        title: 'ပစ်မှတ်ပရိသတ်',
        description: 'ပစ်မှတ်ပရိသတ်ကို သတ်မှတ်ပါ။',
        order: 0,
        status: TaskStatus.completed,
        taskType: 'planning',
        output: 'အလုပ်လုပ်နေသော မိဘများ',
        createdAt: createdAt,
      ),
      MissionTask(
        id: 'themes',
        missionId: 'burmese-mission',
        title: 'အကြောင်းအရာအမျိုးအစား',
        description: 'အကြောင်းအရာအမျိုးအစားကိုသာ ပြင်ဆင်ပါ။',
        order: 1,
        status: TaskStatus.pending,
        taskType: 'planning',
        createdAt: createdAt,
      ),
      MissionTask(
        id: 'captions',
        missionId: 'burmese-mission',
        title: 'Caption ရေးသားခြင်း',
        description: 'Caption များကိုသာ ရေးပါ။',
        order: 2,
        status: TaskStatus.pending,
        taskType: 'writing',
        createdAt: createdAt,
      ),
    ],
  );
}
