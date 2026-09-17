import 'dart:convert';

import 'package:aiorbit/features/beta_access/services/beta_access_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('valid activation exchanges an invite without exposing credentials', () async {
    late http.Request request;
    final client = BetaAccessApiClient(
      baseUrl: 'https://gateway.example.test',
      betaAccessToken: 'beta-token',
      httpClient: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode(<String, String>{
            'accountId': 'acct_example',
            'deviceSession': 'opaque-session',
            'recoveryCode': 'recovery-code',
          }),
          201,
        );
      }),
    );

    final result = await client.activate(
      inviteCode: 'invite-code',
      activationId: '00000000-0000-4000-8000-000000000001',
    );

    expect(request.url.path, '/v1/beta/activate');
    expect(request.headers['x-ovexiq-beta-token'], 'beta-token');
    expect(jsonDecode(request.body), <String, String>{
      'inviteCode': 'invite-code',
      'activationId': '00000000-0000-4000-8000-000000000001',
    });
    expect(result.deviceSession, 'opaque-session');
  });

  test('invalid invite is safe and returns no credential data', () async {
    const inviteCode = 'private-invite-code';
    final client = BetaAccessApiClient(
      baseUrl: 'https://gateway.example.test',
      betaAccessToken: 'beta-token',
      httpClient: MockClient(
        (_) async => http.Response(
          '{"error":{"code":"invalid_beta_invite"}}',
          401,
        ),
      ),
    );

    await expectLater(
      client.activate(
        inviteCode: inviteCode,
        activationId: '00000000-0000-4000-8000-000000000001',
      ),
      throwsA(
        isA<BetaAccessException>()
            .having((error) => error.failure, 'failure', BetaAccessFailure.invalidInvite)
            .having(
              (error) => error.userMessage,
              'does not expose invite',
              isNot(contains(inviteCode)),
            ),
      ),
    );
  });
}
