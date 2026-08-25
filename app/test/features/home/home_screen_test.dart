import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aiorbit/core/ai/ai.dart';
import 'package:aiorbit/core/ai/providers/ovexiq_image_api_client.dart';
import 'package:aiorbit/features/chat/models/chat_message.dart';
import 'package:aiorbit/features/chat/models/conversation.dart';
import 'package:aiorbit/features/chat/providers/chat_controller.dart';
import 'package:aiorbit/features/chat/providers/chat_image_generation_provider.dart';
import 'package:aiorbit/features/chat/repositories/conversation_repository.dart';
import 'package:aiorbit/features/chat/services/ai_chat_service.dart';
import 'package:aiorbit/features/chat/services/chat_image_generation_service.dart';
import 'package:aiorbit/features/chat/services/local_generated_image_result_store.dart';
import 'package:aiorbit/features/home/home_screen.dart';
import 'package:aiorbit/features/mission/providers/mission_provider.dart';
import 'package:aiorbit/features/mission/services/memory_mission_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Home history failure keeps goal actions and retry restores history',
    (tester) async {
      final latest = _conversation(
        id: 'latest',
        title: 'Continue beta mission',
        updatedAt: DateTime(2026, 8, 11),
      );
      final older = _conversation(
        id: 'older',
        title: 'Earlier beta mission',
        updatedAt: DateTime(2026, 8, 10),
      );
      final repository = _FailOnceConversationRepository(<Conversation>[
        latest,
        older,
      ]);
      final container = ProviderContainer(
        overrides: <Override>[
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(chatControllerProvider.notifier)
          .loadConversation(latest.id);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Send'), findsOneWidget);
      expect(find.text('Quick start'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Could not load conversations'),
        400,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Please try again.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      expect(repository.readCount, 1);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(repository.readCount, 2);
      await tester.scrollUntilVisible(
        find.text('Continue beta mission'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Continue beta mission'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Earlier beta mission'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Earlier beta mission'), findsOneWidget);
      expect(find.text('Could not load conversations'), findsNothing);
    },
  );

  testWidgets('Home preserves genuinely empty history behavior', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(
          _MemoryConversationRepository(const <Conversation>[]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Send'), findsOneWidget);
    expect(find.text('Quick start'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Could not load conversations'), findsNothing);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets(
    'Home keeps its core actions without a placeholder Account action',
    (tester) async {
      final updatedAt = DateTime(2026, 8, 11);
      final conversation = Conversation(
        id: 'continue-conversation',
        title: 'Continue beta mission',
        messages: <ChatMessage>[
          ChatMessage(
            id: 'user-message',
            role: ChatRole.user,
            content: 'Prepare my beta launch plan',
            createdAt: updatedAt,
          ),
        ],
        createdAt: updatedAt,
        updatedAt: updatedAt,
      );
      final container = ProviderContainer(
        overrides: <Override>[
          conversationRepositoryProvider.overrideWithValue(
            _MemoryConversationRepository(<Conversation>[conversation]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Account'), findsNothing);
      expect(
        find.text(
          'Tell Ovexiq your goal. It will help you move from idea to finished result.',
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Send'), findsOneWidget);
      expect(find.text('Quick start'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Research'), findsOneWidget);
      expect(find.text('Write'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Continue beta mission'),
        400,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Continue beta mission'), findsOneWidget);
    },
  );

  testWidgets(
    'Home first image prompt preserves its action through Chat navigation',
    (tester) async {
      final repository = _MemoryConversationRepository(const <Conversation>[]);
      final imageCompleter = Completer<GeneratedImage>();
      final imageGenerator = _FakeChatImageGenerator(
        (_) => imageCompleter.future,
      );
      final imageStoreDirectory = await Directory.systemTemp.createTemp(
        'aiorbit-home-image-',
      );
      addTearDown(() => imageStoreDirectory.delete(recursive: true));
      final aiChatService = _SuccessfulAIChatService();
      final container = ProviderContainer(
        overrides: <Override>[
          conversationRepositoryProvider.overrideWithValue(repository),
          aiChatServiceProvider.overrideWithValue(aiChatService),
          missionRepositoryProvider.overrideWithValue(
            MemoryMissionRepository(),
          ),
          chatImageGenerationServiceProvider.overrideWithValue(imageGenerator),
          generatedImageResultStoreProvider.overrideWithValue(
            _FakeGeneratedImageResultStore(
              await _writeTestImage(imageStoreDirectory),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'Create a peaceful picture of Buddha meditating under a bodhi tree.',
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Ovexiq is creating your image...'), findsOneWidget);
      expect(imageGenerator.prompts, <String>[
        'Buddha meditating under a bodhi tree',
      ]);
      expect(aiChatService.requests, isEmpty);

      final conversation = container.read(chatControllerProvider).conversation!;
      expect(
        conversation.messages.where((message) => message.role == ChatRole.user),
        hasLength(1),
      );
      expect(
        (await repository.getConversation(conversation.id))!.messages,
        hasLength(1),
      );

      imageCompleter.complete(_testGeneratedImage());
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(
        find.byKey(const ValueKey<String>('generated-image-card')),
        findsOneWidget,
      );
      expect(imageGenerator.prompts, hasLength(1));
    },
    skip: true,
  );

  testWidgets('Home first normal prompt still opens Chat with one response', (
    tester,
  ) async {
    final repository = _MemoryConversationRepository(const <Conversation>[]);
    final aiChatService = _SuccessfulAIChatService();
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(repository),
        aiChatServiceProvider.overrideWithValue(aiChatService),
        missionRepositoryProvider.overrideWithValue(MemoryMissionRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'What is a budget?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('A budget is a spending plan.'), findsOneWidget);
    expect(aiChatService.requests, hasLength(1));
    expect(
      container
          .read(chatControllerProvider)
          .messages
          .where((message) => message.role == ChatRole.user),
      hasLength(1),
    );
  });

  testWidgets('Home first image failure shows a friendly Chat message', (
    tester,
  ) async {
    final repository = _MemoryConversationRepository(const <Conversation>[]);
    final imageCompleter = Completer<GeneratedImage>();
    final imageGenerator = _FakeChatImageGenerator(
      (_) => imageCompleter.future,
    );
    final container = ProviderContainer(
      overrides: <Override>[
        conversationRepositoryProvider.overrideWithValue(repository),
        aiChatServiceProvider.overrideWithValue(_SuccessfulAIChatService()),
        missionRepositoryProvider.overrideWithValue(MemoryMissionRepository()),
        chatImageGenerationServiceProvider.overrideWithValue(imageGenerator),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'Create a peaceful picture of Buddha meditating under a bodhi tree.',
    );
    await tester.tap(find.byTooltip('Send'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    imageCompleter.completeError(StateError('raw provider error'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ovexiq couldn’t create that image. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('provider error'), findsNothing);
    expect(imageGenerator.prompts, hasLength(1));
  });
}

class _SuccessfulAIChatService extends AIChatService {
  final List<List<AIMessage>> requests = <List<AIMessage>>[];

  @override
  Stream<AIChunk> sendMessages(List<AIMessage> messages) async* {
    requests.add(List<AIMessage>.of(messages));
    yield const AIChunk.text(
      provider: ProviderType.openAI,
      text: 'A budget is a spending plan.',
    );
    yield const AIChunk.done(provider: ProviderType.openAI);
  }
}

class _FakeChatImageGenerator extends ChatImageGenerator {
  _FakeChatImageGenerator(this._onGenerate);

  final Future<GeneratedImage> Function(String prompt) _onGenerate;
  final List<String> prompts = <String>[];

  @override
  Future<GeneratedImage> generate({required String prompt}) {
    prompts.add(prompt);
    return _onGenerate(prompt);
  }
}

class _FakeGeneratedImageResultStore implements GeneratedImageResultStore {
  const _FakeGeneratedImageResultStore(this._path);

  final String _path;

  @override
  Future<String> savePng({
    required String conversationId,
    required String sourceMessageId,
    required Uint8List bytes,
  }) async => _path;
}

Future<String> _writeTestImage(Directory directory) async {
  final file = File('${directory.path}${Platform.pathSeparator}image.png');
  await file.writeAsBytes(_testGeneratedImage().bytes, flush: true);
  return file.path;
}

GeneratedImage _testGeneratedImage() {
  return GeneratedImage(
    mimeType: 'image/png',
    bytes: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
    ),
  );
}

class _MemoryConversationRepository extends ConversationRepository {
  _MemoryConversationRepository(Iterable<Conversation> conversations)
    : _items = <String, Conversation>{
        for (final conversation in conversations) conversation.id: conversation,
      };

  final Map<String, Conversation> _items;

  @override
  Future<List<Conversation>> getAllConversations() async {
    final conversations = _items.values.toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  @override
  Future<Conversation?> getConversation(String conversationId) async {
    return _items[conversationId];
  }

  @override
  Future<void> saveConversation(Conversation conversation) async {
    _items[conversation.id] = conversation;
  }
}

class _FailOnceConversationRepository extends _MemoryConversationRepository {
  _FailOnceConversationRepository(super.conversations);

  int readCount = 0;

  @override
  Future<List<Conversation>> getAllConversations() async {
    readCount++;

    if (readCount == 1) {
      throw StateError('Temporary read failure');
    }

    return super.getAllConversations();
  }
}

Conversation _conversation({
  required String id,
  required String title,
  required DateTime updatedAt,
}) {
  return Conversation(
    id: id,
    title: title,
    messages: <ChatMessage>[
      ChatMessage(
        id: '$id-message',
        role: ChatRole.user,
        content: 'Prompt for $title',
        createdAt: updatedAt,
      ),
    ],
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}
