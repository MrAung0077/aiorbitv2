import 'package:flutter/material.dart';

import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../models/brain_status.dart';
import '../models/router_decision.dart';
import 'brain_step.dart';

class BrainOverlay extends StatelessWidget {
  const BrainOverlay({
    super.key,
    required this.currentStatus,
    required this.decision,
  });

  final BrainStatus currentStatus;
  final RouterDecision decision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const steps = [
      BrainStatus.understanding,
      BrainStatus.selectingAi,
      BrainStatus.optimizing,
    ];

    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: SingleChildScrollView(
          padding: AppSpacing.screen,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 440),
            padding: AppSpacing.card,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: AppRadius.cardRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.92, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.psychology_rounded,
                      size: 38,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'AIOrbit Brain',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Analyzing and routing your request',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ...steps.map(
                  (status) => BrainStep(
                    status: status,
                    isCompleted: status.index < currentStatus.index,
                    isActive: status == currentStatus,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: AppRadius.cardRadius,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        icon: Icons.task_alt_rounded,
                        label: 'Task',
                        value: decision.task,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _InfoRow(
                        icon: Icons.psychology_alt_rounded,
                        label: 'Reasoning',
                        value: decision.reasoning,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _InfoRow(
                        icon: Icons.speed_rounded,
                        label: 'Complexity',
                        value: decision.complexity,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _InfoRow(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Recommended AI',
                        value: decision.recommendedAi,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      LinearProgressIndicator(
                        value: decision.confidence.clamp(0, 100) / 100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${decision.confidence}% confidence',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.onSecondaryContainer),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
