import 'dart:async';

import 'package:flutter/material.dart';

import '../design/app_motion.dart';
import '../design/app_radius.dart';
import '../design/app_shadows.dart';
import '../design/app_spacing.dart';

class AppTypingIndicator extends StatefulWidget {
  const AppTypingIndicator({super.key, this.label = 'Ovexiq is thinking'});

  final String label;

  @override
  State<AppTypingIndicator> createState() => _AppTypingIndicatorState();
}

class _AppTypingIndicatorState extends State<AppTypingIndicator> {
  Timer? _timer;
  int _activeDot = 0;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(AppMotion.normal, (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _activeDot = (_activeDot + 1) % 3;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Row(
              children: List.generate(
                3,
                (index) => AnimatedContainer(
                  duration: AppMotion.fast,
                  margin: EdgeInsets.only(
                    right: index == 2 ? 0 : AppSpacing.xs,
                  ),
                  width: index == _activeDot ? 8 : 6,
                  height: index == _activeDot ? 8 : 6,
                  decoration: BoxDecoration(
                    color: index == _activeDot
                        ? colorScheme.primary
                        : colorScheme.outline,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
