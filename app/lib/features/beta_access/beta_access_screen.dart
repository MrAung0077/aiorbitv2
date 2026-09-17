import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/beta_access_state.dart';
import 'providers/beta_access_provider.dart';

class BetaAccessScreen extends ConsumerStatefulWidget {
  const BetaAccessScreen({super.key});

  @override
  ConsumerState<BetaAccessScreen> createState() => _BetaAccessScreenState();
}

class _BetaAccessScreenState extends ConsumerState<BetaAccessScreen> {
  final _inviteController = TextEditingController();

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final result = await ref
        .read(betaAccessControllerProvider.notifier)
        .activate(_inviteController.text);
    if (!mounted || result?.recoveryCode == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Recovery code ကို သိမ်းထားပါ'),
        content: Text(
          'ဤ code ကို လုံခြုံသောနေရာတွင် တစ်ကြိမ်သာ သိမ်းထားပါ။\n\n${result!.recoveryCode}',
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('သိမ်းပြီးပါပြီ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(betaAccessControllerProvider);
    final loading = state.status == BetaAccessStatus.activating;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Ovexiq Closed Beta', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  const Text('Beta invite code ကို ထည့်သွင်းပြီး စတင်အသုံးပြုပါ။'),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _inviteController,
                    enabled: !loading,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _activate(),
                    decoration: const InputDecoration(
                      labelText: 'Beta invite code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (state.message != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(state.message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: loading ? null : _activate,
                    child: loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('အတည်ပြုမည်'),
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
