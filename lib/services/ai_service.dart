import '../models/message.dart';

abstract class AIService {
  Future<String> getCompletion(List<Message> messages, String model);
  
  Stream<String> getCompletionStream(List<Message> messages, String model);
} 