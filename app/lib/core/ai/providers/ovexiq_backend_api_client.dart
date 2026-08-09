import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../ai_request.dart';

class OvexiqBackendApiClient {
  OvexiqBackendApiClient({
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

  Future<OvexiqBackendApiResult> complete(AIRequest request) async {
    if (!isConfigured) {
      throw const OvexiqBackendApiException(
        message: 'Ovexiq AI is not configured.',
      );
    }

    if (request.messages.isEmpty ||
        request.messages.every((message) => message.content.trim().isEmpty)) {
      throw const OvexiqBackendApiException(
        message: 'The Ovexiq AI request cannot be empty.',
      );
    }

    final body = <String, Object?>{
      'messages': request.messages
          .map((message) => message.toJson())
          .toList(growable: false),
      'temperature': request.temperature,
      if (request.maxTokens != null) 'maxTokens': request.maxTokens,
      if (request.metadata.isNotEmpty) 'metadata': request.metadata,
    };

    final http.Response response;

    try {
      response = await _httpClient
          .post(
            _baseUri!.resolve('/v1/ai/complete'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'X-Ovexiq-Beta-Token': _betaAccessToken,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const OvexiqBackendApiException(
        message: 'Ovexiq AI timed out. Please try again.',
      );
    } on SocketException {
      throw const OvexiqBackendApiException(
        message: 'Could not connect to Ovexiq AI.',
      );
    } on HandshakeException {
      throw const OvexiqBackendApiException(
        message: 'Could not connect securely to Ovexiq AI.',
      );
    } on http.ClientException {
      throw const OvexiqBackendApiException(
        message: 'Could not connect to Ovexiq AI.',
      );
    } on FormatException {
      throw const OvexiqBackendApiException(
        message: 'The Ovexiq AI request is invalid.',
      );
    } catch (_) {
      throw const OvexiqBackendApiException(
        message: 'Ovexiq AI is temporarily unavailable.',
      );
    }

    final decodedBody = _tryDecodeObject(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OvexiqBackendApiException(
        message: _safeFailureMessage(response.statusCode),
        statusCode: response.statusCode,
      );
    }

    if (decodedBody == null) {
      throw const OvexiqBackendApiException(
        message: 'Ovexiq AI returned an invalid response.',
      );
    }

    final content = decodedBody['content'];

    if (content is! String || content.trim().isEmpty) {
      throw const OvexiqBackendApiException(
        message: 'Ovexiq AI returned an empty response.',
      );
    }

    final usage = decodedBody['usage'];

    return OvexiqBackendApiResult(
      content: content.trim(),
      model: decodedBody['model'] as String?,
      requestId: decodedBody['requestId'] as String?,
      promptTokens: usage is Map<String, dynamic>
          ? usage['promptTokens'] as int?
          : null,
      completionTokens: usage is Map<String, dynamic>
          ? usage['completionTokens'] as int?
          : null,
    );
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

  String _safeFailureMessage(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return 'This Ovexiq beta access is not authorized.';
    }

    if (statusCode == 429) {
      return 'Too many Ovexiq requests. Please wait and try again.';
    }

    if (statusCode == 400 || statusCode == 413 || statusCode == 415) {
      return 'The Ovexiq AI request was rejected.';
    }

    return 'Ovexiq AI is temporarily unavailable.';
  }

  void close() {
    _httpClient.close();
  }
}

class OvexiqBackendApiResult {
  const OvexiqBackendApiResult({
    required this.content,
    this.model,
    this.requestId,
    this.promptTokens,
    this.completionTokens,
  });

  final String content;
  final String? model;
  final String? requestId;
  final int? promptTokens;
  final int? completionTokens;
}

class OvexiqBackendApiException implements Exception {
  const OvexiqBackendApiException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
