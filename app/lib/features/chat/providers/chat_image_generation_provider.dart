import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/providers/ovexiq_image_api_client.dart';
import '../../../core/config/app_config.dart';
import '../../beta_access/providers/beta_access_provider.dart';
import '../services/chat_image_generation_service.dart';
import '../services/local_generated_image_result_store.dart';

final ovexiqImageApiClientProvider = Provider<OvexiqImageApiClient>((ref) {
  ref.watch(betaAccessControllerProvider);
  final betaAccess = ref.read(betaAccessControllerProvider.notifier);
  final client = OvexiqImageApiClient(
    baseUrl: AppConfig.ovexiqApiBaseUrl,
    betaAccessToken: AppConfig.ovexiqBetaAccessToken,
    deviceSession: betaAccess.deviceSession,
    onAuthorizationRejected: betaAccess.invalidateSession,
  );
  ref.onDispose(client.close);
  return client;
});

final chatImageGenerationServiceProvider = Provider<ChatImageGenerator>((ref) {
  return ChatImageGenerationService(
    imageApiClient: ref.watch(ovexiqImageApiClientProvider),
  );
});

final generatedImageResultStoreProvider = Provider<GeneratedImageResultStore>((
  ref,
) {
  return LocalGeneratedImageResultStore();
});
