import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../mission/services/chat_mission_result_adapter.dart';

class FinishedResultCard extends StatelessWidget {
  const FinishedResultCard({super.key, required this.result, this.isPartial = false});

  final ChatMissionResult result;
  final bool isPartial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();
    final deliverables = result.deliverables;

    Future<void> copyAll() async {
      final content = deliverables
          .map(
            (deliverable) => '${deliverable.title}\n\n${deliverable.content}',
          )
          .join('\n\n---\n\n');
      await Clipboard.setData(ClipboardData(text: content));

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
    }

    return Container(
      key: const ValueKey<String>('finished-result-card'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isPartial
                ? colorScheme.surfaceContainerHighest
                : colorScheme.tertiaryContainer)
            .withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPartial ? l10n.completedOutputs : l10n.resultPackReady,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            isPartial
                ? deliverables.length == 1
                      ? l10n.completedOneOutput
                      : l10n.completedOutputCount(deliverables.length)
                : deliverables.length == 1
                ? l10n.resultPackOneOutput
                : l10n.resultPackOutputCount(deliverables.length),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          ...deliverables.indexed.map((entry) {
            final index = entry.$1;
            final deliverable = entry.$2;
            final showTitle = deliverable.title.trim().isNotEmpty;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == deliverables.length - 1 ? 0 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showTitle) ...[
                    Text(
                      deliverable.title.trim(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  SelectableText(
                    deliverable.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey<String>('copy-finished-result-button'),
              onPressed: copyAll,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(l10n.copy),
            ),
          ),
        ],
      ),
    );
  }
}
