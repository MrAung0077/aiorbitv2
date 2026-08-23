import 'dart:convert';

import 'package:aiorbit/core/ai/providers/ovexiq_image_api_client.dart';
import 'package:aiorbit/features/chat/services/chat_image_generation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('delegates image generation to the dedicated gateway client', () async {
    String? sentPrompt;
    final client = OvexiqImageApiClient(
      baseUrl: 'https://gateway.example.test',
      betaAccessToken: 'tester-token',
      httpClient: MockClient((request) async {
        sentPrompt = (jsonDecode(request.body) as Map<String, dynamic>)['prompt']
            as String;
        return http.Response(
          jsonEncode(<String, Object?>{
            'image': <String, String>{
              'mimeType': 'image/png',
              'base64': base64Encode(<int>[1]),
            },
          }),
          200,
        );
      }),
    );
    addTearDown(client.close);
    final service = ChatImageGenerationService(imageApiClient: client);

    final image = await service.generate(prompt: 'Buddha beneath a tree');

    expect(sentPrompt, 'Buddha beneath a tree');
    expect(image.bytes, isNotEmpty);
  });
}
