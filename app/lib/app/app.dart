import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/welcome/welcome_screen.dart';
import '../l10n/app_localizations.dart';

class AIOrbitApp extends StatelessWidget {
  const AIOrbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const WelcomeScreen(),
    );
  }
}
