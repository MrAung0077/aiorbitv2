import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/mission_controller.dart';
import 'models/execution_status.dart';
import 'models/mission.dart';
import 'models/mission_execution.dart';
import 'models/mission_task.dart';
import 'models/mission_task_execution.dart';
import 'models/mission_timeline.dart';
import 'models/task_status.dart';
import 'providers/mission_execution_provider.dart';
import 'providers/mission_task_execution_provider.dart';

class MissionDetailScreen extends ConsumerStatefulWidget {
  const MissionDetailScreen({
    super.key,
    required this.mission,
    required this.missionController,
  });

  final Mission mission;
  final MissionController missionController;

  @override
  ConsumerState<MissionDetailScreen> createState() =>
      _MissionDetailScreenState();
}

class _MissionDetailScreenState extends ConsumerState<MissionDetailScreen> {
  late Mission _mission;
  String? _updatingTaskId;
  String? _acceptingTaskId;

  Mission get mission => _mission;

  @override
  void initState() {
    super.initState();
    _mission = widget.mission;
  }

  @override
  void didUpdateWidget(covariant MissionDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.mission.id != widget.mission.id) {
      _mission = widget.mission;
      return;
    }

    if (oldWidget.mission != widget.mission) {
      _mission = widget.mission;
    }
  }

  Future<void> _updateTaskStatus(String taskId, TaskStatus status) async {
    if (_updatingTaskId != null) {
      return;
    }

    setState(() {
      _updatingTaskId = taskId;
    });

    try {
      final updatedMission = await widget.missionController.updateTaskStatus(
        missionId: mission.id,
        taskId: taskId,
        status: status,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _mission = updatedMission;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update the task. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingTaskId = null;
        });
      }
    }
  }

  Future<void> _runExecution() async {
    final notifier = ref.read(missionExecutionProvider.notifier);
    var execution = ref.read(missionExecutionProvider);

    if (execution == null || execution.missionId != mission.id) {
      notifier.createExecution(
        executionId: 'execution-${mission.id}',
        missionId: mission.id,
      );

      execution = ref.read(missionExecutionProvider);
    }

    if (execution == null ||
        execution.status == ExecutionStatus.preparing ||
        execution.status == ExecutionStatus.running ||
        execution.status == ExecutionStatus.completed) {
      return;
    }

    notifier.prepare();

    await Future<void>.delayed(const Duration(milliseconds: 700));

    notifier.start();

    final taskCount = mission.tasks.length;

    for (var index = 0; index < taskCount; index++) {
      await Future<void>.delayed(const Duration(milliseconds: 900));

      notifier.updateProgress(
        progress: (index + 1) / taskCount,
        currentTaskId: mission.tasks[index].id,
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));

    notifier.complete();
  }

  Future<void> _runTask(String taskId) async {
    try {
      await ref
          .read(missionTaskExecutionProvider.notifier)
          .executeTask(missionId: mission.id, taskId: taskId);
    } catch (_) {
      return;
    }
  }

  Future<void> _acceptTaskResult(String taskId) async {
    if (_acceptingTaskId != null) {
      return;
    }

    setState(() {
      _acceptingTaskId = taskId;
    });

    try {
      final updatedMission = await ref
          .read(missionTaskExecutionProvider.notifier)
          .acceptResult(missionId: mission.id, taskId: taskId);

      if (!mounted) {
        return;
      }

      setState(() {
        _mission = updatedMission;
      });
    } catch (_) {
      return;
    } finally {
      if (mounted) {
        setState(() {
          _acceptingTaskId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final execution = ref.watch(missionExecutionProvider);
    final taskExecutions = ref.watch(missionTaskExecutionProvider);

    final currentExecution = execution?.missionId == mission.id
        ? execution
        : null;

    final isExecuting =
        currentExecution?.status == ExecutionStatus.preparing ||
        currentExecution?.status == ExecutionStatus.running;

    final isExecutionCompleted =
        currentExecution?.status == ExecutionStatus.completed;
    final isAnyTaskRunning = taskExecutions.any(
      (execution) => execution.status == ExecutionStatus.running,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Mission')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MissionSummaryCard(mission: mission),
              const SizedBox(height: 16),
              _ExecutionCard(execution: currentExecution),
              const SizedBox(height: 28),
              Text(
                'Mission Timeline',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _MissionTimelineCard(
                timeline: MissionTimeline(
                  mission: mission,
                  execution: currentExecution,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Workflow',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (mission.tasks.isEmpty)
                _EmptyWorkflowCard(
                  onBackToChat: () {
                    Navigator.of(context).maybePop();
                  },
                )
              else
                ...mission.tasks.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MissionTaskTile(
                      task: task,
                      taskExecution: _taskExecutionFor(
                        taskExecutions,
                        missionId: mission.id,
                        taskId: task.id,
                      ),
                      isAnyTaskRunning: isAnyTaskRunning,
                      isAccepting: _acceptingTaskId == task.id,
                      isCurrent:
                          currentExecution?.currentTaskId == task.id &&
                          currentExecution?.status == ExecutionStatus.running,
                      isUpdating: _updatingTaskId == task.id,
                      canTransition:
                          widget.missionController.canTransitionTaskStatus,
                      onStatusChanged: (status) {
                        _updateTaskStatus(task.id, status);
                      },
                      onRunTask: () {
                        _runTask(task.id);
                      },
                      onAcceptResult: () {
                        _acceptTaskResult(task.id);
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      mission.tasks.isEmpty ||
                          isExecuting ||
                          isExecutionCompleted
                      ? null
                      : _runExecution,
                  icon: isExecuting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isExecutionCompleted
                              ? Icons.check_rounded
                              : Icons.play_arrow_rounded,
                        ),
                  label: Text(
                    isExecuting
                        ? 'Mission Running...'
                        : isExecutionCompleted
                        ? 'Execution Completed'
                        : 'Run Mission',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExecutionCard extends StatelessWidget {
  const _ExecutionCard({required this.execution});

  final MissionExecution? execution;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final status = execution?.status ?? ExecutionStatus.queued;
    final progress = execution?.progress ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_executionIcon(status), color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mission Execution',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatName(status.name),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 9,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).round()}% executed',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionTimelineCard extends StatelessWidget {
  const _MissionTimelineCard({required this.timeline});

  final MissionTimeline timeline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          _TimelineRow(
            icon: Icons.add_circle_outline_rounded,
            label: 'Created',
            value: formatMissionTimelineDate(
              timeline.createdAt,
              placeholder: '—',
            ),
          ),
          const Divider(height: 1),
          _TimelineRow(
            icon: Icons.play_circle_outline_rounded,
            label: 'Started',
            value: formatMissionTimelineDate(
              timeline.startedAt,
              placeholder: 'Not started',
            ),
          ),
          const Divider(height: 1),
          _TimelineRow(
            icon: Icons.update_rounded,
            label: 'Updated',
            value: formatMissionTimelineDate(
              timeline.updatedAt,
              placeholder: '—',
            ),
          ),
          const Divider(height: 1),
          _TimelineRow(
            icon: Icons.check_circle_outline_rounded,
            label: 'Completed',
            value: formatMissionTimelineDate(
              timeline.completedAt,
              placeholder: '—',
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _executionIcon(ExecutionStatus status) {
  return switch (status) {
    ExecutionStatus.queued => Icons.schedule_rounded,
    ExecutionStatus.preparing => Icons.tune_rounded,
    ExecutionStatus.running => Icons.bolt_rounded,
    ExecutionStatus.paused => Icons.pause_circle_outline_rounded,
    ExecutionStatus.completed => Icons.check_circle_rounded,
    ExecutionStatus.failed => Icons.error_outline_rounded,
    ExecutionStatus.cancelled => Icons.cancel_outlined,
  };
}

const _interactiveTaskStatuses = <TaskStatus>[
  TaskStatus.pending,
  TaskStatus.inProgress,
  TaskStatus.completed,
];

IconData _taskStatusIcon(TaskStatus status) {
  return switch (status) {
    TaskStatus.pending => Icons.schedule_rounded,
    TaskStatus.inProgress => Icons.play_circle_outline_rounded,
    TaskStatus.completed => Icons.check_circle_outline_rounded,
    TaskStatus.skipped => Icons.skip_next_rounded,
    TaskStatus.failed => Icons.error_outline_rounded,
  };
}

Color _taskStatusColor(TaskStatus status, ColorScheme colorScheme) {
  return switch (status) {
    TaskStatus.pending => colorScheme.onSurfaceVariant,
    TaskStatus.inProgress => colorScheme.primary,
    TaskStatus.completed => colorScheme.tertiary,
    TaskStatus.skipped => colorScheme.outline,
    TaskStatus.failed => colorScheme.error,
  };
}

class _MissionSummaryCard extends StatelessWidget {
  const _MissionSummaryCard({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = mission.taskProgress;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.flag_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mission.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            mission.goal,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MissionMetadataChip(
                icon: Icons.category_outlined,
                label: _formatName(mission.category.name),
              ),
              _MissionMetadataChip(
                icon: Icons.info_outline_rounded,
                label: progress.isComplete
                    ? 'Completed'
                    : _formatName(mission.status.name),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (progress.isComplete)
            _MissionCompletedSection(
              completedTasks: progress.completedTasks,
              totalTasks: progress.totalTasks,
            )
          else ...[
            Row(
              children: [
                Text(
                  'Task progress',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${progress.percentage}%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: progress.percent,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${progress.completedTasks} / ${progress.totalTasks} Tasks Completed',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MissionCompletedSection extends StatelessWidget {
  const _MissionCompletedSection({
    required this.completedTasks,
    required this.totalTasks,
  });

  final int completedTasks;
  final int totalTasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mission Completed',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'All tasks completed successfully.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completedTasks / $totalTasks Tasks Completed',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionMetadataChip extends StatelessWidget {
  const _MissionMetadataChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionTaskTile extends StatelessWidget {
  const _MissionTaskTile({
    required this.task,
    required this.taskExecution,
    required this.isAnyTaskRunning,
    required this.isAccepting,
    required this.isCurrent,
    required this.isUpdating,
    required this.canTransition,
    required this.onStatusChanged,
    required this.onRunTask,
    required this.onAcceptResult,
  });

  final MissionTask task;
  final MissionTaskExecution? taskExecution;
  final bool isAnyTaskRunning;
  final bool isAccepting;
  final bool isCurrent;
  final bool isUpdating;
  final bool Function(TaskStatus from, TaskStatus to) canTransition;
  final ValueChanged<TaskStatus> onStatusChanged;
  final VoidCallback onRunTask;
  final VoidCallback onAcceptResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stepNumber = task.order + 1;
    final statusColor = _taskStatusColor(task.status, colorScheme);
    final canChangeStatus = _interactiveTaskStatuses.any(
      (status) => canTransition(task.status, status),
    );
    final isTaskRunning = taskExecution?.status == ExecutionStatus.running;
    final didTaskFail = taskExecution?.status == ExecutionStatus.failed;
    final canRunTask = _isTaskExecutionEligible(task);

    return Container(
      key: ValueKey<String>('mission-task-${task.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent
            ? colorScheme.primaryContainer.withValues(alpha: 0.45)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$stepNumber',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (task.description.trim().isNotEmpty &&
                    task.description.trim() != task.title.trim()) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PopupMenuButton<TaskStatus>(
                    key: ValueKey<String>('task-status-${task.id}'),
                    enabled: canChangeStatus && !isUpdating,
                    tooltip: 'Change task status',
                    onSelected: onStatusChanged,
                    itemBuilder: (context) {
                      return _interactiveTaskStatuses
                          .map((status) {
                            final isSelected = status == task.status;

                            return PopupMenuItem<TaskStatus>(
                              value: status,
                              enabled: canTransition(task.status, status),
                              child: Row(
                                children: [
                                  Icon(_taskStatusIcon(status), size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(_formatName(status.name)),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_rounded, size: 18),
                                ],
                              ),
                            );
                          })
                          .toList(growable: false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _taskStatusIcon(task.status),
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatName(task.status.name),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isUpdating) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: statusColor,
                              ),
                            ),
                          ] else if (canChangeStatus) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 18,
                              color: statusColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (canRunTask) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: ValueKey<String>('run-task-${task.id}'),
                      onPressed: isTaskRunning || isAnyTaskRunning
                          ? null
                          : onRunTask,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      icon: isTaskRunning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              didTaskFail
                                  ? Icons.refresh_rounded
                                  : Icons.play_arrow_rounded,
                              size: 18,
                            ),
                      label: Text(
                        isTaskRunning
                            ? 'Running…'
                            : didTaskFail
                            ? 'Retry Task'
                            : 'Run Task',
                      ),
                    ),
                  ),
                ],
                if (taskExecution?.status == ExecutionStatus.completed ||
                    taskExecution?.status == ExecutionStatus.failed) ...[
                  const SizedBox(height: 10),
                  _TaskExecutionResultPanel(
                    taskId: task.id,
                    execution: taskExecution!,
                    taskStatus: task.status,
                    isAccepting: isAccepting,
                    onAcceptResult: onAcceptResult,
                  ),
                ],
                if (isCurrent) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Executing now',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskExecutionResultPanel extends StatelessWidget {
  const _TaskExecutionResultPanel({
    required this.taskId,
    required this.execution,
    required this.taskStatus,
    required this.isAccepting,
    required this.onAcceptResult,
  });

  final String taskId;
  final MissionTaskExecution execution;
  final TaskStatus taskStatus;
  final bool isAccepting;
  final VoidCallback onAcceptResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final failed = execution.status == ExecutionStatus.failed;
    final content = failed
        ? execution.failureMessage ??
              'Unable to complete this task. Please try again.'
        : execution.outputText?.trim().isNotEmpty == true
        ? execution.outputText!.trim()
        : 'Task execution completed without text output.';
    final containerColor = failed
        ? colorScheme.errorContainer
        : colorScheme.tertiaryContainer;
    final contentColor = failed
        ? colorScheme.onErrorContainer
        : colorScheme.onTertiaryContainer;
    final canAccept =
        !failed &&
        _hasUsableTaskExecutionResult(execution) &&
        (taskStatus == TaskStatus.pending ||
            taskStatus == TaskStatus.inProgress);
    final isAccepted = !failed && taskStatus == TaskStatus.completed;

    return Container(
      key: ValueKey<String>('task-execution-result-$taskId'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: containerColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            failed
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 20,
            color: contentColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  failed ? 'Task execution failed' : 'Task execution completed',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: contentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: contentColor,
                  ),
                ),
                if (canAccept) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    key: ValueKey<String>('accept-task-result-$taskId'),
                    onPressed: isAccepting ? null : onAcceptResult,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(isAccepting ? 'Accepting…' : 'Accept Result'),
                  ),
                ] else if (isAccepted) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 17,
                        color: contentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Task completed',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: contentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

MissionTaskExecution? _taskExecutionFor(
  List<MissionTaskExecution> executions, {
  required String missionId,
  required String taskId,
}) {
  for (final execution in executions.reversed) {
    if (execution.missionId == missionId && execution.taskId == taskId) {
      return execution;
    }
  }

  return null;
}

bool _isTaskExecutionEligible(MissionTask task) {
  final hasRequiredInput =
      task.title.trim().isNotEmpty &&
      task.description.trim().isNotEmpty &&
      task.taskType.trim().isNotEmpty;

  return hasRequiredInput &&
      (task.status == TaskStatus.pending ||
          task.status == TaskStatus.inProgress);
}

bool _hasUsableTaskExecutionResult(MissionTaskExecution execution) {
  return execution.outputText?.trim().isNotEmpty == true ||
      execution.structuredResultReference?.trim().isNotEmpty == true;
}

class _EmptyWorkflowCard extends StatelessWidget {
  const _EmptyWorkflowCard({required this.onBackToChat});

  final VoidCallback onBackToChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_outlined, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This mission needs a workflow',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Return to Chat and tell Ovexiq what you want to accomplish in '
            'more detail.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onBackToChat,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Back to Chat'),
          ),
        ],
      ),
    );
  }
}

String _formatName(String value) {
  if (value.isEmpty) {
    return value;
  }

  final words = value
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .split(' ');

  return words
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}
