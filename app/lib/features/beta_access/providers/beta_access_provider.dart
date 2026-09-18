import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../models/beta_access_state.dart';
import '../services/beta_access_api_client.dart';
import '../services/beta_access_secure_store.dart';

final betaAccessSecureStoreProvider = Provider<BetaAccessSecureStore>((ref) {
  return FlutterBetaAccessSecureStore();
});

final betaAccessApiClientProvider = Provider<BetaAccessApiClient>((ref) {
  final client = BetaAccessApiClient(
    baseUrl: AppConfig.ovexiqApiBaseUrl,
    betaAccessToken: AppConfig.ovexiqBetaAccessToken,
  );
  ref.onDispose(client.close);
  return client;
});

final betaAccessControllerProvider =
    StateNotifierProvider<BetaAccessController, BetaAccessState>((ref) {
      return BetaAccessController(
        store: ref.watch(betaAccessSecureStoreProvider),
        apiClient: ref.watch(betaAccessApiClientProvider),
        productionGateEnabled: AppConfig.isProduction,
      );
    });

class BetaAccessController extends StateNotifier<BetaAccessState> {
  BetaAccessController({
    required BetaAccessSecureStore store,
    required BetaAccessApiClient apiClient,
    required bool productionGateEnabled,
    String Function()? activationIdFactory,
  }) : _store = store,
       _apiClient = apiClient,
       _productionGateEnabled = productionGateEnabled,
       _activationIdFactory = activationIdFactory ?? _newActivationId,
       super(const BetaAccessState());

  final BetaAccessSecureStore _store;
  final BetaAccessApiClient _apiClient;
  final bool _productionGateEnabled;
  final String Function() _activationIdFactory;

  String? _deviceSession;

  String? get deviceSession => _deviceSession;

  Future<void> restore() async {
    if (!_productionGateEnabled) {
      state = const BetaAccessState(status: BetaAccessStatus.authorized);
      return;
    }

    state = const BetaAccessState(status: BetaAccessStatus.checking);
    final restored = await _store.readDeviceSession();
    _deviceSession = restored?.trim();
    state = BetaAccessState(
      status: _deviceSession?.isNotEmpty == true
          ? BetaAccessStatus.authorized
          : BetaAccessStatus.needsInvitation,
    );
  }

  Future<BetaActivationResult?> activate(String inviteCode) async {
    if (state.status == BetaAccessStatus.activating) {
      return null;
    }

    final normalizedInviteCode = inviteCode.trim();
    if (normalizedInviteCode.isEmpty) {
      state = const BetaAccessState(
        status: BetaAccessStatus.needsInvitation,
        message: 'Beta invite code ကို ထည့်သွင်းပေးပါ။',
      );
      return null;
    }

    state = const BetaAccessState(status: BetaAccessStatus.activating);
    try {
      var activationId = (await _store.readActivationId())?.trim();
      if (activationId == null || activationId.isEmpty) {
        activationId = _activationIdFactory();
        await _store.writeActivationId(activationId);
      }

      final result = await _apiClient.activate(
        inviteCode: normalizedInviteCode,
        activationId: activationId,
      );
      await _store.writeDeviceSession(result.deviceSession);
      _deviceSession = result.deviceSession;
      state = const BetaAccessState(status: BetaAccessStatus.authorized);
      return result;
    } on BetaAccessException catch (error) {
      _deviceSession = null;
      state = BetaAccessState(
        status: BetaAccessStatus.needsInvitation,
        message: error.userMessage,
      );
      return null;
    } catch (_) {
      _deviceSession = null;
      state = const BetaAccessState(
        status: BetaAccessStatus.needsInvitation,
        message:
            'Beta အသုံးပြုခွင့်ကို ယခုအချိန်တွင် အတည်ပြု၍ မရသေးပါ။ ခဏအကြာ ထပ်မံကြိုးစားပါ။',
      );
      return null;
    }
  }

  Future<void> invalidateSession() async {
    if (!_productionGateEnabled) {
      return;
    }

    _deviceSession = null;
    await _store.clearDeviceSession();
    state = const BetaAccessState(
      status: BetaAccessStatus.needsInvitation,
      message:
          'ဤစက်၏ Beta အသုံးပြုခွင့်ကို ပြန်လည်အတည်ပြုရန် လိုအပ်ပါသည်။ Invite code ကို ထပ်မံထည့်သွင်းပါ။',
    );
  }

  static String _newActivationId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
