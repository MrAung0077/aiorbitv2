import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/providers/ovexiq_image_api_client.dart';
import '../../../core/config/app_config.dart';
import '../services/chat_image_generation_service.dart';
import '../services/local_generated_image_result_store.dart';

final ovexiqImageApiClientProvider = Provider<OvexiqImageApiClient>((ref) {
  final client = OvexiqImageApiClient(
    baseUrl: AppConfig.ovexiqApiBaseUrl,
    betaAccessToken: AppConfig.ovexiqBetaAccessToken,
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
