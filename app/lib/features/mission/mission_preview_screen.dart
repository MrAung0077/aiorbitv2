import 'package:flutter/material.dart';

import 'models/mission_suggestion.dart';

class MissionPreviewScreen extends StatelessWidget {
  const MissionPreviewScreen({super.key, required this.suggestion});

  final MissionSuggestion suggestion;

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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This is only a preview. No mission has been created or saved yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
