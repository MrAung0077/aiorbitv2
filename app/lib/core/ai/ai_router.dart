import 'ai_provider.dart';
import 'ai_request.dart';
import 'ai_routing_result.dart';
import 'provider_type.dart';

class AIRouter {
  AIRouter({
    required List<AIProvider> providers,
    this.defaultProvider = ProviderType.gemini,
  }) : _providers = List<AIProvider>.unmodifiable(providers);

  final List<AIProvider> _providers;
  final ProviderType defaultProvider;

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
          reason: 'User or feature selected ${preferredProvider.displayName}.',
        );
      }
    }

    final ProviderType inferredType = _inferProvider(request.latestUserPrompt);
    final AIProvider? inferredProvider = _findAvailableProvider(
      inferredType,
      request,
    );

    if (inferredProvider != null) {
      return AIRoutingResult(
        provider: inferredProvider,
        reason:
            'Router selected ${inferredProvider.displayName} for this task.',
      );
    }

    final AIProvider? defaultMatch = _findAvailableProvider(
      defaultProvider,
      request,
    );

    if (defaultMatch != null) {
      return AIRoutingResult(
        provider: defaultMatch,
        reason: 'Router used the default provider.',
      );
    }

    for (final AIProvider provider in _providers) {
      if (provider.isConfigured && provider.supports(request)) {
        return AIRoutingResult(
          provider: provider,
          reason: 'Router used the first available compatible provider.',
        );
      }
    }

    throw StateError('No configured AI provider supports this request.');
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

  ProviderType _inferProvider(String prompt) {
    final String normalized = prompt.toLowerCase();

    if (_containsAny(normalized, const <String>[
      'code',
      'debug',
      'flutter',
      'dart',
      'python',
      'javascript',
      'typescript',
      'api',
      'architecture',
    ])) {
      return ProviderType.claude;
    }

    if (_containsAny(normalized, const <String>[
      'latest',
      'news',
      'current',
      'today',
      'research',
      'compare',
    ])) {
      return ProviderType.gemini;
    }

    if (_containsAny(normalized, const <String>[
      'local model',
      'offline',
      'private',
      'on device',
    ])) {
      return ProviderType.ollama;
    }

    if (_containsAny(normalized, const <String>[
      'cheap',
      'budget',
      'low cost',
      'economical',
    ])) {
      return ProviderType.deepSeek;
    }

    return defaultProvider;
  }

  bool _containsAny(String value, List<String> terms) {
    return terms.any(value.contains);
  }
}
