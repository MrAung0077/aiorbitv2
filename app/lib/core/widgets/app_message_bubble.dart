import 'package:flutter/material.dart';

import '../../features/chat/models/chat_message.dart';
import '../../features/chat/models/message_feedback.dart';
import '../design/app_radius.dart';
import '../design/app_shadows.dart';

class AppMessageBubble extends StatelessWidget {
  const AppMessageBubble({
    super.key,
    required this.message,
    this.onCopy,
    this.onRetry,
    this.onLike,
    this.onDislike,
    this.onRegenerate,
    this.feedback = MessageFeedback.none,
    this.providerName,
    this.isStreaming = false,
    this.showAvatar = false,
    this.showTimestamp = false,
  });

  final ChatMessage message;
  final VoidCallback? onCopy;
  final VoidCallback? onRetry;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onRegenerate;

  final MessageFeedback feedback;
  final String? providerName;
  final bool isStreaming;
  final bool showAvatar;
  final bool showTimestamp;

  bool get _isUser => message.role == ChatRole.user;

  bool get _isLiked => feedback == MessageFeedback.liked;

  bool get _isDisliked => feedback == MessageFeedback.disliked;

  bool get _showProviderBadge {
    // Production UI:
    // Hide provider badges (OpenAI, Gemini, Claude, etc.)
    // Keep provider metadata internally for debugging and future developer mode.
    return false;
  }

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

    final messageContent = !_isUser && isStreaming
        ? '${message.content}▋'
        : message.content;

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
          Flexible(
            child: ConstrainedBox(
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
                    if (_showProviderBadge) ...[
                      _ProviderBadge(providerName: providerName!.trim()),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      messageContent,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                    if (showTimestamp) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(message.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: foreground.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                    if (!_isUser && !isStreaming) ...[
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
                          if (!message.isError && onLike != null)
                            IconButton(
                              tooltip: _isLiked
                                  ? 'Remove positive feedback'
                                  : 'Good response',
                              visualDensity: VisualDensity.compact,
                              iconSize: 18,
                              color: _isLiked ? colorScheme.primary : null,
                              onPressed: onLike,
                              icon: Icon(
                                _isLiked
                                    ? Icons.thumb_up_alt
                                    : Icons.thumb_up_alt_outlined,
                              ),
                            ),
                          if (!message.isError && onDislike != null)
                            IconButton(
                              tooltip: _isDisliked
                                  ? 'Remove negative feedback'
                                  : 'Bad response',
                              visualDensity: VisualDensity.compact,
                              iconSize: 18,
                              color: _isDisliked ? colorScheme.primary : null,
                              onPressed: onDislike,
                              icon: Icon(
                                _isDisliked
                                    ? Icons.thumb_down_alt
                                    : Icons.thumb_down_alt_outlined,
                              ),
                            ),
                          if (!message.isError && onRegenerate != null)
                            IconButton(
                              tooltip: 'Regenerate',
                              visualDensity: VisualDensity.compact,
                              iconSize: 18,
                              onPressed: onRegenerate,
                              icon: const Icon(Icons.refresh_rounded),
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

class _ProviderBadge extends StatelessWidget {
  const _ProviderBadge({required this.providerName});

  final String providerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 6),
            Text(
              providerName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
