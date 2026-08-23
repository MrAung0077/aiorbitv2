import 'dart:convert';
import 'dart:typed_data';

import 'package:aiorbit/core/ai/providers/ovexiq_image_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('posts a trimmed prompt to the isolated image gateway endpoint', () async {
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
  });

  test('sanitizes gateway failures and malformed image data', () async {
    const leakedBody = 'provider secret raw backend stack trace';
    final failedClient = _client((_) async => http.Response(leakedBody, 502));
    final malformedClient = _client(
      (_) async => http.Response(
        jsonEncode(<String, Object?>{
          'image': <String, String>{
            'mimeType': 'image/png',
            'base64': '@@@',
          },
        }),
        200,
      ),
    );
    addTearDown(failedClient.close);
    addTearDown(malformedClient.close);

    for (final client in <OvexiqImageApiClient>[failedClient, malformedClient]) {
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
}

OvexiqImageApiClient _client(
  Future<http.Response> Function(http.Request request) handler,
) {
  return OvexiqImageApiClient(
    baseUrl: 'https://gateway.example.test',
    betaAccessToken: 'tester-token',
    httpClient: MockClient(handler),
  );
}
