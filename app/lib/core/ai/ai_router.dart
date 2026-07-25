import 'ai_capability.dart';
import 'ai_provider.dart';
import 'ai_request.dart';
import 'ai_routing_result.dart';
import 'ai_task_analyzer.dart';
import 'ai_task_analysis_result.dart';
import 'provider_type.dart';

class AIRouter {
  AIRouter({
    required List<AIProvider> providers,
    AITaskAnalyzer? analyzer,
    this.defaultProvider = ProviderType.openAI,
  }) : _providers = List<AIProvider>.unmodifiable(providers),
       _analyzer = analyzer ?? const AITaskAnalyzer();

  final List<AIProvider> _providers;
  final ProviderType defaultProvider;
  final AITaskAnalyzer _analyzer;

  List<AIProvider> get providers => _providers;

  AIRoutingResult route(AIRequest request) {
    final ProviderType? preferred = request.preferredProvider;

    if (preferred != null) {
      final AIProvider? preferredProvider = _findAvailableProvider(
        preferred,
        request,
      );

      if (preferredProvider != null) {
        return AIRoutingResult(
          provider: preferredProvider,
          reason: 'User selected ${preferredProvider.displayName}.',
        );
      }
    }

    final AITaskAnalysisResult analysis = _analyzer.analyze(
      request.latestUserPrompt,
    );

    final ProviderType taskProvider = _providerForTask(analysis.task);

    final AIProvider? selected = _findAvailableProvider(taskProvider, request);

    if (selected != null) {
      return AIRoutingResult(
        provider: selected,
        reason: '${analysis.reason} Selected ${selected.displayName}.',
      );
    }

    final AIProvider? fallback = _findAvailableProvider(
      defaultProvider,
      request,
    );

    if (fallback != null) {
      return AIRoutingResult(
        provider: fallback,
        reason: 'Used default provider.',
      );
    }

    throw StateError('No available AI provider.');
  }

  AIProvider? _findAvailableProvider(ProviderType type, AIRequest request) {
    for (final AIProvider provider in _providers) {
      if (provider.type == type &&
          provider.isConfigured &&
          provider.supports(request)) {
        return provider;
      }
    }

    return null;
  }

  ProviderType _providerForTask(AITaskType task) {
    switch (task) {
      case AITaskType.coding:
        return ProviderType.openAI;

      case AITaskType.research:
        return ProviderType.gemini;

      case AITaskType.translation:
        return ProviderType.gemini;

      case AITaskType.summarization:
        return ProviderType.gemini;

      case AITaskType.imageGeneration:
        return ProviderType.openAI;

      case AITaskType.imageAnalysis:
        return ProviderType.openAI;

      case AITaskType.documentAnalysis:
        return ProviderType.openAI;

      case AITaskType.generalChat:
        return defaultProvider;
    }
  }
}
