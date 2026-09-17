import 'dart:convert';

import 'package:aiorbit/features/beta_access/models/beta_access_state.dart';
import 'package:aiorbit/features/beta_access/providers/beta_access_provider.dart';
import 'package:aiorbit/features/beta_access/services/beta_access_api_client.dart';
import 'package:aiorbit/features/beta_access/services/beta_access_secure_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('valid invitation stores an opaque session and restores it after restart', () async {
    final store = _MemoryStore();
    final controller = _controller(store, _successClient());

    final result = await controller.activate('valid-invite');

    expect(result?.deviceSession, 'opaque-session');
    expect(store.deviceSession, 'opaque-session');
    expect(controller.state.status, BetaAccessStatus.authorized);
    expect(store.activationId, '00000000-0000-4000-8000-000000000001');

    final restarted = _controller(store, _successClient());
    await restarted.restore();
    expect(restarted.deviceSession, 'opaque-session');
    expect(restarted.state.status, BetaAccessStatus.authorized);
  });

  test('invalid invitation stores no session and reports Burmese-first error', () async {
    final store = _MemoryStore();
    final client = BetaAccessApiClient(
      baseUrl: 'https://gateway.example.test',
      betaAccessToken: 'beta-token',
      httpClient: MockClient(
        (_) async => http.Response('{"error":{"code":"invalid_beta_invite"}}', 401),
      ),
    );
    final controller = _controller(store, client);

    final result = await controller.activate('invalid-invite');

    expect(result, isNull);
    expect(store.deviceSession, isNull);
    expect(controller.state.status, BetaAccessStatus.needsInvitation);
    expect(controller.state.message, contains('invite code'));
  });

  test('invalidating a session preserves unrelated activation identity', () async {
    final store = _MemoryStore(
      activationId: '00000000-0000-4000-8000-000000000001',
      deviceSession: 'opaque-session',
    );
    final controller = _controller(store, _successClient());
    await controller.restore();

    await controller.invalidateSession();

    expect(store.deviceSession, isNull);
    expect(store.activationId, '00000000-0000-4000-8000-000000000001');
    expect(controller.state.status, BetaAccessStatus.needsInvitation);
  });
}

BetaAccessController _controller(
  _MemoryStore store,
  BetaAccessApiClient client,
) {
  return BetaAccessController(
    store: store,
    apiClient: client,
    productionGateEnabled: true,
    activationIdFactory: () => '00000000-0000-4000-8000-000000000001',
  );
}

BetaAccessApiClient _successClient() {
  return BetaAccessApiClient(
    baseUrl: 'https://gateway.example.test',
    betaAccessToken: 'beta-token',
    httpClient: MockClient(
      (_) async => http.Response(
        jsonEncode(<String, String>{'deviceSession': 'opaque-session'}),
        201,
      ),
    ),
  );
}

class _MemoryStore implements BetaAccessSecureStore {
  _MemoryStore({this.deviceSession, this.activationId});

  String? deviceSession;
  String? activationId;

  @override
  Future<void> clearDeviceSession() async => deviceSession = null;

  @override
  Future<String?> readActivationId() async => activationId;

  @override
  Future<String?> readDeviceSession() async => deviceSession;

  @override
  Future<void> writeActivationId(String value) async => activationId = value;

  @override
  Future<void> writeDeviceSession(String value) async => deviceSession = value;
}
