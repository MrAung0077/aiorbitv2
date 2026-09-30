import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;

import '../ai_request_failure.dart';
import '../ai_request.dart';

class OvexiqBackendApiClient {
  OvexiqBackendApiClient({
    required String baseUrl,
    required String betaAccessToken,
    String? deviceSession,
    Future<void> Function()? onAuthorizationRejected,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 180),
  }) : _baseUri = Uri.tryParse(baseUrl.trim()),
       _betaAccessToken = betaAccessToken.trim(),
       _deviceSession = deviceSession?.trim(),
       _onAuthorizationRejected = onAuthorizationRejected,
       _httpClient = httpClient ?? http.Client();

  final Uri? _baseUri;
  final String _betaAccessToken;
  final String? _deviceSession;
  final Future<void> Function()? _onAuthorizationRejected;
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
    final stopwatch = Stopwatch()..start();

    if (!isConfigured) {
      throw _failure(
        category: AIRequestFailureCategory.invalidRequest,
        retryable: false,
        executionStage: 'request_validation',
        diagnosticReason: 'client_not_configured',
        elapsed: stopwatch.elapsed,
      );
    }

    if (request.messages.isEmpty ||
        request.messages.every((message) => message.content.trim().isEmpty)) {
      throw _failure(
        category: AIRequestFailureCategory.invalidRequest,
        retryable: false,
        executionStage: 'request_validation',
        diagnosticReason: 'empty_messages',
        elapsed: stopwatch.elapsed,
      );
    }

    final body = <String, Object?>{
      'messages': request.messages
          .map((message) => message.toJson())
          .toList(growable: false),
      'response_language': request.responseLanguage.wireValue,
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
              if (_deviceSession?.isNotEmpty == true)
                'X-Ovexiq-Device-Session': _deviceSession!,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw _failure(
        category: AIRequestFailureCategory.requestTimeout,
        retryable: true,
        executionStage: 'gateway_request',
        diagnosticReason: 'request_timeout',
        elapsed: stopwatch.elapsed,
      );
    } on SocketException catch (error) {
      final category = _socketFailureCategory(error);
      throw _failure(
        category: category,
        retryable: _isRetryableTransportCategory(category),
        executionStage: 'gateway_request',
        diagnosticReason: _transportDiagnosticReason(category),
        elapsed: stopwatch.elapsed,
      );
    } on HandshakeException {
      throw _failure(
        category: AIRequestFailureCategory.networkTransport,
        retryable: true,
        executionStage: 'gateway_request',
        diagnosticReason: 'tls_handshake_failure',
        elapsed: stopwatch.elapsed,
      );
    } on http.ClientException catch (error) {
      final category = _transportMessageCategory(error.message);
      throw _failure(
        category: category,
        retryable: _isRetryableTransportCategory(category),
        executionStage: 'gateway_request',
        diagnosticReason: _transportDiagnosticReason(category),
        elapsed: stopwatch.elapsed,
      );
    } on FormatException {
      throw _failure(
        category: AIRequestFailureCategory.invalidRequest,
        retryable: false,
        executionStage: 'request_encoding',
        diagnosticReason: 'request_encoding_invalid',
        elapsed: stopwatch.elapsed,
      );
    } catch (_) {
      throw _failure(
        category: AIRequestFailureCategory.unknown,
        retryable: true,
        executionStage: 'gateway_request',
        diagnosticReason: 'unclassified_transport_failure',
        elapsed: stopwatch.elapsed,
      );
    }

    final decodedBody = _tryDecodeObject(response.body);
    final correlationId = _responseCorrelationId(response, decodedBody);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _onAuthorizationRejected?.call();
      }
      throw _failure(
        category: _httpFailureCategory(response.statusCode, decodedBody),
        retryable: _isRetryableStatusCode(response.statusCode),
        executionStage: 'gateway_response',
        diagnosticReason: _httpDiagnosticReason(
          response.statusCode,
          decodedBody,
        ),
        statusCode: response.statusCode,
        correlationId: correlationId,
        elapsed: stopwatch.elapsed,
        retryAfter: _retryAfter(response),
      );
    }

    if (decodedBody == null) {
      throw _failure(
        category: AIRequestFailureCategory.invalidResponse,
        retryable: true,
        executionStage: 'response_decoding',
        diagnosticReason: 'response_not_json_object',
        correlationId: correlationId,
        elapsed: stopwatch.elapsed,
      );
    }

    final content = decodedBody['content'];

    if (content is! String || content.trim().isEmpty) {
      throw _failure(
        category: AIRequestFailureCategory.invalidResponse,
        retryable: true,
        executionStage: 'response_validation',
        diagnosticReason: 'response_content_empty',
        correlationId: correlationId,
        elapsed: stopwatch.elapsed,
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

  AIRequestFailure _failure({
    required AIRequestFailureCategory category,
    required bool retryable,
    required String executionStage,
    required String diagnosticReason,
    int? statusCode,
    String? correlationId,
    Duration? elapsed,
    Duration? retryAfter,
  }) {
    final failure = AIRequestFailure(
      category: category,
      retryable: retryable,
      executionStage: executionStage,
      diagnosticReason: diagnosticReason,
      statusCode: statusCode,
      correlationId: correlationId,
      elapsed: elapsed,
      retryAfter: retryAfter,
    );
    developer.log(
      'Ovexiq AI request failure ${failure.diagnosticSummary}',
      name: 'ovexiq.ai.request',
    );
    return failure;
  }

  Duration? _retryAfter(http.Response response) {
    if (response.statusCode != 429) {
      return null;
    }

    // The gateway uses the standard delay-seconds form. Ignore malformed,
    // zero, and impractically large values rather than trusting them for UI
    // control flow.
    final retryAfter = response.headers.entries
        .where((entry) => entry.key.toLowerCase() == 'retry-after')
        .map((entry) => entry.value.trim())
        .firstOrNull;
    final seconds = int.tryParse(retryAfter ?? '');
    if (seconds == null || seconds <= 0 || seconds > 24 * 60 * 60) {
      return null;
    }
    return Duration(seconds: seconds);
  }

  AIRequestFailureCategory _socketFailureCategory(SocketException error) {
    final message = <String>[
      error.message,
      if (error.osError != null) error.osError!.message,
    ].join(' ').toLowerCase();
    return _transportMessageCategory(message);
  }

  AIRequestFailureCategory _transportMessageCategory(String message) {
    final normalized = message.toLowerCase();
    if (_containsAny(normalized, const <String>['cancelled', 'canceled'])) {
      return AIRequestFailureCategory.cancelled;
    }
    if (_containsAny(normalized, const <String>[
      'failed host lookup',
      'getaddrinfo',
      'name or service not known',
      'no address associated',
    ])) {
      return AIRequestFailureCategory.dnsFailure;
    }
    if (_containsAny(normalized, const <String>[
      'network is unreachable',
      'network unreachable',
      'no route to host',
      'not connected',
    ])) {
      return AIRequestFailureCategory.networkOffline;
    }
    if (_containsAny(normalized, const <String>[
      'connection timed out',
      'connect timeout',
    ])) {
      return AIRequestFailureCategory.connectionTimeout;
    }
    return AIRequestFailureCategory.networkTransport;
  }

  bool _isRetryableTransportCategory(AIRequestFailureCategory category) =>
      category != AIRequestFailureCategory.cancelled;

  bool _containsAny(String value, List<String> candidates) =>
      candidates.any(value.contains);

  String _transportDiagnosticReason(AIRequestFailureCategory category) {
    switch (category) {
      case AIRequestFailureCategory.networkOffline:
        return 'network_unreachable';
      case AIRequestFailureCategory.dnsFailure:
        return 'dns_lookup_failed';
      case AIRequestFailureCategory.connectionTimeout:
        return 'connection_timeout';
      case AIRequestFailureCategory.networkTransport:
        return 'network_transport_failure';
      case AIRequestFailureCategory.cancelled:
        return 'request_cancelled';
      default:
        return 'transport_failure';
    }
  }

  AIRequestFailureCategory _httpFailureCategory(
    int statusCode,
    Map<String, dynamic>? body,
  ) {
    if (statusCode == 401 || statusCode == 403) {
      return AIRequestFailureCategory.authentication;
    }
    if (statusCode == 408) {
      return AIRequestFailureCategory.requestTimeout;
    }
    if (statusCode == 429) {
      return AIRequestFailureCategory.rateLimited;
    }
    if (statusCode == 400 ||
        statusCode == 404 ||
        statusCode == 413 ||
        statusCode == 415 ||
        statusCode == 422) {
      return AIRequestFailureCategory.invalidRequest;
    }
    if (statusCode >= 500 && _isUpstreamFailure(body)) {
      return AIRequestFailureCategory.providerUnavailable;
    }
    return AIRequestFailureCategory.serverError;
  }

  bool _isRetryableStatusCode(int statusCode) =>
      statusCode == 408 || statusCode == 429 || statusCode >= 500;

  bool _isUpstreamFailure(Map<String, dynamic>? body) {
    final code = _safeErrorCode(body);
    return code == 'provider_unavailable' ||
        code == 'upstream_unavailable' ||
        code == 'provider_timeout' ||
        code == 'upstream_timeout';
  }

  String _httpDiagnosticReason(int statusCode, Map<String, dynamic>? body) {
    if (_isUpstreamFailure(body)) {
      return 'upstream_unavailable';
    }
    return 'http_$statusCode';
  }

  String? _safeErrorCode(Map<String, dynamic>? body) {
    final error = body?['error'];
    if (error is! Map) {
      return null;
    }
    final code = error['code'];
    if (code is! String) {
      return null;
    }
    final normalized = code.toLowerCase();
    return RegExp(r'^[a-z0-9_-]{1,64}$').hasMatch(normalized)
        ? normalized
        : null;
  }

  String? _responseCorrelationId(
    http.Response response,
    Map<String, dynamic>? body,
  ) {
    final candidate =
        body?['requestId'] ??
        response.headers['x-request-id'] ??
        response.headers['cf-ray'];
    if (candidate is! String) {
      return null;
    }
    final normalized = candidate.trim();
    return RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(normalized)
        ? normalized
        : null;
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
