import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:aiorbit/features/mission/services/mission_task_ai_request_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('build includes mission goal and task context', () {
    final mission = Mission(
      id: 'mission-1',
      title: 'Launch Ovexiq',
      goal: 'Create a strong launch campaign for Ovexiq creators',
      category: MissionCategory.productivity,
      status: MissionStatus.active,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      currentTaskIndex: 0,
      progressPercent: 0,
      userContext:
          'Audience is Myanmar beginners. Keep recommendations practical.',
      tasks: <MissionTask>[
        MissionTask(
          id: 'task-1',
          missionId: 'mission-1',
          title: 'Research competitors',
          description: 'Find the strongest competing creator tools',
          order: 0,
          status: TaskStatus.pending,
          taskType: 'research',
          inputContext: 'Focus on Facebook, TikTok, and YouTube creators.',
          createdAt: DateTime(2026),
        ),
      ],
    );

    final task = mission.tasks.single;
    const builder = MissionTaskAIRequestBuilder();

    final request = builder.build(mission: mission, task: task);

    final prompt = request.latestUserPrompt;

    expect(
      prompt,
      contains(
        'Mission goal: Create a strong launch campaign for Ovexiq creators',
      ),
    );

    expect(
      prompt,
      contains(
        'User context: Audience is Myanmar beginners. '
        'Keep recommendations practical.',
      ),
    );

    expect(prompt, contains('Title: Research competitors'));

    expect(
      prompt,
      contains('Description: Find the strongest competing creator tools'),
    );

    expect(prompt, contains('Task type: research'));

    expect(
      prompt,
      contains(
        'Input context: Focus on Facebook, TikTok, and YouTube creators.',
      ),
    );
  });

  test('build includes mission context in request metadata', () {
    final mission = Mission(
      id: 'mission-1',
      title: 'Launch Ovexiq',
      goal: 'Create a launch campaign',
      category: MissionCategory.productivity,
      status: MissionStatus.active,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      currentTaskIndex: 0,
      progressPercent: 0,
      userContext: 'Professional tone. Budget must stay under 50 USD.',
      tasks: <MissionTask>[
        MissionTask(
          id: 'task-1',
          missionId: 'mission-1',
          title: 'Research',
          description: 'Research the market',
          order: 0,
          status: TaskStatus.pending,
          taskType: 'research',
          createdAt: DateTime(2026),
        ),
      ],
    );

    const builder = MissionTaskAIRequestBuilder();

    final request = builder.build(mission: mission, task: mission.tasks.single);

    expect(request.metadata['missionId'], 'mission-1');

    expect(request.metadata['taskId'], 'task-1');

    expect(request.metadata['taskType'], 'research');

    expect(request.metadata['missionGoal'], 'Create a launch campaign');

    expect(
      request.metadata['missionCategory'],
      MissionCategory.productivity.name,
    );

    expect(
      request.metadata['userContext'],
      'Professional tone. Budget must stay under 50 USD.',
    );
  });

  test('build includes accepted outputs from completed earlier tasks', () {
    final mission = Mission(
      id: 'mission-1',
      title: 'Launch campaign',
      goal: 'Create a launch campaign',
      category: MissionCategory.productivity,
      status: MissionStatus.active,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      currentTaskIndex: 1,
      progressPercent: 0.33,
      tasks: <MissionTask>[
        MissionTask(
          id: 'research',
          missionId: 'mission-1',
          title: 'Research competitors',
          description: 'Research competing products',
          order: 0,
          status: TaskStatus.completed,
          taskType: 'research',
          output: '  Competitors focus on speed, templates, and automation.  ',
          createdAt: DateTime(2026),
          completedAt: DateTime(2026, 1, 1, 0, 1),
        ),
        MissionTask(
          id: 'strategy',
          missionId: 'mission-1',
          title: 'Create strategy',
          description: 'Create the launch strategy',
          order: 1,
          status: TaskStatus.pending,
          taskType: 'planning',
          createdAt: DateTime(2026),
        ),
        MissionTask(
          id: 'content',
          missionId: 'mission-1',
          title: 'Write content',
          description: 'Write launch content',
          order: 2,
          status: TaskStatus.pending,
          taskType: 'writing',
          output: 'Future output must not be used.',
          createdAt: DateTime(2026),
        ),
      ],
    );

    const builder = MissionTaskAIRequestBuilder();

    final request = builder.build(mission: mission, task: mission.tasks[1]);

    final prompt = request.latestUserPrompt;

    expect(prompt, contains('Previous accepted results:'));

    expect(prompt, contains('Research competitors:'));

    expect(
      prompt,
      contains('Competitors focus on speed, templates, and automation.'),
    );

    expect(prompt, isNot(contains('Future output must not be used.')));
  });

  test('build excludes unusable or unaccepted previous task outputs', () {
    final mission = Mission(
      id: 'mission-1',
      title: 'Launch campaign',
      goal: 'Create a launch campaign',
      category: MissionCategory.productivity,
      status: MissionStatus.active,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      currentTaskIndex: 3,
      progressPercent: 0.5,
      tasks: <MissionTask>[
        MissionTask(
          id: 'completed-blank',
          missionId: 'mission-1',
          title: 'Blank result',
          description: 'Blank output',
          order: 0,
          status: TaskStatus.completed,
          taskType: 'research',
          output: '   \n\t ',
          createdAt: DateTime(2026),
          completedAt: DateTime(2026, 1, 1, 0, 1),
        ),
        MissionTask(
          id: 'pending-output',
          missionId: 'mission-1',
          title: 'Pending result',
          description: 'Pending output',
          order: 1,
          status: TaskStatus.pending,
          taskType: 'research',
          output: 'Pending output must not be used.',
          createdAt: DateTime(2026),
        ),
        MissionTask(
          id: 'in-progress-output',
          missionId: 'mission-1',
          title: 'In progress result',
          description: 'In progress output',
          order: 2,
          status: TaskStatus.inProgress,
          taskType: 'research',
          output: 'In progress output must not be used.',
          createdAt: DateTime(2026),
        ),
        MissionTask(
          id: 'current',
          missionId: 'mission-1',
          title: 'Create strategy',
          description: 'Create the launch strategy',
          order: 3,
          status: TaskStatus.pending,
          taskType: 'planning',
          createdAt: DateTime(2026),
        ),
      ],
    );

    const builder = MissionTaskAIRequestBuilder();

    final request = builder.build(mission: mission, task: mission.tasks[3]);

    final prompt = request.latestUserPrompt;

    expect(prompt, isNot(contains('Previous accepted results:')));

    expect(prompt, isNot(contains('Pending output must not be used.')));

    expect(prompt, isNot(contains('In progress output must not be used.')));
  });

  test('blank mission user context is excluded from prompt and metadata', () {
    final mission = Mission(
      id: 'mission-1',
      title: 'Mission',
      goal: 'Complete the mission',
      category: MissionCategory.productivity,
      status: MissionStatus.active,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      currentTaskIndex: 0,
      progressPercent: 0,
      userContext: '   \n\t ',
      tasks: <MissionTask>[
        MissionTask(
          id: 'task-1',
          missionId: 'mission-1',
          title: 'Research',
          description: 'Research the market',
          order: 0,
          status: TaskStatus.pending,
          taskType: 'research',
          createdAt: DateTime(2026),
        ),
      ],
    );

    const builder = MissionTaskAIRequestBuilder();

    final request = builder.build(mission: mission, task: mission.tasks.single);

    expect(request.latestUserPrompt, isNot(contains('User context:')));

    expect(request.metadata.containsKey('userContext'), isFalse);
  });

  test('build rejects a task that belongs to another mission', () {
    final mission = Mission(
      id: 'mission-1',
      title: 'Mission',
      goal: 'Complete the mission',
      category: MissionCategory.productivity,
      status: MissionStatus.active,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      currentTaskIndex: 0,
      progressPercent: 0,
      tasks: const <MissionTask>[],
    );

    final foreignTask = MissionTask(
      id: 'task-foreign',
      missionId: 'mission-2',
      title: 'Foreign task',
      description: 'Does not belong to this mission',
      order: 0,
      status: TaskStatus.pending,
      taskType: 'research',
      createdAt: DateTime(2026),
    );

    const builder = MissionTaskAIRequestBuilder();

    expect(
      () => builder.build(mission: mission, task: foreignTask),
      throwsArgumentError,
    );
  });
}
