import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';
import 'mission_task_output_screen.dart';
import 'models/mission_task.dart';
import 'models/task_status.dart';

class MissionFinalResult {
  const MissionFinalResult({required this.task});

  final MissionTask task;

  String? get outputText {
    final output = task.output?.trim();
    return output?.isNotEmpty == true ? output : null;
  }

  bool get isUsable =>
      task.status == TaskStatus.completed && outputText != null;
}

class MissionFinalResultsCard extends StatelessWidget {
  const MissionFinalResultsCard({super.key, required this.results});

  final List<MissionFinalResult> results;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();

    final usableResults = results
        .where((result) => result.isUsable)
        .toList(growable: false);

    if (usableResults.isEmpty) {
      return const SizedBox.shrink();
    }

    Future<void> copyAllResults() async {
      final text = usableResults
          .map((result) {
            final title = result.task.title.trim();
            final output = result.outputText!;

            return '$title\n\n$output';
          })
          .join('\n\n---\n\n');

      await Clipboard.setData(ClipboardData(text: text));

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
    }

    return Container(
      key: const ValueKey<String>('mission-final-results'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.25)),
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
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: colorScheme.onTertiaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.completedOutputs,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      usableResults.length == 1
                          ? l10n.completedOneOutput
                          : l10n.completedOutputCount(usableResults.length),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...usableResults.indexed.map((entry) {
            final index = entry.$1;
            final result = entry.$2;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == usableResults.length - 1 ? 0 : 8,
              ),
              child: _FinalResultTile(result: result),
            );
          }),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              key: const ValueKey<String>('copy-all-final-results-button'),
              onPressed: copyAllResults,
              icon: const Icon(Icons.copy_all_rounded),
              label: Text(l10n.copyAllOutputs),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalResultTile extends StatelessWidget {
  const _FinalResultTile({required this.result});

  final MissionFinalResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsEn();

    final taskTitle = result.task.title.trim();
    final outputText = result.outputText!;

    Future<void> copyResult() async {
      await Clipboard.setData(ClipboardData(text: outputText));

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
    }

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              key: ValueKey<String>('open-final-result-${result.task.id}'),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MissionTaskOutputScreen(
                      taskTitle: taskTitle,
                      outputText: outputText,
                      mode: MissionTaskOutputMode.accepted,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 2, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.description_rounded,
                        size: 18,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            taskTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            outputText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 2),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            key: ValueKey<String>('copy-final-result-${result.task.id}'),
            tooltip: l10n.copy,
            onPressed: copyResult,
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }
}
