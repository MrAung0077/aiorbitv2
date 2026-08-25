import 'dart:async';

import '../../../core/ai/providers/ovexiq_image_api_client.dart';

abstract class ChatImageGenerator {
  Future<GeneratedImage> generate({required String prompt});

  /// Default wrapper keeps existing fakes and alternate implementations
  /// cancellable at the Chat boundary, even when they cannot abort transport.
  ChatImageGenerationOperation startGeneration({required String prompt}) {
    return ChatImageGenerationOperation.fromFuture(generate(prompt: prompt));
  }
}

class ChatImageGenerationOperation {
  ChatImageGenerationOperation._({
    required Future<GeneratedImage> result,
    required void Function() onCancel,
  }) : _result = result,
       _onCancel = onCancel;

  factory ChatImageGenerationOperation.fromFuture(
    Future<GeneratedImage> future, {
    void Function()? onCancel,
  }) {
    final cancellation = Completer<void>();
    return ChatImageGenerationOperation._(
      result: Future.any<GeneratedImage>(<Future<GeneratedImage>>[
        future,
        cancellation.future.then<GeneratedImage>((_) {
          throw const OvexiqImageGenerationCancelled();
        }),
      ]),
      onCancel: () {
        onCancel?.call();
        if (!cancellation.isCompleted) {
          cancellation.complete();
        }
      },
    );
  }

  final Future<GeneratedImage> _result;
  final void Function() _onCancel;
  var _isCancelled = false;

  Future<GeneratedImage> get result => _result;
  bool get isCancelled => _isCancelled;

  void cancel() {
    if (_isCancelled) {
      return;
    }

    _isCancelled = true;
    _onCancel();
  }
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

  @override
  ChatImageGenerationOperation startGeneration({required String prompt}) {
    final generation = _imageApiClient.startGeneration(prompt: prompt);
    return ChatImageGenerationOperation._(
      result: generation.result,
      onCancel: generation.cancel,
    );
  }
}
