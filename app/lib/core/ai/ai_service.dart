import 'dart:developer';

import 'ai_chunk.dart';
import 'ai_provider.dart';
import 'ai_request.dart';
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

        log(
          'AIOrbit complete: ${provider.displayName} failed.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    throw StateError(
      'All available AI providers failed. Last error: $lastError',
    );
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
            lastError = chunk.error ?? 'Unknown provider error.';

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

        if (lastError == null || hasEmittedText) {
          return;
        }
      } catch (error, stackTrace) {
        lastError = error;

        log(
          'AIOrbit stream: ${provider.displayName} failed.',
          error: error,
          stackTrace: stackTrace,
        );

        yield AIChunk.status(
          provider: provider.type,
          text: _providerFailureMessage(provider.displayName, error),
        );

        if (hasEmittedText) {
          yield AIChunk.error(provider: provider.type, error: error.toString());
          return;
        }
      }
    }

    final AIProvider lastProvider = candidates.last;

    yield AIChunk.error(
      provider: lastProvider.type,
      error: 'All available AI providers failed. Last error: $lastError',
    );
  }

  String _providerFailureMessage(String providerName, Object error) {
    if (error is GeminiAPIException) {
      switch (error.type) {
        case GeminiErrorType.regionUnavailable:
          return '$providerName is unavailable in your region. AIOrbit is switching...';

        case GeminiErrorType.rateLimited:
          return '$providerName is temporarily busy. AIOrbit is switching...';

        case GeminiErrorType.invalidModel:
          return '$providerName model is unavailable. AIOrbit is switching...';

        case GeminiErrorType.network:
          return 'Cannot connect to $providerName. AIOrbit is switching...';

        case GeminiErrorType.unknown:
          return '$providerName is temporarily unavailable. AIOrbit is switching...';
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
