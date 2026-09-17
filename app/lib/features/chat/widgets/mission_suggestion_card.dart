import 'package:flutter/material.dart';

import '../../../core/design/app_radius.dart';
import '../../../core/design/app_shadows.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/text/response_language.dart';

class MissionSuggestionCard extends StatelessWidget {
  const MissionSuggestionCard({
    super.key,
    required this.title,
    required this.onContinue,
    this.isExistingMission = false,
    this.isLoading = false,
  });

  final String title;
  final VoidCallback onContinue;
  final bool isExistingMission;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final burmese = isBurmeseResponse(title);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.route_rounded,
                color: colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  isExistingMission
                      ? (burmese
                            ? 'Mission ကို ဆက်လုပ်ရန်'
                            : 'Continue Mission')
                      : (burmese
                            ? 'Mission အဖြစ် ဆက်လုပ်ရန်'
                            : 'Continue as a Mission'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isExistingMission
                ? (burmese
                      ? 'သိမ်းထားသော workflow သို့ ပြန်သွားပါ။'
                      : 'Return to your saved workflow.')
                : (burmese
                      ? 'ဤရည်ရွယ်ချက်ကို လမ်းညွှန်ထားသည့် workflow အဖြစ် ပြင်ဆင်ပါ။'
                      : 'Turn this goal into a guided workflow.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: isLoading ? null : onContinue,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(
                isLoading
                    ? (burmese ? 'စစ်ဆေးနေသည်...' : 'Checking...')
                    : isExistingMission
                    ? (burmese ? 'Mission ဖွင့်ရန်' : 'Open Mission')
                    : (burmese ? 'ဆက်လုပ်ရန်' : 'Continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
