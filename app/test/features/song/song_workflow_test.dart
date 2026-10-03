import 'dart:convert';
import 'dart:io';

import 'package:aiorbit/core/ai/ai.dart';
import 'package:aiorbit/features/chat/ai_chat_screen.dart';
import 'package:aiorbit/features/chat/models/conversation.dart';
import 'package:aiorbit/features/chat/providers/chat_controller.dart';
import 'package:aiorbit/features/chat/repositories/conversation_repository.dart';
import 'package:aiorbit/features/chat/services/ai_chat_service.dart';
import 'package:aiorbit/features/home/home_screen.dart';
import 'package:aiorbit/features/song/song_api.dart';
import 'package:aiorbit/features/song/song_models.dart';
import 'package:aiorbit/features/song/song_studio_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const projectId = '00000000-0000-4000-8000-000000000001';
Map<String, Object?> artifact(String name, String mime, int index) => {
  'id': '00000000-0000-4000-8000-00000000000$index',
  'fileName': name,
  'mimeType': mime,
  'byteSize': 3,
  'sha256': 'a' * 64,
};
Map<String, Object?> project({
  String status = 'completed',
  String language = 'en',
}) => {
  'projectId': projectId,
  'title': 'Morning',
  'status': status,
  'language': language,
  'lyrics': '[Verse 1]\nMorning comes\n[Chorus]\nBegin again',
  'createdAt': '2026-10-01T00:00:00Z',
  'artifacts': [
    artifact('lyrics.txt', 'text/plain', 1),
    artifact('song.mp3', 'audio/mpeg', 2),
    artifact('youtube.mp4', 'video/mp4', 3),
    artifact('teaser.mp4', 'video/mp4', 4),
  ],
};
SongApi apiWith(
  Future<http.Response> Function(http.Request) handler, {
  Future<void> Function()? invalidate,
}) => SongApi(
  baseUrl: 'https://api.example.test',
  token: 'synthetic-beta',
  session: () => 'synthetic-session',
  invalidateSession: invalidate ?? () async {},
  client: MockClient(handler),
);

class _HistoryApi extends SongApi {
  _HistoryApi(this.saved)
    : super(
        baseUrl: 'https://api.example.test',
        token: 'synthetic',
        session: () => 'synthetic',
        invalidateSession: () async {},
        client: MockClient((_) async {
          throw StateError('History must not submit work');
        }),
      );
  final Map<String, Object?> saved;
  final methods = <String>[];
  @override
  Future<Map<String, dynamic>> artist() async {
    methods.add('GET');
    return {'artistName': 'Ari', 'visualReferenceIds': <String>[]};
  }

  @override
  Future<List<SongProject>> projects() async {
    methods.add('GET');
    return [SongProject.fromJson(saved)];
  }
}

class _EmptyConversations extends ConversationRepository {
  int writes = 0;
  @override
  Future<List<Conversation>> getAllConversations() async => [];
  @override
  Future<void> saveConversation(Conversation value) async {
    writes++;
  }
}

