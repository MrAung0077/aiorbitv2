import 'dart:convert';

import 'package:aiorbit/core/ai/ai_message.dart';
import 'package:aiorbit/core/ai/providers/gemini_api_client.dart';
import 'package:aiorbit/core/ai/providers/openai_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const messages = <AIMessage>[
    AIMessage(
      role: AIMessageRole.user,
      content: 'Research Kaspa smart contracts',
    ),
    AIMessage(
      role: AIMessageRole.assistant,
      content: 'Kaspa smart contracts research result',
    ),
    AIMessage(role: AIMessageRole.user, content: 'Summarize it in 3 bullets'),
  ];

  test('OpenAI request contains ordered role-preserving history', () async {
    Map<String, dynamic>? requestBody;
    final client = OpenAIAPIClient(
      apiKey: 'test-key',
      defaultModel: 'test-model',
      httpClient: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, Object?>{
            'id': 'response-id',
            'model': 'test-model',
            'output': <Object?>[
              <String, Object?>{
                'content': <Object?>[
                  <String, Object?>{'type': 'output_text', 'text': 'Summary'},
                ],
              },
            ],
          }),
          200,
        );
      }),
    );

    await client.createResponse(messages: messages);

    expect(requestBody!['input'], <Object?>[
      <String, Object?>{
        'role': 'user',
        'content': 'Research Kaspa smart contracts',
      },
      <String, Object?>{
        'role': 'assistant',
        'content': 'Kaspa smart contracts research result',
      },
      <String, Object?>{'role': 'user', 'content': 'Summarize it in 3 bullets'},
    ]);
  });

  test('Gemini request contains ordered role-preserving history', () async {
    Map<String, dynamic>? requestBody;
    final client = GeminiAPIClient(
      apiKey: 'test-key',
      defaultModel: 'test-model',
      httpClient: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, Object?>{
            'candidates': <Object?>[
              <String, Object?>{
                'content': <String, Object?>{
                  'parts': <Object?>[
                    <String, Object?>{'text': 'Summary'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    await client.createResponse(messages: messages);

    expect(requestBody!['contents'], <Object?>[
      <String, Object?>{
        'role': 'user',
        'parts': <Object?>[
          <String, Object?>{'text': 'Research Kaspa smart contracts'},
        ],
      },
      <String, Object?>{
        'role': 'model',
        'parts': <Object?>[
          <String, Object?>{'text': 'Kaspa smart contracts research result'},
        ],
      },
      <String, Object?>{
        'role': 'user',
        'parts': <Object?>[
          <String, Object?>{'text': 'Summarize it in 3 bullets'},
        ],
      },
    ]);
  });
}
