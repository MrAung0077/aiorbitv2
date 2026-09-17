import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:aiorbit/core/ai/providers/ovexiq_image_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'posts a trimmed prompt to the isolated image gateway endpoint',
    () async {
      http.Request? request;
      final client = _client((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode(<String, Object?>{
            'image': <String, String>{
              'mimeType': 'image/png',
              'base64': base64Encode(<int>[1, 2, 3]),
            },
          }),
          200,
        );
      });
      addTearDown(client.close);

      final image = await client.generate(prompt: '  Buddha meditating  ');

      expect(request!.method, 'POST');
      expect(request!.url.path, '/v1/ai/image');
      expect(request!.headers['content-type'], 'application/json');
      expect(request!.headers['x-ovexiq-beta-token'], 'tester-token');
      expect(jsonDecode(request!.body), <String, String>{
        'prompt': 'Buddha meditating',
      });
      expect(image.mimeType, 'image/png');
      expect(image.bytes, Uint8List.fromList(<int>[1, 2, 3]));
    },
  );

  test(
    'sends the opaque device session and clears it after authorization failure',
    () async {
      late http.Request capturedRequest;
      var invalidations = 0;
      final client = _client(
        (incoming) async {
          capturedRequest = incoming;
          return http.Response('{"error":{"code":"unauthorized"}}', 401);
        },
        deviceSession: 'opaque-device-session',
        onAuthorizationRejected: () async {
          invalidations++;
        },
      );
      addTearDown(client.close);

      await expectLater(
        client.generate(prompt: 'Buddha'),
        throwsA(isA<OvexiqImageApiException>()),
      );

      expect(
        capturedRequest.headers['x-ovexiq-device-session'],
        'opaque-device-session',
      );
      expect(invalidations, 1);
    },
  );

  test('sanitizes gateway failures and malformed image data', () async {
    const leakedBody = 'provider secret raw backend stack trace';
    final failedClient = _client((_) async => http.Response(leakedBody, 502));
    final malformedClient = _client(
      (_) async => http.Response(
        jsonEncode(<String, Object?>{
          'image': <String, String>{'mimeType': 'image/png', 'base64': '@@@'},
        }),
        200,
      ),
    );
    addTearDown(failedClient.close);
    addTearDown(malformedClient.close);

    for (final client in <OvexiqImageApiClient>[
      failedClient,
      malformedClient,
    ]) {
      await expectLater(
        client.generate(prompt: 'Buddha'),
        throwsA(
          isA<OvexiqImageApiException>()
              .having(
                (error) => error.message,
                'safe message',
                'Ovexiq couldn’t create that image. Please try again.',
              )
              .having(
                (error) => error.toString(),
                'raw backend data',
                isNot(contains('provider secret')),
              ),
        ),
      );
    }
  });

  test('cancels one dedicated image request distinctly', () async {
    final requestClient = _PendingHttpClient();
    final client = OvexiqImageApiClient(
      baseUrl: 'https://gateway.example.test',
      betaAccessToken: 'tester-token',
      httpClientFactory: () => requestClient,
    );

    final generation = client.startGeneration(prompt: 'Buddha');
    generation.cancel();
    generation.cancel();

    await expectLater(
      generation.result,
      throwsA(isA<OvexiqImageGenerationCancelled>()),
    );
    expect(requestClient.closeCount, 1);
  });
}

OvexiqImageApiClient _client(
  Future<http.Response> Function(http.Request request) handler, {
  String? deviceSession,
  Future<void> Function()? onAuthorizationRejected,
}) {
  return OvexiqImageApiClient(
    baseUrl: 'https://gateway.example.test',
    betaAccessToken: 'tester-token',
    deviceSession: deviceSession,
    onAuthorizationRejected: onAuthorizationRejected,
    httpClient: MockClient(handler),
  );
}

class _PendingHttpClient extends http.BaseClient {
  final Completer<http.StreamedResponse> _pending =
      Completer<http.StreamedResponse>();
  var closeCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _pending.future;
  }

  @override
  void close() {
    closeCount++;
  }
}
