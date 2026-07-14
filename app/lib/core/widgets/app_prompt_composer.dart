import 'package:flutter/material.dart';

import '../design/app_radius.dart';
import '../design/app_shadows.dart';
import '../design/app_spacing.dart';

class AppPromptComposer extends StatelessWidget {
  const AppPromptComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.focusNode,
    this.hintText = 'Ask AIOrbit anything...',
    this.isSending = false,
    this.enabled = true,
    this.onAttach,
    this.onVoice,
    this.minLines = 1,
    this.maxLines = 6,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final Future<void> Function() onSend;

  final String hintText;
  final bool isSending;
  final bool enabled;

  final VoidCallback? onAttach;
  final VoidCallback? onVoice;

  final int minLines;
  final int maxLines;

  bool get _canInteract => enabled && !isSending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: _canInteract,
            minLines: minLines,
            maxLines: maxLines,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: hintText,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (onAttach != null)
                IconButton(
                  tooltip: 'Attach file',
                  onPressed: _canInteract ? onAttach : null,
                  icon: const Icon(Icons.attach_file_rounded),
                ),
              if (onVoice != null)
                IconButton(
                  tooltip: 'Voice input',
                  onPressed: _canInteract ? onVoice : null,
                  icon: const Icon(Icons.mic_none_rounded),
                ),
              const Spacer(),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton.filled(
                  tooltip: 'Send',
                  onPressed: _canInteract ? onSend : null,
                  icon: isSending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
