import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/welcome/welcome_screen.dart';

class AIOrbitApp extends StatelessWidget {
  const AIOrbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "AIOrbit",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const WelcomeScreen(),
    );
  }
}
