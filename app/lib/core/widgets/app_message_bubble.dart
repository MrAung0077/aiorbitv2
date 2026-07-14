import 'package:flutter/material.dart';

import '../../features/chat/models/chat_message.dart';
import '../design/app_radius.dart';
import '../design/app_shadows.dart';
import 'app_markdown.dart';

class AppMessageBubble extends StatelessWidget {
  const AppMessageBubble({
    super.key,
    required this.message,
    this.onCopy,
    this.onRetry,
    this.showAvatar = false,
    this.showTimestamp = false,
  });

  final ChatMessage message;
  final VoidCallback? onCopy;
  final VoidCallback? onRetry;
  final bool showAvatar;
  final bool showTimestamp;

  bool get _isUser => message.role == ChatRole.user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final background = message.isError
        ? colorScheme.errorContainer
        : _isUser
        ? colorScheme.primaryContainer
        : colorScheme.surface;

    final foreground = message.isError
        ? colorScheme.onErrorContainer
        : _isUser
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: _isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!_isUser && showAvatar) ...[
            const CircleAvatar(
              radius: 16,
              child: Icon(Icons.auto_awesome, size: 16),
            ),
            const SizedBox(width: 8),
          ],

          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * .80,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: background,
                borderRadius: AppRadius.cardRadius,
                boxShadow: AppShadows.card,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppMarkdown(message.content, textColor: foreground),

                  if (showTimestamp) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(message.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],

                  if (!_isUser) ...[
                    const SizedBox(height: 4),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onCopy != null)
                          IconButton(
                            tooltip: 'Copy',
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            onPressed: onCopy,
                            icon: const Icon(Icons.copy_outlined),
                          ),

                        if (message.isError && onRetry != null)
                          IconButton(
                            tooltip: 'Retry',
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }
}
