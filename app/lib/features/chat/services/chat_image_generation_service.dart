import '../../../core/ai/providers/ovexiq_image_api_client.dart';

abstract class ChatImageGenerator {
  Future<GeneratedImage> generate({required String prompt});
}

/// Keeps Chat's image action handling separate from text completion.
class ChatImageGenerationService implements ChatImageGenerator {
  ChatImageGenerationService({required OvexiqImageApiClient imageApiClient})
    : _imageApiClient = imageApiClient;

  final OvexiqImageApiClient _imageApiClient;

  @override
  Future<GeneratedImage> generate({required String prompt}) {
    return _imageApiClient.generate(prompt: prompt);
  }
}
