import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'providers/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: settingsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _SettingsErrorView(
          message: error.toString(),
          onRetry: () {
            ref.read(settingsControllerProvider.notifier).load();
          },
        ),
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SettingsSection(
                title: 'Appearance',
                children: [
                  _SelectionTile(
                    title: 'System theme',
                    subtitle: 'Follow the device theme',
                    icon: Icons.brightness_auto_outlined,
                    selected: settings.theme == 'system',
                    onTap: () {
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setTheme('system');
                    },
                  ),
                  _SelectionTile(
                    title: 'Light theme',
                    icon: Icons.light_mode_outlined,
                    selected: settings.theme == 'light',
                    onTap: () {
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setTheme('light');
                    },
                  ),
                  _SelectionTile(
                    title: 'Dark theme',
                    icon: Icons.dark_mode_outlined,
                    selected: settings.theme == 'dark',
                    onTap: () {
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setTheme('dark');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SettingsSection(
                title: l10n.language,
                children: [
                  _SelectionTile(
                    title: l10n.systemLanguage,
                    subtitle: 'Follow the device language',
                    icon: Icons.language_outlined,
                    selected: settings.language == 'system',
                    onTap: () {
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setLanguage('system');
                    },
                  ),
                  _SelectionTile(
                    title: l10n.english,
                    icon: Icons.translate_outlined,
                    selected: settings.language == 'en',
                    onTap: () {
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setLanguage('en');
                    },
                  ),
                  _SelectionTile(
                    title: l10n.myanmar,
                    icon: Icons.translate_outlined,
                    selected: settings.language == 'my',
                    onTap: () {
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setLanguage('my');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _SettingsSection(
                title: 'About',
                children: [
                  ListTile(
                    leading: Icon(Icons.info_outline_rounded),
                    title: Text('AIOrbit'),
                    subtitle: Text('Version 1.0.0'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: selected ? colorScheme.primary : null),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
          : const Icon(Icons.circle_outlined),
    );
  }
}

class _SettingsErrorView extends StatelessWidget {
  const _SettingsErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text('Could not load settings.', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
