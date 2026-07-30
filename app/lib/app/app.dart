import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_provider.dart';
import '../core/theme/app_theme.dart';
import '../features/home/home_navigation.dart';
import '../features/settings/providers/settings_controller.dart';
import '../features/startup/startup_screen.dart';
import '../l10n/app_localizations.dart';

class AIOrbitApp extends ConsumerWidget {
  const AIOrbitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      onGenerateTitle: (context) {
        return AppLocalizations.of(context).appName;
      },
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const StartupScreen(readyChild: _ReadyAppHome()),
    );
  }
}

class _ReadyAppHome extends ConsumerWidget {
  const _ReadyAppHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(settingsControllerProvider);

    return const HomeNavigation();
  }
}
