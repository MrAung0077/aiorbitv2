import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Provider-neutral generated image data returned by the Ovexiq gateway.
class GeneratedImage {
  const GeneratedImage({required this.mimeType, required this.bytes});

  final String mimeType;
  final Uint8List bytes;
}

/// A single image request that can be stopped without affecting other work.
class CancellableImageGeneration {
  CancellableImageGeneration._({
    required Future<GeneratedImage> result,
    required void Function() onCancel,
  }) : _result = result,
       _onCancel = onCancel;

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

class OvexiqImageApiClient {
  OvexiqImageApiClient({
    required String baseUrl,
    required String betaAccessToken,
    String? deviceSession,
    Future<void> Function()? onAuthorizationRejected,
    http.Client? httpClient,
    http.Client Function()? httpClientFactory,
    this.timeout = const Duration(seconds: 60),
  }) : assert(httpClient == null || httpClientFactory == null),
       _baseUri = Uri.tryParse(baseUrl.trim()),
       _betaAccessToken = betaAccessToken.trim(),
       _deviceSession = deviceSession?.trim(),
       _onAuthorizationRejected = onAuthorizationRejected,
       _providedHttpClient = httpClient,
       _httpClientFactory = httpClientFactory ?? http.Client.new;

  final Uri? _baseUri;
  final String _betaAccessToken;
  final String? _deviceSession;
  final Future<void> Function()? _onAuthorizationRejected;

  /// An injected client is retained for tests. Production requests create a
  /// dedicated client so cancelling one image cannot close unrelated work.
  final http.Client? _providedHttpClient;
  final http.Client Function() _httpClientFactory;
  final Duration timeout;

  bool get isConfigured {
    final baseUri = _baseUri;

    return baseUri != null &&
        (baseUri.scheme == 'https' || baseUri.scheme == 'http') &&
        baseUri.host.isNotEmpty &&
        _betaAccessToken.isNotEmpty;
  }

  Future<GeneratedImage> generate({required String prompt}) {
    return startGeneration(prompt: prompt).result;
  }

  CancellableImageGeneration startGeneration({required String prompt}) {
    final cancellation = Completer<void>();
    final requestClient = _providedHttpClient ?? _httpClientFactory();
    final ownsRequestClient = _providedHttpClient == null;
    var requestClientClosed = false;

    void closeRequestClient() {
      if (!ownsRequestClient || requestClientClosed) {
        return;
      }

      requestClientClosed = true;
      requestClient.close();
    }

    void cancel() {
      if (!cancellation.isCompleted) {
        cancellation.complete();
      }

      closeRequestClient();
    }

    final result =
        Future.any<GeneratedImage>(<Future<GeneratedImage>>[
          _generateWithClient(prompt: prompt, httpClient: requestClient),
          cancellation.future.then<GeneratedImage>((_) {
            throw const OvexiqImageGenerationCancelled();
          }),
        ]).whenComplete(() {
          closeRequestClient();
        });

    return CancellableImageGeneration._(result: result, onCancel: cancel);
  }

  Future<GeneratedImage> _generateWithClient({
    required String prompt,
    required http.Client httpClient,
  }) async {
    if (!isConfigured) {
      throw const OvexiqImageApiException(
        message: 'Ovexiq image generation is not configured.',
      );
    }

    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) {
      throw const OvexiqImageApiException(
        message: 'Ovexiq could not create that image. Please try again.',
      );
    }

    final http.Response response;

    try {
      response = await httpClient
          .post(
            _baseUri!.resolve('/v1/ai/image'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'X-Ovexiq-Beta-Token': _betaAccessToken,
              if (_deviceSession?.isNotEmpty == true)
                'X-Ovexiq-Device-Session': _deviceSession!,
            },
            body: jsonEncode(<String, String>{'prompt': trimmedPrompt}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const OvexiqImageApiException(
        message: 'Ovexiq couldn’t create that image. Please try again.',
      );
    } on SocketException {
      throw const OvexiqImageApiException(
        message: 'Ovexiq couldn’t create that image. Please try again.',
      );
    } on HandshakeException {
      throw const OvexiqImageApiException(
        message: 'Ovexiq couldn’t create that image. Please try again.',
      );
    } on http.ClientException {
      throw const OvexiqImageApiException(
        message: 'Ovexiq couldn’t create that image. Please try again.',
      );
    } on FormatException {
      throw const OvexiqImageApiException(
        message: 'Ovexiq couldn’t create that image. Please try again.',
      );
    } catch (_) {
      throw const OvexiqImageApiException(
        message: 'Ovexiq couldn’t create that image. Please try again.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _onAuthorizationRejected?.call();
      }
      throw const OvexiqImageApiException(
        message: 'Ovexiq couldn’t create that image. Please try again.',
      );
    }

    final decodedBody = _tryDecodeObject(response.body);
    final image = decodedBody?['image'];

    if (image is! Map<String, dynamic> ||
        image['mimeType'] is! String ||
        image['base64'] is! String) {
      throw const OvexiqImageApiException(
        message: 'Ovexiq couldn’t create that image. Please try again.',
      );
    }

    final mimeType = (image['mimeType'] as String).trim();
    final encodedImage = (image['base64'] as String).trim();

    if (mimeType.isEmpty || encodedImage.isEmpty) {
      throw const OvexiqImageApiException(
        message: 'Ovexiq couldn’t create that image. Please try again.',
      );
    }

    try {
      final bytes = base64Decode(encodedImage);
      if (bytes.isEmpty) {
        throw const FormatException();
      }

      return GeneratedImage(mimeType: mimeType, bytes: bytes);
    } on FormatException {
      throw const OvexiqImageApiException(
        message: 'Ovexiq couldn’t create that image. Please try again.',
      );
    }
  }

  Map<String, dynamic>? _tryDecodeObject(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  void close() {
    _providedHttpClient?.close();
  }
}

class OvexiqImageGenerationCancelled implements Exception {
  const OvexiqImageGenerationCancelled();
}

class OvexiqImageApiException implements Exception {
  const OvexiqImageApiException({required this.message});

  final String message;

  @override
  String toString() => message;
}
