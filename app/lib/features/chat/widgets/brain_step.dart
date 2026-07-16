import 'package:flutter/material.dart';

import '../models/brain_status.dart';

class BrainStep extends StatelessWidget {
  const BrainStep({
    super.key,
    required this.status,
    required this.isCompleted,
    required this.isActive,
  });

  final BrainStatus status;
  final bool isCompleted;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget leading;

    if (isCompleted) {
      leading = Icon(
        Icons.check_circle_rounded,
        color: colorScheme.primary,
        size: 22,
      );
    } else if (isActive) {
      leading = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colorScheme.primary,
        ),
      );
    } else {
      leading = Icon(
        Icons.radio_button_unchecked,
        color: colorScheme.outline,
        size: 20,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: theme.textTheme.bodyLarge!.copyWith(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isCompleted || isActive
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
              child: Text(status.label),
            ),
          ),
        ],
      ),
    );
  }
}
