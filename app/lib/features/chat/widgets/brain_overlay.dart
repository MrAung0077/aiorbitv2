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
                  'Ovexiq',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Working toward your result',
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
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
