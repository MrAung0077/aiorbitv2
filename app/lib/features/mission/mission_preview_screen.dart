import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mission_detail_screen.dart';
import 'models/mission_suggestion.dart';
import 'providers/mission_execution_provider.dart';
import 'providers/mission_provider.dart';

class MissionPreviewScreen extends ConsumerStatefulWidget {
  const MissionPreviewScreen({
    super.key,
    required this.suggestion,
    this.conversationId,
  });

  final MissionSuggestion suggestion;
  final String? conversationId;

  @override
  ConsumerState<MissionPreviewScreen> createState() =>
      _MissionPreviewScreenState();
}

class _MissionPreviewScreenState extends ConsumerState<MissionPreviewScreen> {
  bool _isStarting = false;
  bool _isCreated = false;

  MissionSuggestion get suggestion => widget.suggestion;

  Future<void> _startMission() async {
    if (_isStarting || _isCreated) {
      return;
    }

    setState(() {
      _isStarting = true;
    });

    try {
      final missionController = ref.read(missionControllerProvider);
      final mission = await missionController.startMission(
        suggestion,
        conversationId: widget.conversationId,
      );

      if (!mounted) {
        return;
      }

      ref
          .read(missionExecutionProvider.notifier)
          .createExecution(
            executionId: 'execution-${mission.id}',
            missionId: mission.id,
          );

      setState(() {
        _isCreated = true;
      });

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MissionDetailScreen(
            mission: mission,
            missionController: missionController,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to create the mission. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mission Preview')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.route_rounded, size: 42, color: colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                suggestion.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              _PreviewSection(title: 'Goal', content: suggestion.goal),
              const SizedBox(height: 16),
              _PreviewSection(
                title: 'Category',
                content: suggestion.category.name,
              ),
              const SizedBox(height: 16),
              _PreviewSection(
                title: 'Why this can become a mission',
                content: suggestion.reason,
              ),
              const SizedBox(height: 28),
              Text(
                'Planned workflow',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...suggestion.plannedSteps.indexed.map((entry) {
                final stepNumber = entry.$1 + 1;
                final step = entry.$2;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PlannedStepTile(number: stepNumber, title: step),
                );
              }),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isCreated
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _isCreated
                          ? Icons.check_circle_outline_rounded
                          : Icons.info_outline_rounded,
                      color: _isCreated
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isCreated
                            ? 'Your mission has been created and saved for this session.'
                            : 'This is only a preview. No mission has been created or saved yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _isCreated
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isStarting || _isCreated ? null : _startMission,
                  icon: _isStarting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isCreated
                              ? Icons.check_rounded
                              : Icons.play_arrow_rounded,
                        ),
                  label: Text(
                    _isStarting
                        ? 'Starting Mission...'
                        : _isCreated
                        ? 'Mission Created'
                        : 'Start Mission',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Chat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlannedStepTile extends StatelessWidget {
  const _PlannedStepTile({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(content, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}
