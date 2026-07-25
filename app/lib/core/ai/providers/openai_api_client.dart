import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class OpenAIAPIClient {
  OpenAIAPIClient({
    required String apiKey,
    required this.defaultModel,
    http.Client? httpClient,
    Uri? responsesUri,
  }) : _apiKey = apiKey.trim(),
       _httpClient = httpClient ?? http.Client(),
       _responsesUri =
           responsesUri ?? Uri.parse('https://api.openai.com/v1/responses');

  final String _apiKey;
  final String defaultModel;
  final http.Client _httpClient;
  final Uri _responsesUri;

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<OpenAIAPIResult> createResponse({
    required String input,
    String? model,
    int? maxOutputTokens,
  }) async {
    final normalizedInput = input.trim();

    if (!isConfigured) {
      throw const OpenAIAPIException(
        message: 'The OpenAI API key is not configured.',
      );
    }

    if (normalizedInput.isEmpty) {
      throw const OpenAIAPIException(
        message: 'The OpenAI input cannot be empty.',
      );
    }

    final body = <String, Object?>{
      'model': model?.trim().isNotEmpty == true ? model!.trim() : defaultModel,
      'input': normalizedInput,
      'max_output_tokens': ?maxOutputTokens,
    };

    final http.Response response;

    try {
      response = await _httpClient
          .post(
            _responsesUri,
            headers: <String, String>{
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException catch (error) {
      throw OpenAIAPIException(
        message: 'OpenAI request timed out after 60 seconds.',
        cause: error,
      );
    } on SocketException catch (error) {
      throw OpenAIAPIException(
        message: 'Could not reach OpenAI. Network error: ${error.message}',
        cause: error,
      );
    } on HandshakeException catch (error) {
      throw OpenAIAPIException(
        message:
            'Could not establish a secure connection to OpenAI: ${error.message}',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw OpenAIAPIException(
        message: 'OpenAI HTTP connection failed: ${error.message}',
        cause: error,
      );
    } catch (error) {
      throw OpenAIAPIException(
        message:
            'Unexpected OpenAI connection error: ${error.runtimeType}: $error',
        cause: error,
      );
    }

    final Object? decodedBody = _tryDecodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenAIAPIException(
        message:
            _extractErrorMessage(decodedBody) ??
            'OpenAI request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    if (decodedBody is! Map<String, dynamic>) {
      throw const OpenAIAPIException(
        message: 'OpenAI returned an invalid response.',
      );
    }

    final text = _extractOutputText(decodedBody);

    if (text.isEmpty) {
      throw const OpenAIAPIException(
        message: 'OpenAI returned an empty response.',
      );
    }

    final usage = decodedBody['usage'];

    return OpenAIAPIResult(
      id: decodedBody['id'] as String?,
      model: decodedBody['model'] as String? ?? defaultModel,
      text: text,
      inputTokens: usage is Map<String, dynamic>
          ? usage['input_tokens'] as int?
          : null,
      outputTokens: usage is Map<String, dynamic>
          ? usage['output_tokens'] as int?
          : null,
    );
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
    final output = json['output'];

    if (output is! List) {
      return '';
    }

    final buffer = StringBuffer();

    for (final item in output) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final content = item['content'];

      if (content is! List) {
        continue;
      }

      for (final contentItem in content) {
        if (contentItem is! Map<String, dynamic>) {
          continue;
        }

        if (contentItem['type'] == 'output_text') {
          final text = contentItem['text'];

          if (text is String) {
            buffer.write(text);
          }
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

  void close() {
    _httpClient.close();
  }
}

class OpenAIAPIResult {
  const OpenAIAPIResult({
    required this.model,
    required this.text,
    this.id,
    this.inputTokens,
    this.outputTokens,
  });

  final String? id;
  final String model;
  final String text;
  final int? inputTokens;
  final int? outputTokens;
}

class OpenAIAPIException implements Exception {
  const OpenAIAPIException({
    required this.message,
    this.statusCode,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => message;
}
