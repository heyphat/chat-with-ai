import '../models/message.dart';
import '../models/token_usage.dart';

abstract class AIService {
  Future<(String, TokenUsage?)> getCompletion(
    List<Message> messages,
    String model,
  );

  Stream<String> getCompletionStream(List<Message> messages, String model);

  // Gives access to the token usage after a stream completes
  Future<TokenUsage?> getLastStreamTokenUsage();
}
