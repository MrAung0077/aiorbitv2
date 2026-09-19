import 'package:aiorbit/features/mission/models/mission.dart';
import 'package:aiorbit/features/mission/models/mission_category.dart';
import 'package:aiorbit/features/mission/models/mission_status.dart';
import 'package:aiorbit/features/mission/models/mission_task.dart';
import 'package:aiorbit/features/mission/models/task_status.dart';
import 'package:aiorbit/features/mission/services/mission_task_ai_request_builder.dart';
import 'package:aiorbit/core/text/response_language.dart';
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

    expect(
      prompt,
      contains(
        'Do the requested work and give the usable finished result first',
      ),
    );
    expect(prompt, contains('concise 100–180-word result'));
    expect(prompt, contains('Return ready-to-use deliverables'));
    expect(prompt, contains('plain, beginner-friendly language'));
    expect(prompt, contains('internal reasoning or frameworks out'));
    expect(prompt, contains('ask at most 1–3 short questions'));
  });

  test('build limits execution to the current Mission task', () {
    final currentTask = MissionTask(
      id: 'research',
      missionId: 'mission-1',
      title: 'Research the market and key message',
      description: 'Find audience needs, pain points, and a key message.',
      order: 0,
      status: TaskStatus.pending,
      taskType: 'research',
      createdAt: DateTime(2026),
    );
    final futureTask = MissionTask(
      id: 'posts',
      missionId: 'mission-1',
      title: 'Publish social posts',
      description: 'Create launch social posts.',
      order: 1,
      status: TaskStatus.pending,
      taskType: 'writing',
      createdAt: DateTime(2026),
    );
    final mission = Mission(
      id: 'mission-1',
      title: 'Launch Ovexiq',
      goal: 'Launch Ovexiq successfully',
      category: MissionCategory.productivity,
      status: MissionStatus.active,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      currentTaskIndex: 0,
      progressPercent: 0,
      tasks: <MissionTask>[currentTask, futureTask],
    );

    final prompt = const MissionTaskAIRequestBuilder()
        .build(mission: mission, task: currentTask)
        .latestUserPrompt;

    expect(
      prompt,
      contains(
        'Complete only the current task. Do not pre-complete future mission '
        'tasks or include deliverables that clearly belong to later tasks.',
      ),
    );
    expect(
      prompt,
      contains(
        'Use mission context only to understand the current task, not to '
        'answer the whole mission.',
      ),
    );
    expect(
      prompt,
      contains('End the response once the current task is complete.'),
    );
    expect(prompt, contains('Title: Research the market and key message'));
    expect(prompt, isNot(contains('Title: Publish social posts')));
  });

  test('build permits explicit long-form Mission work', () {
    final task = MissionTask(
      id: 'task-1',
      missionId: 'mission-1',
      title: 'Write a detailed 1,500-word launch report',
      description: 'Create a long report with the full launch plan.',
      order: 0,
      status: TaskStatus.pending,
      taskType: 'writing',
      createdAt: DateTime(2026),
    );
    final mission = Mission(
      id: 'mission-1',
      title: 'Launch Ovexiq',
      goal: 'Plan the launch',
      category: MissionCategory.productivity,
      status: MissionStatus.active,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      currentTaskIndex: 0,
      progressPercent: 0,
      tasks: <MissionTask>[task],
    );

    final prompt = const MissionTaskAIRequestBuilder()
        .build(mission: mission, task: task)
        .latestUserPrompt;

    expect(prompt, contains('Output policy:'));
    expect(
      prompt,
      contains(
        'Provide longer output only when the user explicitly asks for detail, '
        'explanation, long-form content or a report, or when the requested '
        'artifact itself must be long.',
      ),
    );
    expect(
      prompt,
      contains('Title: Write a detailed 1,500-word launch report'),
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

  test('preserves the Burmese writing contract through every Mission task', () {
    final mission = Mission(
      id: 'mission-burmese',
      title: 'Facebook နှင့် TikTok Content အစီအစဉ်',
      goal: 'Facebook နဲ့ TikTok အတွက် တစ်ပတ်စာ Content အစီအစဉ် ပြင်ဆင်ပေးပါ။',
      category: MissionCategory.socialMedia,
      status: MissionStatus.active,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      currentTaskIndex: 0,
      progressPercent: 0,
      tasks: <MissionTask>[
        MissionTask(
          id: 'task-1',
          missionId: 'mission-burmese',
          title: 'ပစ်မှတ်ပရိသတ် သတ်မှတ်ခြင်း',
          description: 'ပစ်မှတ်ပရိသတ်ကို သတ်မှတ်ပါ။',
          order: 0,
          status: TaskStatus.pending,
          taskType: 'planning',
          createdAt: DateTime(2026),
        ),
        MissionTask(
          id: 'task-2',
          missionId: 'mission-burmese',
          title: 'Content အစီအစဉ် ရေးဆွဲခြင်း',
          description: 'တစ်ပတ်စာ Content အစီအစဉ် ပြင်ဆင်ပါ။',
          order: 1,
          status: TaskStatus.pending,
          taskType: 'writing',
          createdAt: DateTime(2026),
        ),
      ],
    );

    const builder = MissionTaskAIRequestBuilder();
    for (final task in mission.tasks) {
      final request = builder.build(mission: mission, task: task);
      final prompt = request.latestUserPrompt;
      expect(prompt, contains('natural Burmese throughout'));
      expect(prompt, contains('every heading, bullet'));
      expect(prompt, contains('Never use the pronouns မင်း, နင်, or ငါ'));
      expect(prompt, isNot(contains('ရည်အသွား')));
      expect(prompt, isNot(contains('ဒျမိုန့် tips')));
      expect(prompt, isNot(contains('စိတ်တိုချင်းဖျော်ဖြေရေး')));
      expect(request.responseLanguage, ResponseLanguage.burmese);
    }
  });

  test(
    'preserves an explicitly selected English response language through every Mission task',
    () {
      final mission = Mission(
        id: 'mission-english',
        title: 'Facebook content plan',
        goal: 'Facebook အတွက် Content အစီအစဉ် ပြင်ဆင်ပေးပါ။ Reply in English.',
        category: MissionCategory.socialMedia,
        status: MissionStatus.active,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        currentTaskIndex: 0,
        progressPercent: 0,
        tasks: <MissionTask>[
          MissionTask(
            id: 'task-1',
            missionId: 'mission-english',
            title: 'Audience',
            description: 'Define the audience.',
            order: 0,
            status: TaskStatus.pending,
            taskType: 'planning',
            createdAt: DateTime(2026),
          ),
          MissionTask(
            id: 'task-2',
            missionId: 'mission-english',
            title: 'Plan',
            description: 'Create the content plan.',
            order: 1,
            status: TaskStatus.pending,
            taskType: 'writing',
            createdAt: DateTime(2026),
          ),
        ],
      );

      const builder = MissionTaskAIRequestBuilder();
      for (final task in mission.tasks) {
        final request = builder.build(mission: mission, task: task);
        final prompt = request.latestUserPrompt;
        expect(
          prompt,
          contains("Language: Respond in the user's requested language."),
        );
        expect(prompt, isNot(contains('natural Burmese throughout')));
        expect(request.responseLanguage, ResponseLanguage.english);
      }
    },
  );

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

  test('build includes only the latest three accepted previous results', () {
    final createdAt = DateTime(2026);

    MissionTask completedTask({
      required String id,
      required String title,
      required int order,
      required String output,
    }) {
      return MissionTask(
        id: id,
        missionId: 'mission-1',
        title: title,
        description: 'Completed task $order',
        order: order,
        status: TaskStatus.completed,
        taskType: 'research',
        output: output,
        createdAt: createdAt,
        completedAt: DateTime(2026, 1, 1, 0, order + 1),
      );
    }

    final mission = Mission(
      id: 'mission-1',
      title: 'Long mission',
      goal: 'Complete a multi-step mission',
      category: MissionCategory.productivity,
      status: MissionStatus.active,
      createdAt: createdAt,
      updatedAt: createdAt,
      currentTaskIndex: 4,
      progressPercent: 0.8,
      tasks: <MissionTask>[
        completedTask(
          id: 'task-1',
          title: 'Oldest result',
          order: 0,
          output: 'OUTPUT_ONE',
        ),
        completedTask(
          id: 'task-2',
          title: 'Second result',
          order: 1,
          output: 'OUTPUT_TWO',
        ),
        completedTask(
          id: 'task-3',
          title: 'Third result',
          order: 2,
          output: 'OUTPUT_THREE',
        ),
        completedTask(
          id: 'task-4',
          title: 'Latest result',
          order: 3,
          output: 'OUTPUT_FOUR',
        ),
        MissionTask(
          id: 'current',
          missionId: 'mission-1',
          title: 'Current task',
          description: 'Use relevant previous work',
          order: 4,
          status: TaskStatus.pending,
          taskType: 'planning',
          createdAt: createdAt,
        ),
      ],
    );

    const builder = MissionTaskAIRequestBuilder();

    final request = builder.build(mission: mission, task: mission.tasks.last);

    final prompt = request.latestUserPrompt;

    expect(prompt, isNot(contains('OUTPUT_ONE')));
    expect(prompt, contains('OUTPUT_TWO'));
    expect(prompt, contains('OUTPUT_THREE'));
    expect(prompt, contains('OUTPUT_FOUR'));

    expect(request.metadata['previousAcceptedResultCount'], 3);
  });

  test('build caps total previous accepted result context', () {
    final createdAt = DateTime(2026);

    final mission = Mission(
      id: 'mission-1',
      title: 'Large context mission',
      goal: 'Complete a mission without excessive context',
      category: MissionCategory.productivity,
      status: MissionStatus.active,
      createdAt: createdAt,
      updatedAt: createdAt,
      currentTaskIndex: 3,
      progressPercent: 0.75,
      tasks: <MissionTask>[
        MissionTask(
          id: 'task-1',
          missionId: 'mission-1',
          title: 'Large result one',
          description: 'Produce a large result',
          order: 0,
          status: TaskStatus.completed,
          taskType: 'research',
          output: 'A' * 4000,
          createdAt: createdAt,
          completedAt: DateTime(2026, 1, 1, 0, 1),
        ),
        MissionTask(
          id: 'task-2',
          missionId: 'mission-1',
          title: 'Large result two',
          description: 'Produce another large result',
          order: 1,
          status: TaskStatus.completed,
          taskType: 'research',
          output: 'B' * 4000,
          createdAt: createdAt,
          completedAt: DateTime(2026, 1, 1, 0, 2),
        ),
        MissionTask(
          id: 'task-3',
          missionId: 'mission-1',
          title: 'Latest result',
          description: 'Produce the latest result',
          order: 2,
          status: TaskStatus.completed,
          taskType: 'research',
          output: 'LATEST_RESULT',
          createdAt: createdAt,
          completedAt: DateTime(2026, 1, 1, 0, 3),
        ),
        MissionTask(
          id: 'current',
          missionId: 'mission-1',
          title: 'Current task',
          description: 'Use bounded previous context',
          order: 3,
          status: TaskStatus.pending,
          taskType: 'planning',
          createdAt: createdAt,
        ),
      ],
    );

    const builder = MissionTaskAIRequestBuilder();

    final request = builder.build(mission: mission, task: mission.tasks.last);

    final prompt = request.latestUserPrompt;

    final contextStart = prompt.indexOf('Previous accepted results:');
    final currentTaskStart = prompt.indexOf('Title: Current task');

    expect(contextStart, greaterThanOrEqualTo(0));
    expect(currentTaskStart, greaterThan(contextStart));

    final previousContext = prompt.substring(contextStart, currentTaskStart);

    expect(previousContext.length, lessThanOrEqualTo(6100));

    // The newest accepted result must survive the context budget.
    expect(previousContext, contains('LATEST_RESULT'));
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
