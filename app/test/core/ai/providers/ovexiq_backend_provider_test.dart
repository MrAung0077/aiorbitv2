import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aiorbit/core/ai/ai_chunk.dart';
import 'package:aiorbit/core/ai/ai_message.dart';
import 'package:aiorbit/core/ai/ai_request.dart';
import 'package:aiorbit/core/ai/ai_request_failure.dart';
import 'package:aiorbit/core/ai/ai_router.dart';
import 'package:aiorbit/core/ai/ai_service.dart';
import 'package:aiorbit/core/ai/providers/ovexiq_backend_api_client.dart';
import 'package:aiorbit/core/ai/providers/ovexiq_backend_provider.dart';
import 'package:aiorbit/core/text/response_language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const messages = <AIMessage>[
    AIMessage(role: AIMessageRole.system, content: 'Be concise.'),
    AIMessage(role: AIMessageRole.user, content: 'Research Kaspa.'),
    AIMessage(role: AIMessageRole.assistant, content: 'Prior accepted result.'),
    AIMessage(role: AIMessageRole.user, content: 'Summarize it.'),
  ];

  test('backend client preserves ordered message roles and content', () async {
    Map<String, dynamic>? requestBody;
    late http.Request capturedRequest;
    final client = _client((request) async {
      capturedRequest = request;
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _successResponse();
    });

    await client.complete(
      const AIRequest(
        messages: messages,
        temperature: 0.4,
        maxTokens: 800,
        metadata: <String, Object?>{
          'missionId': 'mission-1',
          'taskId': 'task-2',
        },
      ),
    );

    expect(capturedRequest.url.toString(), endsWith('/v1/ai/complete'));
    expect(capturedRequest.headers['x-ovexiq-beta-token'], 'tester-token');
    expect(requestBody!['messages'], <Object?>[
      <String, Object?>{'role': 'system', 'content': 'Be concise.'},
      <String, Object?>{'role': 'user', 'content': 'Research Kaspa.'},
      <String, Object?>{
        'role': 'assistant',
        'content': 'Prior accepted result.',
      },
      <String, Object?>{'role': 'user', 'content': 'Summarize it.'},
    ]);
    expect(requestBody!['temperature'], 0.4);
    expect(requestBody!['maxTokens'], 800);
    expect(requestBody!['response_language'], 'auto');
    expect(requestBody!['metadata'], <String, Object?>{
      'missionId': 'mission-1',
      'taskId': 'task-2',
    });
  });

  test(
    'backend client sends the selected response language contract',
    () async {
      Map<String, dynamic>? requestBody;
      final client = _client((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _successResponse();
      });

      await client.complete(
        const AIRequest(
          messages: messages,
          responseLanguage: ResponseLanguage.burmese,
        ),
      );

      expect(requestBody!['response_language'], 'my');
    },
  );

  test(
    'backend client sends the opaque device session with beta token',
    () async {
      late http.Request capturedRequest;
      final client = _client((request) async {
        capturedRequest = request;
        return _successResponse();
      }, deviceSession: 'opaque-device-session');

      await client.complete(const AIRequest(messages: messages));

      expect(
        capturedRequest.headers['x-ovexiq-device-session'],
        'opaque-device-session',
      );
      expect(capturedRequest.headers['x-ovexiq-beta-token'], 'tester-token');
    },
  );

  test(
    'authorization rejection invalidates only the session callback',
    () async {
      var invalidations = 0;
      final client = _client(
        (_) async => http.Response('{"error":{"code":"unauthorized"}}', 401),
        deviceSession: 'opaque-device-session',
        onAuthorizationRejected: () async {
          invalidations++;
        },
      );

      await expectLater(
        client.complete(const AIRequest(messages: messages)),
        throwsA(
          isA<AIRequestFailure>()
              .having(
                (failure) => failure.category,
                'category',
                AIRequestFailureCategory.authentication,
              )
              .having((failure) => failure.retryable, 'retryable', isFalse)
              .having((failure) => failure.statusCode, 'status code', 401),
        ),
      );

      expect(invalidations, 1);
    },
  );

  test('complete maps the normalized backend response to AIResponse', () async {
    final provider = OvexiqBackendProvider(
      _client((_) async => _successResponse()),
    );

    final response = await provider.complete(
      const AIRequest(messages: messages),
    );

    expect(response.content, 'Gateway result');
    expect(response.model, 'gateway-model');
    expect(response.promptTokens, 42);
    expect(response.completionTokens, 17);
    expect(response.metadata['requestId'], 'gateway-request-id');
    expect(response.metadata['backend'], isTrue);
  });

  test('stream adapts one backend completion into existing chunks', () async {
    final provider = OvexiqBackendProvider(
      _client((_) async => _successResponse()),
    );

    final chunks = await provider
        .stream(const AIRequest(messages: messages))
        .toList();

    expect(chunks.map((chunk) => chunk.type), <AIChunkType>[
      AIChunkType.status,
      AIChunkType.text,
      AIChunkType.usage,
      AIChunkType.done,
    ]);
    expect(chunks[1].text, 'Gateway result');
    expect(chunks[2].promptTokens, 42);
    expect(chunks[2].completionTokens, 17);
  });

  test('backend failure remains sanitized through AIService', () async {
    const leakedBody =
        'provider-secret-value raw provider payload and stack trace';
    final provider = OvexiqBackendProvider(
      _client((_) async => http.Response(leakedBody, 502)),
    );
    final service = AIService(
      router: AIRouter(providers: <OvexiqBackendProvider>[provider]),
    );

    await expectLater(
      service.complete(const AIRequest(messages: messages)),
      throwsA(
        isA<AIRequestFailure>()
            .having(
              (error) => error.toString(),
              'safe failure',
              contains('Ovexiq AI is temporarily unavailable.'),
            )
            .having(
              (error) => error.toString(),
              'provider secret',
              isNot(contains('provider-secret-value')),
            )
            .having(
              (error) => error.toString(),
              'raw payload',
              isNot(contains('raw provider payload')),
            ),
      ),
    );
  });

  test(
    'maps DNS lookup failures as retryable without raw socket text',
    () async {
      const leakedSocketText = 'Failed host lookup: private-host.example';
      final client = _client(
        (_) => Future<http.Response>.error(
          const SocketException(leakedSocketText),
        ),
      );

      await expectLater(
        client.complete(const AIRequest(messages: messages)),
        throwsA(
          isA<AIRequestFailure>()
              .having(
                (failure) => failure.category,
                'category',
                AIRequestFailureCategory.dnsFailure,
              )
              .having((failure) => failure.retryable, 'retryable', isTrue)
              .having(
                (failure) => failure.diagnosticReason,
                'safe reason',
                'dns_lookup_failed',
              )
              .having(
                (failure) => failure.diagnosticSummary,
                'no raw socket text',
                isNot(contains('private-host.example')),
              ),
        ),
      );
    },
  );

  test('maps connection timeout socket failures as retryable', () async {
    final client = _client(
      (_) => Future<http.Response>.error(
        const SocketException('Connection timed out'),
      ),
    );

    await expectLater(
      client.complete(const AIRequest(messages: messages)),
      throwsA(
        isA<AIRequestFailure>()
            .having(
              (failure) => failure.category,
              'category',
              AIRequestFailureCategory.connectionTimeout,
            )
            .having((failure) => failure.retryable, 'retryable', isTrue),
      ),
    );
  });

  test('maps offline socket failures as retryable', () async {
    final client = _client(
      (_) => Future<http.Response>.error(
        const SocketException('Network is unreachable'),
      ),
    );

    await expectLater(
      client.complete(const AIRequest(messages: messages)),
      throwsA(
        isA<AIRequestFailure>()
            .having(
              (failure) => failure.category,
              'category',
              AIRequestFailureCategory.networkOffline,
            )
            .having((failure) => failure.retryable, 'retryable', isTrue),
      ),
    );
  });

  test('maps explicit cancellation as non-retryable', () async {
    final client = _client(
      (_) => Future<http.Response>.error(
        http.ClientException('Request cancelled'),
      ),
    );

    await expectLater(
      client.complete(const AIRequest(messages: messages)),
      throwsA(
        isA<AIRequestFailure>()
            .having(
              (failure) => failure.category,
              'category',
              AIRequestFailureCategory.cancelled,
            )
            .having((failure) => failure.retryable, 'retryable', isFalse),
      ),
    );
  });

  test('maps request timeout as retryable', () async {
    final completer = Completer<http.Response>();
    final client = _client(
      (_) => completer.future,
      timeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      client.complete(const AIRequest(messages: messages)),
      throwsA(
        isA<AIRequestFailure>()
            .having(
              (failure) => failure.category,
              'category',
              AIRequestFailureCategory.requestTimeout,
            )
            .having((failure) => failure.retryable, 'retryable', isTrue),
      ),
    );
  });

  test(
    'maps authentication, rate, invalid request, and server statuses',
    () async {
      final cases =
          <({int status, AIRequestFailureCategory category, bool retryable})>[
            (
              status: 403,
              category: AIRequestFailureCategory.authentication,
              retryable: false,
            ),
            (
              status: 408,
              category: AIRequestFailureCategory.requestTimeout,
              retryable: true,
            ),
            (
              status: 429,
              category: AIRequestFailureCategory.rateLimited,
              retryable: true,
            ),
            (
              status: 422,
              category: AIRequestFailureCategory.invalidRequest,
              retryable: false,
            ),
            (
              status: 500,
              category: AIRequestFailureCategory.serverError,
              retryable: true,
            ),
          ];

      for (final entry in cases) {
        final client = _client(
          (_) => Future<http.Response>.value(
            http.Response('{"error":{"code":"safe_code"}}', entry.status),
          ),
        );

        await expectLater(
          client.complete(const AIRequest(messages: messages)),
          throwsA(
            isA<AIRequestFailure>()
                .having(
                  (failure) => failure.category,
                  'category',
                  entry.category,
                )
                .having(
                  (failure) => failure.retryable,
                  'retryable',
                  entry.retryable,
                )
                .having(
                  (failure) => failure.statusCode,
                  'status',
                  entry.status,
                ),
          ),
        );
      }
    },
  );

  test('retains a safe Retry-After delay for a gateway rate limit', () async {
    final client = _client(
      (_) async => http.Response(
        '{"error":{"code":"rate_limited"}}',
        429,
        headers: const <String, String>{'Retry-After': '60'},
      ),
    );

    await expectLater(
      client.complete(const AIRequest(messages: messages)),
      throwsA(
        isA<AIRequestFailure>()
            .having(
              (failure) => failure.category,
              'category',
              AIRequestFailureCategory.rateLimited,
            )
            .having(
              (failure) => failure.retryAfter,
              'retry after',
              const Duration(seconds: 60),
            ),
      ),
    );
  });

  test(
    'maps an explicit upstream failure separately from a generic server error',
    () async {
      final client = _client(
        (_) => Future<http.Response>.value(
          http.Response(
            '{"error":{"code":"provider_unavailable"},"requestId":"safe-request-1"}',
            503,
          ),
        ),
      );

      await expectLater(
        client.complete(const AIRequest(messages: messages)),
        throwsA(
          isA<AIRequestFailure>()
              .having(
                (failure) => failure.category,
                'category',
                AIRequestFailureCategory.providerUnavailable,
              )
              .having(
                (failure) => failure.correlationId,
                'safe correlation id',
                'safe-request-1',
              )
              .having((failure) => failure.retryable, 'retryable', isTrue),
        ),
      );
    },
  );

  test('maps malformed and empty gateway responses explicitly', () async {
    for (final body in <String>['not-json', '{"content":"  "}']) {
      final client = _client(
        (_) => Future<http.Response>.value(http.Response(body, 200)),
      );

      await expectLater(
        client.complete(const AIRequest(messages: messages)),
        throwsA(
          isA<AIRequestFailure>()
              .having(
                (failure) => failure.category,
                'category',
                AIRequestFailureCategory.invalidResponse,
              )
              .having((failure) => failure.retryable, 'retryable', isTrue),
        ),
      );
    }
  });

  test(
    'unknown exceptions produce a safe diagnostic without leaked content',
    () async {
      const secret = 'do-not-log-beta-token-or-request-prompt';
      final client = _client(
        (_) => Future<http.Response>.error(StateError(secret)),
      );

      await expectLater(
        client.complete(const AIRequest(messages: messages)),
        throwsA(
          isA<AIRequestFailure>()
              .having(
                (failure) => failure.category,
                'category',
                AIRequestFailureCategory.unknown,
              )
              .having(
                (failure) => failure.diagnosticSummary,
                'safe diagnostic',
                isNot(contains(secret)),
              )
              .having(
                (failure) => failure.toString(),
                'safe message',
                isNot(contains(secret)),
              ),
        ),
      );
    },
  );
}

OvexiqBackendApiClient _client(
  Future<http.Response> Function(http.Request request) handler, {
  String? deviceSession,
  Future<void> Function()? onAuthorizationRejected,
  Duration timeout = const Duration(seconds: 60),
}) {
  return OvexiqBackendApiClient(
    baseUrl: 'https://gateway.example.test',
    betaAccessToken: 'tester-token',
    deviceSession: deviceSession,
    onAuthorizationRejected: onAuthorizationRejected,
    httpClient: MockClient(handler),
    timeout: timeout,
  );
}

http.Response _successResponse() {
  return http.Response(
    jsonEncode(<String, Object?>{
      'content': ' Gateway result ',
      'model': 'gateway-model',
      'requestId': 'gateway-request-id',
      'usage': <String, Object?>{'promptTokens': 42, 'completionTokens': 17},
    }),
    200,
    headers: <String, String>{'Content-Type': 'application/json'},
  );
}
