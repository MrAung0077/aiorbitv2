import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/execution_status.dart';
import 'models/mission.dart';
import 'models/mission_execution.dart';
import 'models/mission_task.dart';
import 'providers/mission_execution_provider.dart';

class MissionDetailScreen extends ConsumerStatefulWidget {
  const MissionDetailScreen({super.key, required this.mission});

  final Mission mission;

  @override
  ConsumerState<MissionDetailScreen> createState() =>
      _MissionDetailScreenState();
}

class _MissionDetailScreenState extends ConsumerState<MissionDetailScreen> {
  Mission get mission => widget.mission;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final execution = ref.watch(missionExecutionProvider);

    final currentExecution = execution?.missionId == mission.id
        ? execution
        : null;

    final isExecuting =
        currentExecution?.status == ExecutionStatus.preparing ||
        currentExecution?.status == ExecutionStatus.running;

    final isCompleted = currentExecution?.status == ExecutionStatus.completed;

    return Scaffold(
      appBar: AppBar(title: const Text('Mission')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.flag_rounded, size: 44, color: colorScheme.primary),
              const SizedBox(height: 18),
              Text(
                mission.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mission.goal,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _MissionSummaryCard(mission: mission),
              const SizedBox(height: 16),
              _ExecutionCard(execution: currentExecution),
              const SizedBox(height: 28),
              Text(
                'Workflow',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (mission.tasks.isEmpty)
                const _EmptyWorkflowCard()
              else
                ...mission.tasks.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MissionTaskTile(
                      task: task,
                      isCurrent:
                          currentExecution?.currentTaskId == task.id &&
                          currentExecution?.status == ExecutionStatus.running,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: mission.tasks.isEmpty || isExecuting || isCompleted
                      ? null
                      : _runExecution,
                  icon: isExecuting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isCompleted
                              ? Icons.check_rounded
                              : Icons.play_arrow_rounded,
                        ),
                  label: Text(
                    isExecuting
                        ? 'Mission Running...'
                        : isCompleted
                        ? 'Mission Completed'
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

class _MissionSummaryCard extends StatelessWidget {
  const _MissionSummaryCard({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          _SummaryRow(label: 'Status', value: _formatName(mission.status.name)),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Category',
            value: _formatName(mission.category.name),
          ),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Tasks', value: '${mission.tasks.length}'),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: (mission.progressPercent / 100).clamp(0.0, 1.0),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${mission.progressPercent.round()}% complete',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MissionTaskTile extends StatelessWidget {
  const _MissionTaskTile({required this.task, required this.isCurrent});

  final MissionTask task;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stepNumber = task.order + 1;

    return Container(
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
                Text(
                  _formatName(task.status.name),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

class _EmptyWorkflowCard extends StatelessWidget {
  const _EmptyWorkflowCard();

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
      child: Text(
        'No workflow tasks are available for this mission.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
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
