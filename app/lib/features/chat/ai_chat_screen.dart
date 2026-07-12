import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/chat_message.dart';
import 'models/conversation.dart';
import 'services/ai_chat_service.dart';
import 'services/conversation_service.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final AIChatService _chatService = AIChatService();
  final ConversationService _conversationService = ConversationService();

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late Conversation _currentConversation;
  bool _isSending = false;

  List<ChatMessage> get _messages => _currentConversation.messages;

  @override
  void initState() {
    super.initState();
    _currentConversation = _conversationService.createConversation();
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

    if (text.isEmpty || _isSending) return;

    final now = DateTime.now();
    final conversationId = _currentConversation.id;

    final userMessage = ChatMessage(
      id: now.microsecondsSinceEpoch.toString(),
      role: ChatRole.user,
      content: text,
      createdAt: now,
    );

    setState(() {
      _currentConversation = _conversationService.addMessage(
        conversationId: conversationId,
        message: userMessage,
      );
      _isSending = true;
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final reply = await _chatService.sendMessage(text);

      if (!mounted) return;

      final assistantMessage = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        role: ChatRole.assistant,
        content: reply,
        createdAt: DateTime.now(),
      );

      final updatedConversation = _conversationService.addMessage(
        conversationId: conversationId,
        message: assistantMessage,
      );

      if (!mounted) return;

      setState(() {
        if (_currentConversation.id == conversationId) {
          _currentConversation = updatedConversation;
        }
      });
    } catch (_) {
      if (!mounted) return;

      final errorMessage = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        role: ChatRole.assistant,
        content: 'Something went wrong. Please try again.',
        createdAt: DateTime.now(),
        isError: true,
      );

      final updatedConversation = _conversationService.addMessage(
        conversationId: conversationId,
        message: errorMessage,
      );

      if (!mounted) return;

      setState(() {
        if (_currentConversation.id == conversationId) {
          _currentConversation = updatedConversation;
        }
      });
    } finally {
      if (!mounted) return;

      setState(() => _isSending = false);
      _scrollToBottom();
      _focusNode.requestFocus();
    }
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

  void _newConversation() {
    if (_isSending) return;

    setState(() {
      _currentConversation = _conversationService.createConversation();
    });

    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentConversation.title),
        actions: [
          IconButton(
            tooltip: 'New Chat',
            onPressed: _isSending ? null : _newConversation,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? const _EmptyChatView()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isSending && index == _messages.length) {
                          return const _TypingBubble();
                        }

                        final message = _messages[index];

                        return _ChatBubble(
                          message: message,
                          onCopy: () => _copyMessage(message.content),
                        );
                      },
                    ),
            ),
            _ChatInput(
              controller: _controller,
              focusNode: _focusNode,
              isSending: _isSending,
              onSend: _sendMessage,
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.onCopy});

  final ChatMessage message;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final colorScheme = Theme.of(context).colorScheme;

    final backgroundColor = message.isError
        ? colorScheme.errorContainer
        : isUser
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;

    final textColor = message.isError
        ? colorScheme.onErrorContainer
        : isUser
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.content, style: TextStyle(color: textColor)),
              if (!isUser) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Copy message',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text('AI is typing...'),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
                enabled: !isSending,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Message AIOrbit...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Send message',
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
