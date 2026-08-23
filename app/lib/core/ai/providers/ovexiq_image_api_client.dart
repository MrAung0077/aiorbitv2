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

class OvexiqImageApiClient {
  OvexiqImageApiClient({
    required String baseUrl,
    required String betaAccessToken,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 60),
  }) : _baseUri = Uri.tryParse(baseUrl.trim()),
       _betaAccessToken = betaAccessToken.trim(),
       _httpClient = httpClient ?? http.Client();

  final Uri? _baseUri;
  final String _betaAccessToken;
  final http.Client _httpClient;
  final Duration timeout;

  bool get isConfigured {
    final baseUri = _baseUri;

    return baseUri != null &&
        (baseUri.scheme == 'https' || baseUri.scheme == 'http') &&
        baseUri.host.isNotEmpty &&
        _betaAccessToken.isNotEmpty;
  }

  Future<GeneratedImage> generate({required String prompt}) async {
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
      response = await _httpClient
          .post(
            _baseUri!.resolve('/v1/ai/image'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'X-Ovexiq-Beta-Token': _betaAccessToken,
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
    _httpClient.close();
  }
}

class OvexiqImageApiException implements Exception {
  const OvexiqImageApiException({required this.message});

  final String message;

  @override
  String toString() => message;
}
