import 'dart:async';

import 'ai_chunk.dart';
import 'ai_provider.dart';
import 'ai_request.dart';
import 'ai_response.dart';
import 'provider_type.dart';

class MockAIProvider implements AIProvider {
  const MockAIProvider({
    required this.type,
    required this.displayName,
    this.configured = true,
    this.wordDelay = const Duration(milliseconds: 35),
  });

  @override
  final ProviderType type;

  @override
  final String displayName;

  final bool configured;
  final Duration wordDelay;

  @override
  bool get isConfigured => configured;

  @override
  bool supports(AIRequest request) {
    return request.messages.isNotEmpty;
  }

  @override
  Future<AIResponse> complete(AIRequest request) async {
    _validate(request);

    final String response = _buildResponse(request);

    return AIResponse(
      provider: type,
      content: response,
      model: request.model ?? 'mock-${type.name}',
      promptTokens: _estimateTokens(request.latestUserPrompt),
      completionTokens: _estimateTokens(response),
      metadata: const <String, Object?>{'mock': true},
    );
  }

  @override
  Stream<AIChunk> stream(AIRequest request) async* {
    _validate(request);

    yield AIChunk.status(
      provider: type,
      text: '$displayName is generating a response.',
    );

    final String response = _buildResponse(request);
    final List<String> words = response.split(' ');

    for (int index = 0; index < words.length; index++) {
      if (wordDelay > Duration.zero) {
        await Future<void>.delayed(wordDelay);
      }

      final String suffix = index == words.length - 1 ? '' : ' ';
      yield AIChunk.text(provider: type, text: '${words[index]}$suffix');
    }

    yield AIChunk.usage(
      provider: type,
      promptTokens: _estimateTokens(request.latestUserPrompt),
      completionTokens: _estimateTokens(response),
    );

    yield AIChunk.done(provider: type);
  }

  void _validate(AIRequest request) {
    if (!isConfigured) {
      throw StateError('$displayName is not configured.');
    }

    if (!supports(request)) {
      throw ArgumentError('The request is not supported.');
    }
  }

  String _buildResponse(AIRequest request) {
    final String prompt = request.latestUserPrompt.trim();

    return '[$displayName mock] AIOrbit routed your request successfully. '
        'Prompt received: ${prompt.isEmpty ? '(empty)' : prompt}';
  }

  int _estimateTokens(String text) {
    if (text.trim().isEmpty) {
      return 0;
    }

    return (text.length / 4).ceil();
  }
}
