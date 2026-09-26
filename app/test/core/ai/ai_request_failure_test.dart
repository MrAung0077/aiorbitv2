import 'package:aiorbit/core/ai/ai_request_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release diagnostic line exposes only validated safe metadata', () {
    const failure = AIRequestFailure(
      category: AIRequestFailureCategory.authentication,
      retryable: false,
      executionStage: 'chat request prompt=private-value',
      diagnosticReason: 'body={private-response}',
      correlationId: 'Bearer secret-token',
      statusCode: 403,
      elapsed: Duration(milliseconds: -1),
    );

    final line = failure.releaseDiagnosticLine;

    expect(
      line,
      'OVEXIQ_AI_FAILURE '
      'category=authentication retryable=false status=403 '
      'stage=unknown correlation=none elapsedMs=0 reason=redacted',
    );
    expect(line, isNot(contains('private')));
    expect(line, isNot(contains('Bearer')));
    expect(line, isNot(contains('body')));
  });
}
