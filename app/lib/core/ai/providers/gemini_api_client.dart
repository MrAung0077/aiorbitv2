import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

import '../ai_message.dart';
import '../gemini_config.dart';

class GeminiAPIClient {
  GeminiAPIClient({
    required String apiKey,
    required this.defaultModel,
    http.Client? httpClient,
  }) : _apiKey = apiKey.trim(),
       _httpClient = httpClient ?? http.Client();

  factory GeminiAPIClient.fromConfig() {
    return GeminiAPIClient(
      apiKey: GeminiConfig.apiKey,
      defaultModel: GeminiConfig.model,
    );
  }

  final String _apiKey;
  final String defaultModel;
  final http.Client _httpClient;

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<GeminiAPIResult> createResponse({
    required List<AIMessage> messages,
    String? model,
    int? maxOutputTokens,
  }) async {
    if (!isConfigured) {
      throw const GeminiAPIException(
        message: 'The Gemini API key is not configured.',
      );
    }

    if (messages.isEmpty ||
        messages.every((message) => message.content.trim().isEmpty)) {
      throw const GeminiAPIException(
        message: 'The Gemini input cannot be empty.',
      );
    }

    final selectedModel = model?.trim().isNotEmpty == true
        ? model!.trim()
        : defaultModel;

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/'
      'models/$selectedModel:generateContent?key=$_apiKey',
    );

    final systemMessages = messages
        .where((message) => message.role == AIMessageRole.system)
        .map((message) => message.content)
        .where((content) => content.trim().isNotEmpty)
        .toList(growable: false);

    final body = <String, Object?>{
      'contents': messages
          .where((message) => message.role != AIMessageRole.system)
          .map(
            (message) => <String, Object?>{
              'role': message.role == AIMessageRole.assistant
                  ? 'model'
                  : 'user',
              'parts': <Object?>[
                <String, Object?>{'text': message.content},
              ],
            },
          )
          .toList(growable: false),
      if (systemMessages.isNotEmpty)
        'systemInstruction': <String, Object?>{
          'parts': <Object?>[
            <String, Object?>{'text': systemMessages.join('\n\n')},
          ],
        },
      if (maxOutputTokens != null)
        'generationConfig': <String, Object?>{
          'maxOutputTokens': maxOutputTokens,
        },
    };

    const maxAttempts = 3;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final http.Response response;

      try {
        response = await _httpClient
            .post(
              uri,
              headers: <String, String>{'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 60));
      } on TimeoutException catch (error) {
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
          continue;
        }

        throw GeminiAPIException(
          message: 'Gemini request timed out.',
          cause: error,
          type: GeminiErrorType.network,
        );
      } catch (error) {
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
          continue;
        }

        throw GeminiAPIException(
          message: 'Could not connect to Gemini.',
          cause: error,
          type: GeminiErrorType.network,
        );
      }

      final Object? decodedBody = _tryDecodeJson(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        log(
          'Gemini request failed with status ${response.statusCode}.',
          name: 'Ovexiq.GeminiAPIClient',
          error: response.body,
        );

        final message =
            _extractErrorMessage(decodedBody) ??
            'Gemini request failed with status ${response.statusCode}.';

        if (_shouldRetry(response.statusCode, message) &&
            attempt < maxAttempts) {
          await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
          continue;
        }

        throw GeminiAPIException(
          message: message,
          statusCode: response.statusCode,
          type: _detectErrorType(response.statusCode, message),
        );
      }

      if (decodedBody is! Map<String, dynamic>) {
        throw const GeminiAPIException(
          message: 'Gemini returned an invalid response.',
        );
      }

      final text = _extractOutputText(decodedBody);

      if (text.isEmpty) {
        throw const GeminiAPIException(
          message: 'Gemini returned an empty response.',
        );
      }

      final usage = decodedBody['usageMetadata'];

      return GeminiAPIResult(
        model: selectedModel,
        text: text,
        inputTokens: usage is Map<String, dynamic>
            ? usage['promptTokenCount'] as int?
            : null,
        outputTokens: usage is Map<String, dynamic>
            ? usage['candidatesTokenCount'] as int?
            : null,
      );
    }

    throw const GeminiAPIException(
      message: 'Gemini request failed after multiple attempts.',
    );
  }

  GeminiErrorType _detectErrorType(int statusCode, String message) {
    final lower = message.toLowerCase();

    if (lower.contains('location') ||
        lower.contains('region') ||
        lower.contains('country')) {
      return GeminiErrorType.regionUnavailable;
    }

    if (statusCode == 429 || lower.contains('resource exhausted')) {
      return GeminiErrorType.rateLimited;
    }

    if (lower.contains('model') && lower.contains('available')) {
      return GeminiErrorType.invalidModel;
    }

    return GeminiErrorType.unknown;
  }

  Object? _tryDecodeJson(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  String _extractOutputText(Map<String, dynamic> json) {
    final candidates = json['candidates'];

    if (candidates is! List || candidates.isEmpty) {
      return '';
    }

    final firstCandidate = candidates.first;

    if (firstCandidate is! Map<String, dynamic>) {
      return '';
    }

    final content = firstCandidate['content'];

    if (content is! Map<String, dynamic>) {
      return '';
    }

    final parts = content['parts'];

    if (parts is! List) {
      return '';
    }

    final buffer = StringBuffer();

    for (final part in parts) {
      if (part is Map<String, dynamic>) {
        final text = part['text'];

        if (text is String) {
          buffer.write(text);
        }
      }
    }

    return buffer.toString().trim();
  }

  String? _extractErrorMessage(Object? decodedBody) {
    if (decodedBody is! Map<String, dynamic>) {
      return null;
    }

    final error = decodedBody['error'];

    if (error is Map<String, dynamic>) {
      return error['message'] as String?;
    }

    return null;
  }

  bool _shouldRetry(int statusCode, String message) {
    if (statusCode == 429) {
      return true;
    }

    final lower = message.toLowerCase();

    return lower.contains('high demand') ||
        lower.contains('temporarily unavailable') ||
        lower.contains('resource exhausted');
  }

  void close() {
    _httpClient.close();
  }
}

class GeminiAPIResult {
  const GeminiAPIResult({
    required this.model,
    required this.text,
    this.inputTokens,
    this.outputTokens,
  });

  final String model;
  final String text;
  final int? inputTokens;
  final int? outputTokens;
}

enum GeminiErrorType {
  unknown,
  regionUnavailable,
  rateLimited,
  invalidModel,
  network,
}

class GeminiAPIException implements Exception {
  const GeminiAPIException({
    required this.message,
    this.statusCode,
    this.cause,
    this.type = GeminiErrorType.unknown,
  });

  final String message;
  final int? statusCode;
  final Object? cause;
  final GeminiErrorType type;

  @override
  String toString() => message;
}
