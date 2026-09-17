import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import 'beta_access_screen.dart';
import 'models/beta_access_state.dart';
import 'providers/beta_access_provider.dart';

class BetaAccessGate extends ConsumerStatefulWidget {
  const BetaAccessGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BetaAccessGate> createState() => _BetaAccessGateState();
}

class _BetaAccessGateState extends ConsumerState<BetaAccessGate> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref.read(betaAccessControllerProvider.notifier).restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isProduction) {
      return widget.child;
    }

    final state = ref.watch(betaAccessControllerProvider);
    if (state.status == BetaAccessStatus.authorized) {
      return widget.child;
    }
    if (state.status == BetaAccessStatus.checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const BetaAccessScreen();
  }
}
