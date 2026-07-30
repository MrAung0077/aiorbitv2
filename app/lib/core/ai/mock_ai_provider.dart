import 'dart:async';

import 'ai_chunk.dart';
import 'ai_provider.dart';
import 'ai_request.dart';
import 'ai_response.dart';
import 'provider_type.dart';
import 'ai_provider_metadata.dart';
import 'ai_capability.dart';

class MockAIProvider implements AIProvider {
  const MockAIProvider({
    required this.type,
    required this.displayName,
    this.metadata = const AIProviderMetadata(
      supportedTasks: <AITaskType>{AITaskType.generalChat},
    ),
    this.configured = true,
    this.wordDelay = const Duration(milliseconds: 35),
  });

  @override
  final ProviderType type;

  @override
  final String displayName;

  @override
  final AIProviderMetadata metadata;

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

    if (prompt.isEmpty) {
      return 'Tell me what you want to accomplish, and I’ll help turn it into a clear result.';
    }

    final String normalizedPrompt = prompt.toLowerCase();

    final bool isMarketingRequest =
        normalizedPrompt.contains('ad') ||
        normalizedPrompt.contains('ads') ||
        normalizedPrompt.contains('advertisement') ||
        normalizedPrompt.contains('campaign') ||
        normalizedPrompt.contains('caption') ||
        normalizedPrompt.contains('hashtag') ||
        normalizedPrompt.contains('facebook') ||
        normalizedPrompt.contains('tiktok') ||
        normalizedPrompt.contains('instagram') ||
        normalizedPrompt.contains('youtube') ||
        normalizedPrompt.contains('marketing');

    final bool isCodingRequest =
        normalizedPrompt.contains('code') ||
        normalizedPrompt.contains('coding') ||
        normalizedPrompt.contains('flutter') ||
        normalizedPrompt.contains('dart') ||
        normalizedPrompt.contains('app') ||
        normalizedPrompt.contains('website') ||
        normalizedPrompt.contains('api') ||
        normalizedPrompt.contains('bug') ||
        normalizedPrompt.contains('error');

    final bool isResearchRequest =
        normalizedPrompt.contains('research') ||
        normalizedPrompt.contains('compare') ||
        normalizedPrompt.contains('competitor') ||
        normalizedPrompt.contains('analysis') ||
        normalizedPrompt.contains('analyze') ||
        normalizedPrompt.contains('report') ||
        normalizedPrompt.contains('summary');

    final bool isImageRequest =
        normalizedPrompt.contains('image') ||
        normalizedPrompt.contains('photo') ||
        normalizedPrompt.contains('picture') ||
        normalizedPrompt.contains('logo') ||
        normalizedPrompt.contains('poster') ||
        normalizedPrompt.contains('thumbnail') ||
        normalizedPrompt.contains('design');

    final bool isVideoRequest =
        normalizedPrompt.contains('video') ||
        normalizedPrompt.contains('reel') ||
        normalizedPrompt.contains('short') ||
        normalizedPrompt.contains('animation') ||
        normalizedPrompt.contains('voiceover') ||
        normalizedPrompt.contains('script');

    if (isMarketingRequest) {
      return '''
I understand your goal: create marketing content for:

"$prompt"

Ovexiq would prepare a complete campaign workflow, including the core message, platform-ready copy, captions, calls to action, and relevant hashtags.

This development preview is using a mock provider. The production workflow will generate the finished marketing result automatically.
''';
    }

    if (isCodingRequest) {
      return '''
I understand your goal: build or improve:

"$prompt"

Ovexiq would break the request into implementation steps, select the right technical workflow, generate the required code, and help verify the result.

This development preview is using a mock provider. The production workflow will provide the complete implementation.
''';
    }

    if (isResearchRequest) {
      return '''
I understand your research goal:

"$prompt"

Ovexiq would gather the relevant information, compare the important findings, organize the evidence, and deliver a clear summary with actionable conclusions.

This development preview is using a mock provider. The production workflow will generate the completed research result.
''';
    }

    if (isImageRequest) {
      return '''
I understand your visual goal:

"$prompt"

Ovexiq would translate your idea into a strong visual direction, prepare the generation instructions, create the image, and refine it for the intended platform or use case.

This development preview is using a mock provider. The production workflow will deliver the finished visual result.
''';
    }

    if (isVideoRequest) {
      return '''
I understand your video goal:

"$prompt"

Ovexiq would prepare the concept, script, scene structure, visuals, voiceover direction, captions, and publishing assets as one connected workflow.

This development preview is using a mock provider. The production workflow will deliver the completed video package.
''';
    }

    return '''
I understand what you want to accomplish:

"$prompt"

Ovexiq would turn this goal into a clear workflow, choose the appropriate capabilities behind the scenes, and deliver the completed result without requiring you to select individual AI tools.

This development preview is currently using a mock provider.
''';
  }

  int _estimateTokens(String text) {
    if (text.trim().isEmpty) {
      return 0;
    }

    return (text.length / 4).ceil();
  }
}
