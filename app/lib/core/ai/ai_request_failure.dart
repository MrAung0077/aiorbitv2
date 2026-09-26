/// A sanitized, typed failure produced while completing an AI request.
///
/// This deliberately contains no request content, authentication material, or
/// raw upstream response. It can be safely used for release diagnostics and
/// retry decisions.
enum AIRequestFailureCategory {
  networkOffline,
  dnsFailure,
  connectionTimeout,
  requestTimeout,
  networkTransport,
  authentication,
  rateLimited,
  invalidRequest,
  providerUnavailable,
  serverError,
  invalidResponse,
  cancelled,
  unknown,
}

class AIRequestFailure implements Exception {
  const AIRequestFailure({
    required this.category,
    required this.retryable,
    required this.executionStage,
    required this.diagnosticReason,
    this.statusCode,
    this.correlationId,
    this.elapsed,
  });

  final AIRequestFailureCategory category;
  final bool retryable;

  /// A stable, non-sensitive point in the local request lifecycle.
  final String executionStage;

  /// A stable, non-sensitive diagnostic code; never a raw exception message.
  final String diagnosticReason;
  final int? statusCode;
  final String? correlationId;
  final Duration? elapsed;

  /// Safe, intentionally broad wording for any caller that has no localized
  /// presentation layer of its own.
  String get userMessage {
    switch (category) {
      case AIRequestFailureCategory.networkOffline:
      case AIRequestFailureCategory.dnsFailure:
      case AIRequestFailureCategory.connectionTimeout:
      case AIRequestFailureCategory.requestTimeout:
      case AIRequestFailureCategory.networkTransport:
        return 'Connection problem. Please try again.';
      case AIRequestFailureCategory.authentication:
        return 'This Ovexiq beta access is not authorized.';
      case AIRequestFailureCategory.rateLimited:
        return 'Too many requests. Please try again shortly.';
      case AIRequestFailureCategory.invalidRequest:
        return 'The Ovexiq request could not be processed.';
      case AIRequestFailureCategory.providerUnavailable:
      case AIRequestFailureCategory.serverError:
      case AIRequestFailureCategory.unknown:
        return 'Ovexiq AI is temporarily unavailable.';
      case AIRequestFailureCategory.invalidResponse:
        return 'Ovexiq AI returned an invalid response.';
      case AIRequestFailureCategory.cancelled:
        return 'The request was cancelled.';
    }
  }

  /// Suitable for developer logs. All components are constrained to safe
  /// metadata rather than user content or upstream response text.
  String get diagnosticSummary {
    return _diagnosticFields().join(' ');
  }

  /// A release-safe line emitted once when an AI request has reached its
  /// terminal failure boundary. `print` is intentionally used by the shared
  /// service so Android logcat can observe this in signed builds.
  String get releaseDiagnosticLine =>
      'OVEXIQ_AI_FAILURE ${_diagnosticFields().join(' ')}';

  List<String> _diagnosticFields() {
    return <String>[
      'category=${category.name}',
      'retryable=$retryable',
      'status=${_safeStatusCode()}',
      'stage=${_safeIdentifier(executionStage, fallback: 'unknown')}',
      'correlation=${_safeIdentifier(correlationId, fallback: 'none')}',
      'elapsedMs=${_safeElapsedMilliseconds()}',
      'reason=${_safeIdentifier(diagnosticReason, fallback: 'redacted')}',
    ];
  }

  String _safeStatusCode() {
    final value = statusCode;
    if (value == null || value < 100 || value > 599) {
      return 'none';
    }
    return value.toString();
  }

  int _safeElapsedMilliseconds() {
    final value = elapsed?.inMilliseconds;
    return value == null || value < 0 ? 0 : value;
  }

  String _safeIdentifier(String? value, {required String fallback}) {
    final normalized = value?.trim() ?? '';
    return RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(normalized)
        ? normalized
        : fallback;
  }

  @override
  String toString() => userMessage;
}
