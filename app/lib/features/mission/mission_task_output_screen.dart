import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MissionTaskOutputScreen extends StatelessWidget {
  const MissionTaskOutputScreen({
    super.key,
    required this.taskTitle,
    required this.outputText,
  });

  final String taskTitle;
  final String outputText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trimmedTitle = taskTitle.trim();
    final trimmedOutput = outputText.trim();

    final wordCount = trimmedOutput.isEmpty
        ? 0
        : trimmedOutput.split(RegExp(r'\s+')).length;

    Future<void> copyText({
      required String text,
      required String confirmation,
    }) async {
      await Clipboard.setData(ClipboardData(text: text));

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(confirmation)));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Task Output'), centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
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
                              Icons.task_alt_rounded,
                              color: colorScheme.onPrimaryContainer,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Task',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  trimmedTitle,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.description_outlined,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Output',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(
                                alpha: 0.55,
                              ),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 17,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'Completed Output',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SelectableText(
                            trimmedOutput,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.7,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Divider(),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 18,
                            runSpacing: 10,
                            children: [
                              _OutputMetadata(
                                icon: Icons.notes_rounded,
                                label: '$wordCount words',
                              ),
                              _OutputMetadata(
                                icon: Icons.text_fields_rounded,
                                label: '${trimmedOutput.length} characters',
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              key: const ValueKey<String>('copy-output-button'),
                              onPressed: () {
                                copyText(
                                  text: trimmedOutput,
                                  confirmation: 'Output copied',
                                );
                              },
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Copy Output'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              key: const ValueKey<String>(
                                'copy-task-and-output-button',
                              ),
                              onPressed: () {
                                copyText(
                                  text: '$trimmedTitle\n\n$trimmedOutput',
                                  confirmation: 'Task and output copied',
                                );
                              },
                              icon: const Icon(Icons.content_copy_rounded),
                              label: const Text('Copy with Task Title'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutputMetadata extends StatelessWidget {
  const _OutputMetadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
