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
    this.hintText = 'Ask Ovexiq anything...',
    this.isSending = false,
    this.enabled = true,
    this.onAttach,
    this.onVoice,
    this.inlineActions = false,
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
  final bool inlineActions;

  final int minLines;
  final int maxLines;

  bool get _canInteract => enabled && !isSending;

  void _showAttachmentActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListTile(
            leading: const Icon(Icons.video_library_outlined),
            title: const Text('Add Video'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              onAttach?.call();
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final promptField = TextField(
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
    );
    final attachmentButton = onAttach == null
        ? null
        : SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: 'Add attachment',
              onPressed: _canInteract
                  ? () => _showAttachmentActions(context)
                  : null,
              icon: const Icon(Icons.add_rounded),
            ),
          );
    final voiceButton = onVoice == null
        ? null
        : SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: 'Voice input',
              onPressed: _canInteract ? onVoice : null,
              icon: const Icon(Icons.mic_none_rounded),
            ),
          );
    final sendButton = SizedBox(
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
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: AppShadows.card,
      ),
      child: inlineActions
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (attachmentButton != null) attachmentButton,
                Expanded(child: promptField),
                if (voiceButton != null) voiceButton,
                const SizedBox(width: AppSpacing.xs),
                sendButton,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                promptField,
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    if (attachmentButton != null) attachmentButton,
                    if (voiceButton != null) voiceButton,
                    const Spacer(),
                    sendButton,
                  ],
                ),
              ],
            ),
    );
  }
}
