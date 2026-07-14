import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_conversation_header.dart';
import '../../core/widgets/app_message_bubble.dart';
import '../../core/widgets/app_prompt_composer.dart';
import '../../core/widgets/app_typing_indicator.dart';
import 'models/chat_message.dart';
import 'providers/chat_controller.dart';

class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({super.key});

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      if (!mounted) return;
      await ref
          .read(chatControllerProvider.notifier)
          .loadMostRecentConversation();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final chatState = ref.read(chatControllerProvider);

    if (text.isEmpty || chatState.isSending) return;

    final send = ref.read(chatControllerProvider.notifier).sendMessage(text);
    _controller.clear();
    _scrollToBottom();

    await send;

    if (!mounted) return;
    _scrollToBottom();
    _focusNode.requestFocus();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChatState>(chatControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          (previous?.isSending == true && !next.isSending)) {
        _scrollToBottom();
      }
    });

    final chatState = ref.watch(chatControllerProvider);
    final messages = chatState.messages;
    final hasError = chatState.error != null;

    return Scaffold(
      appBar: AppConversationHeader(
        title: chatState.conversation?.title ?? 'New Conversation',
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty && !hasError
                  ? const _EmptyChatView()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          messages.length +
                          (chatState.isSending ? 1 : 0) +
                          (hasError ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < messages.length) {
                          final message = messages[index];

                          return AppMessageBubble(
                            message: message,
                            onCopy: () => _copyMessage(message.content),
                          );
                        }

                        if (chatState.isSending && index == messages.length) {
                          return const AppTypingIndicator(
                            label: 'AI is typing...',
                          );
                        }

                        const errorMessage =
                            'Something went wrong. Please try again.';

                        return AppMessageBubble(
                          message: ChatMessage(
                            id: 'chat-error',
                            role: ChatRole.assistant,
                            content: errorMessage,
                            createdAt: DateTime.now(),
                            isError: true,
                          ),
                          onCopy: () => _copyMessage(errorMessage),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: AppPromptComposer(
                controller: _controller,
                focusNode: _focusNode,
                isSending: chatState.isSending,
                onSend: _sendMessage,
                hintText: 'Ask AIOrbit anything...',
                maxLines: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 64),
            const SizedBox(height: 16),
            Text(
              'Welcome to AIOrbit',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a new conversation.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
