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
    final fields = <String>[
      'category=${category.name}',
      'retryable=$retryable',
      'stage=$executionStage',
      'reason=$diagnosticReason',
      if (statusCode != null) 'httpStatus=$statusCode',
      if (correlationId != null) 'correlationId=$correlationId',
      if (elapsed != null) 'elapsedMs=${elapsed!.inMilliseconds}',
    ];
    return fields.join(' ');
  }

  @override
  String toString() => userMessage;
}
