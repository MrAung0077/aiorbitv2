import 'ai_chunk.dart';
import 'ai_request.dart';
import 'ai_response.dart';
import 'ai_router.dart';
import 'ai_routing_result.dart';

class AIService {
  const AIService({required AIRouter router}) : _router = router;

  final AIRouter _router;

  AIRoutingResult selectProvider(AIRequest request) {
    return _router.route(request);
  }

  Future<AIResponse> complete(AIRequest request) {
    final AIRoutingResult result = selectProvider(request);
    return result.provider.complete(request);
  }

  Stream<AIChunk> stream(AIRequest request) async* {
    final AIRoutingResult result = selectProvider(request);

    yield AIChunk.status(provider: result.provider.type, text: result.reason);

    yield* result.provider.stream(request);
  }
}
