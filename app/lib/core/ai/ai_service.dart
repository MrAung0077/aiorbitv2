import 'dart:developer';

import 'ai_chunk.dart';
import 'ai_provider.dart';
import 'ai_request.dart';
import 'ai_request_failure.dart';
import 'ai_response.dart';
import 'ai_router.dart';
import 'ai_routing_result.dart';
import 'providers/gemini_api_client.dart';

class AIService {
  const AIService({required AIRouter router}) : _router = router;

  final AIRouter _router;

  AIRoutingResult selectProvider(AIRequest request) {
    return _router.route(request);
  }

  Future<AIResponse> complete(AIRequest request) async {
    final AIRoutingResult routingResult = selectProvider(request);

    final List<AIProvider> candidates = _buildCandidates(
      routingResult.provider,
      request,
    );

    Object? lastError;

    for (final AIProvider provider in candidates) {
      try {
        log('AIOrbit complete: trying ${provider.displayName}.');

        return await provider.complete(request);
      } catch (error, stackTrace) {
        lastError = error;
        _logFailure('complete', provider, error, stackTrace);
      }
    }

    final failure = _typedFailure(lastError, executionStage: 'ai_complete');
    _emitTerminalFailure(failure);
    throw failure;
  }

  Stream<AIChunk> stream(AIRequest request) async* {
    final AIRoutingResult routingResult = selectProvider(request);

    final List<AIProvider> candidates = _buildCandidates(
      routingResult.provider,
      request,
    );

    log(
      'AIOrbit Router: ${routingResult.provider.displayName} '
      '- ${routingResult.reason}',
    );

    yield AIChunk.status(
      provider: routingResult.provider.type,
      text: routingResult.reason,
    );

    Object? lastError;

    for (var index = 0; index < candidates.length; index++) {
      final AIProvider provider = candidates[index];
      final bool isFallback = index > 0;

      // Each provider attempt starts with a clean error state.
      // A previous provider failure must not make a later successful
      // fallback look like it also failed.
      lastError = null;

      var hasEmittedText = false;

      if (isFallback) {
        yield AIChunk.status(
          provider: provider.type,
          text: 'Switching to ${provider.displayName}...',
        );
      }

      try {
        log('AIOrbit stream: trying ${provider.displayName}.');

        await for (final AIChunk chunk in provider.stream(request)) {
          if (chunk.type == AIChunkType.text && chunk.text.isNotEmpty) {
            hasEmittedText = true;
          }

          if (chunk.type == AIChunkType.error) {
            lastError =
                chunk.failure ??
                _typedFailure(null, executionStage: 'provider_stream');

            yield AIChunk.status(
              provider: provider.type,
              text: _providerFailureMessage(
                provider.displayName,
                Exception(lastError),
              ),
            );

            break;
          }

          yield chunk;
        }

        if (lastError == null) {
          return;
        }

        if (hasEmittedText) {
          final failure = _typedFailure(
            lastError,
            executionStage: 'provider_stream',
          );
          _emitTerminalFailure(failure);
          // Preserve the existing partial-response behavior. The request is
          // still terminally recorded for release diagnostics, but a provider
          // error chunk after visible text does not replace that text with a
          // new user-facing failure state.
          return;
        }
      } catch (error, stackTrace) {
        lastError = error;
        _logFailure('stream', provider, error, stackTrace);

        yield AIChunk.status(
          provider: provider.type,
          text: _providerFailureMessage(provider.displayName, error),
        );

        if (hasEmittedText) {
          final failure = _typedFailure(
            error,
            executionStage: 'provider_stream',
          );
          _emitTerminalFailure(failure);
          yield AIChunk.error(
            provider: provider.type,
            error: failure.userMessage,
            failure: failure,
          );

          return;
        }
      }
    }

    final AIProvider lastProvider = candidates.last;
    final failure = _typedFailure(lastError, executionStage: 'ai_stream');
    _emitTerminalFailure(failure);

    yield AIChunk.error(
      provider: lastProvider.type,
      error: failure.userMessage,
      failure: failure,
    );
  }

  AIRequestFailure _typedFailure(
    Object? error, {
    required String executionStage,
  }) {
    if (error is AIRequestFailure) {
      return error;
    }
    return AIRequestFailure(
      category: AIRequestFailureCategory.unknown,
      retryable: true,
      executionStage: executionStage,
      diagnosticReason: 'unclassified_provider_failure',
    );
  }

  void _logFailure(
    String operation,
    AIProvider provider,
    Object error,
    StackTrace stackTrace,
  ) {
    final failure = _typedFailure(error, executionStage: 'ai_$operation');
    log(
      'AIOrbit $operation failure provider=${provider.type.name} '
      '${failure.diagnosticSummary}',
      name: 'ovexiq.ai',
      stackTrace: stackTrace,
    );
  }

  void _emitTerminalFailure(AIRequestFailure failure) {
    // `dart:developer` events do not reliably appear in Android release
    // logcat. This string is fully sanitized by AIRequestFailure.
    // ignore: avoid_print
    print(failure.releaseDiagnosticLine);
  }

  String _providerFailureMessage(String providerName, Object error) {
    if (error is GeminiAPIException) {
      switch (error.type) {
        case GeminiErrorType.regionUnavailable:
          return '$providerName is unavailable in your region. '
              'AIOrbit is switching...';

        case GeminiErrorType.rateLimited:
          return '$providerName is temporarily busy. AIOrbit is switching...';

        case GeminiErrorType.invalidModel:
          return '$providerName model is unavailable. AIOrbit is switching...';

        case GeminiErrorType.network:
          return 'Cannot connect to $providerName. AIOrbit is switching...';

        case GeminiErrorType.unknown:
          return '$providerName is temporarily unavailable. '
              'AIOrbit is switching...';
      }
    }

    return '$providerName is temporarily unavailable. AIOrbit is switching...';
  }

  List<AIProvider> _buildCandidates(
    AIProvider selectedProvider,
    AIRequest request,
  ) {
    final List<AIProvider> candidates = <AIProvider>[selectedProvider];

    for (final AIProvider provider in _router.providers) {
      if (provider.type == selectedProvider.type) {
        continue;
      }

      if (!provider.isConfigured || !provider.supports(request)) {
        continue;
      }

      candidates.add(provider);
    }

    return candidates;
  }
}