class _NoChatGeneration extends AIChatService {
  int calls = 0;
  @override
  Stream<AIChunk> sendMessages(List<AIMessage> messages) {
    calls++;
    return Stream.error(
      StateError('Song must not use the old text/handoff path'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'song preferences default to generated voice and subtitles off; history preserves intent',
    () {
      final legacy = SongProject.fromJson(project());
      expect(legacy.preferences.voiceIntent, VoiceIntent.generated);
      expect(legacy.preferences.subtitles, SubtitlePreference.off);
      for (final intent in VoiceIntent.values) {
        final preferences = SongPreferences(
          voiceIntent: intent,
          subtitles: SubtitlePreference.requested,
          context: SongContext.album,
          style: 'slow rock',
          userFinalLyrics: '  မနက်ခင်း အလင်းရောင်\nနေ့သစ်  ',
          voicePermissionConfirmed: intent.needsPermission,
        );
        final reopened = SongProject.fromJson({
          ...project(),
          'preferences': preferences.toJson(),
        });
        expect(reopened.preferences.toJson(), preferences.toJson());
        for (final burmese in [false, true]) {
          expect(intent.label(burmese), isNot(equals(intent.wireValue)));
          expect(
            intent.label(burmese),
            isNot(
              matches(
                RegExp(
                  r'Suno|Kits|Lyria|ElevenLabs|Gemini|OpenRouter',
                  caseSensitive: false,
                ),
              ),
            ),
          );
        }
      }
    },
  );
  test(
    'create sends selected preflight preferences with final lyrics unchanged',
    () async {
      const preferences = SongPreferences(
        voiceIntent: VoiceIntent.customLockedVoice,
        subtitles: SubtitlePreference.requested,
        context: SongContext.reusableArtist,
        style: 'soft rock',
        userFinalLyrics: '  Final lyrics\nKeep this  ',
        voicePermissionConfirmed: true,
      );
      var calls = 0;
      final api = apiWith((request) async {
        calls++;
        expect(jsonDecode(request.body)['preferences'], preferences.toJson());
        expect(request.headers['X-Ovexiq-Device-Session'], 'synthetic-session');
        return http.Response(
          jsonEncode({...project(), 'preferences': preferences.toJson()}),
          202,
        );
      });
      addTearDown(api.close);
      final saved = await api.create(
        'An original song',
        'en',
        projectId,
        preferences: preferences,
      );
      expect(saved.preferences.toJson(), preferences.toJson());
      expect(calls, 1);
    },
  );
  for (final burmese in [false, true]) {
    testWidgets(
      'voice clarification is outcome-only, subtitles off, choices do not execute (${burmese ? 'my' : 'en'})',
      (tester) async {
        final api = _HistoryApi(project());
        addTearDown(api.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [songApiProvider.overrideWithValue(api)],
            child: MaterialApp(
              home: SongStudioScreen(
                initialGoal: burmese
                    ? 'မြန်မာလို သီချင်းဖန်တီးပေး'
                    : 'Create a song',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            burmese
                ? 'အဆိုတော်အသံကို ဘယ်လိုထားချင်လဲ?'
                : 'How would you like the singing voice?',
          ),
          findsOneWidget,
        );
        final voices = tester.widget<DropdownButton<VoiceIntent>>(
          find.byKey(const Key('song-voice-intent')),
        );
        expect(voices.items!.map((item) => item.value), VoiceIntent.values);
        expect(
          tester
              .widget<SwitchListTile>(find.byKey(const Key('song-subtitles')))
              .value,
          isFalse,
        );
        voices.onChanged!(VoiceIntent.ownVoiceClone);
        await tester.pumpAndSettle();
        expect(
          find.text(
            burmese
                ? 'ကိုယ့်အသံဖြစ်သည် သို့မဟုတ် အသုံးပြုခွင့် ရှိပါသည်။'
                : 'This is my voice, or I have permission to use it.',
          ),
          findsOneWidget,
        );
        tester
            .widget<SwitchListTile>(find.byKey(const Key('song-subtitles')))
            .onChanged!(true);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SwitchListTile>(find.byKey(const Key('song-subtitles')))
              .value,
          isTrue,
        );
        tester
            .widget<DropdownButton<VoiceIntent>>(
              find.byKey(const Key('song-voice-intent')),
            )
            .onChanged!(VoiceIntent.generated);
        await tester.pumpAndSettle();
        expect(
          find.text(
            burmese
                ? 'ကိုယ့်အသံဖြစ်သည် သို့မဟုတ် အသုံးပြုခွင့် ရှိပါသည်။'
                : 'This is my voice, or I have permission to use it.',
          ),
          findsNothing,
        );
        expect(api.methods, ['GET', 'GET']);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('unavailable capability history is truthful and passive', (
    tester,
  ) async {
    final api = _HistoryApi({
      ...project(status: 'failed'),
      'artifacts': [],
      'failure': {'code': 'subtitles_unavailable', 'stage': 'preflight'},
    });
    addTearDown(api.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [songApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: SongStudioScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Generation was not started'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Generation was not started'), findsOneWidget);
    expect(find.text('Files ready'), findsNothing);
    expect(api.methods, ['GET', 'GET']);
    await tester.pumpWidget(const SizedBox());
  });
  for (final home in [true, false]) {
    testWidgets(
      '${home ? 'Home' : 'Chat'} song goal opens preparation without text execution or duplicate bubbles',
      (tester) async {
        final repository = _EmptyConversations();
        final ai = _NoChatGeneration();
        final api = _HistoryApi(project());
        addTearDown(api.close);
        final container = ProviderContainer(
          overrides: [
            conversationRepositoryProvider.overrideWithValue(repository),
            aiChatServiceProvider.overrideWithValue(ai),
            songApiProvider.overrideWithValue(api),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: home ? const HomeScreen() : const AIChatScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        const goal = 'Create an original soft-rock song in English';
        await tester.enterText(find.byType(TextField).first, goal);
        await tester.tap(find.byTooltip('Send'));
        await tester.pumpAndSettle();
        expect(find.byType(SongStudioScreen), findsOneWidget);
        expect(find.text(goal), findsOneWidget);
        expect(repository.writes, 0);
        expect(ai.calls, 0);
        expect(api.methods, ['GET', 'GET']);
        expect(container.read(chatControllerProvider).messages, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  test(
    'direct English/Burmese songs route to media, lyric-only/planning stay text',
    () {
      expect(
        isOriginalSongRequest('Create an original soft-rock song in English.'),
        isTrue,
      );
      expect(
        isOriginalSongRequest('မြန်မာလို slow rock သီချင်းတစ်ပုဒ်လုပ်ပေး'),
        isTrue,
      );
      for (final goal in [
        'Create song ideas',
        'Create lyrics only for a song',
        'သီချင်းစာသားပဲ ရေးပေး',
        'Create a travel plan',
      ]) {
        expect(isOriginalSongRequest(goal), isFalse);
      }
    },
  );
  test(
    'typed artifacts reject paths, missing complete outputs and invalid identities',
    () {
      expect(SongProject.fromJson(project()).isComplete, isTrue);
      expect(
        SongProject.fromJson(project(status: 'failed')).isComplete,
        isFalse,
      );
      expect(
        () => SongArtifact.fromJson({
          ...artifact('song.mp3', 'audio/mpeg', 2),
          'fileName': '../secret.mp3',
        }),
        throwsFormatException,
      );
      expect(
        () => SongProject.fromJson({...project(), 'artifacts': []}),
        throwsFormatException,
      );
      expect(
        () => SongProject.fromJson({...project(), 'projectId': '../escape'}),
        throwsFormatException,
      );
      expect(
        newSongRequestId(),
        matches(
          RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
          ),
        ),
      );
    },
  );
  test(
    'create sends shared contract, original goal/language, both auth headers, no client owner',
    () async {
      final api = apiWith((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/media/projects');
        expect(request.headers['X-Ovexiq-Beta-Token'], 'synthetic-beta');
        expect(request.headers['X-Ovexiq-Device-Session'], 'synthetic-session');
        expect(request.headers.containsKey('X-Ovexiq-Account'), isFalse);
        expect(jsonDecode(request.body), {
          'goal': 'မူရင်း သီချင်းဖန်တီးပေး',
          'language': 'my',
          'requestId': projectId,
        });
        return http.Response(jsonEncode(project(language: 'my')), 202);
      });
      addTearDown(api.close);
      expect(
        (await api.create('မူရင်း သီချင်းဖန်တီးပေး', 'my', projectId)).language,
        'my',
      );
    },
  );
  test(
    'auth failure invalidates session once, no retry or credential/error-body exposure',
    () async {
      var calls = 0, invalidations = 0;
      final api = apiWith(
        (_) async {
          calls++;
          return http.Response(
            'private content synthetic-beta synthetic-session',
            401,
          );
        },
        invalidate: () async {
          invalidations++;
        },
      );
      addTearDown(api.close);
      try {
        await api.projects();
        fail('expected failure');
      } on SongFailure catch (e) {
        expect(e.code, 'unauthorized');
        expect(e.toString(), 'Song workflow unavailable');
      }
      expect(calls, 1);
      expect(invalidations, 1);
    },
  );
  test(
    'authenticated download verifies bytes; open/save/share pass only local metadata',
    () async {
      final root = await Directory.systemTemp.createTemp('ovexiq-song-client-');
      addTearDown(() => root.delete(recursive: true));
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      messenger.setMockMethodCallHandler(paths, (_) async => root.path);
      final actions = <String>[];
      messenger.setMockMethodCallHandler(SongDeviceFiles.channel, (call) async {
        actions.add(call.method);
        final args = Map<String, dynamic>.from(call.arguments as Map);
        expect(args.keys.toSet(), {'path', 'mimeType', 'fileName', 'sha256'});
        expect(args['path'], startsWith(root.path));
        expect(args['sha256'], 'a' * 64);
        return true;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(paths, null);
        messenger.setMockMethodCallHandler(SongDeviceFiles.channel, null);
      });
      var calls = 0;
      final api = apiWith((request) async {
        calls++;
        expect(request.method, 'GET');
        expect(request.url.path, contains('/artifacts/'));
        return http.Response.bytes(
          [1, 2, 3],
          200,
          headers: {'content-type': 'audio/mpeg'},
        );
      });
      addTearDown(api.close);
      final saved = SongProject.fromJson(project());
      final mp3 = saved.artifacts[1];
      final path = await api.download(saved, mp3);
      expect(await File(path).readAsBytes(), [1, 2, 3]);
      for (final action in ['open', 'save', 'share']) {
        expect(await SongDeviceFiles().perform(action, path, mp3), isTrue);
      }
      expect(await api.download(saved, mp3), path);
      expect(calls, 1);
      expect(actions, ['verify', 'open', 'save', 'share', 'verify']);
    },
  );
  testWidgets(
    'reopen shows MP3/MP4 actions and saved lyrics with zero execution',
    (tester) async {
      final api = _HistoryApi(project());
      addTearDown(api.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [songApiProvider.overrideWithValue(api)],
          child: const MaterialApp(home: SongStudioScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Files ready'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Files ready'), findsOneWidget);
      expect(find.text('Morning'), findsOneWidget);
      expect(find.textContaining('song.mp3'), findsOneWidget);
      expect(find.textContaining('youtube.mp4'), findsOneWidget);
      expect(find.textContaining('teaser.mp4'), findsOneWidget);
      expect(find.text('Download & open'), findsNWidgets(4));
      expect(find.text('Save'), findsNWidgets(4));
      expect(find.text('Share'), findsNWidgets(4));
      expect(api.methods, ['GET', 'GET']);
      expect(find.textContaining('Mission'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'partial failure retains outputs without claiming completion or auto retry',
    (tester) async {
      final api = _HistoryApi({
        ...project(status: 'failed'),
        'artifacts': [artifact('lyrics.txt', 'text/plain', 1)],
      });
      addTearDown(api.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [songApiProvider.overrideWithValue(api)],
          child: const MaterialApp(home: SongStudioScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Not completed'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Files ready'), findsNothing);
      expect(find.textContaining('lyrics.txt'), findsOneWidget);
      expect(api.methods, ['GET', 'GET']);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
