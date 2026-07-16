import 'ai_provider.dart';

class AIRoutingResult {
  const AIRoutingResult({required this.provider, required this.reason});

  final AIProvider provider;
  final String reason;
}
