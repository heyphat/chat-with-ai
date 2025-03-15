import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../models/token_usage.dart';
import 'ai_service.dart';
import 'dart:developer' as developer;

class GeminiService implements AIService {
  TokenUsage? _lastStreamTokenUsage;

  @override
  Future<(String, TokenUsage?)> getCompletion(
    List<Message> messages,
    String model,
  ) async {
    try {
      final apiKey = await _getApiKey();

      if (apiKey.isEmpty) {
        throw Exception(
          'Gemini API key not found. Please add your API key in the Settings.',
        );
      }

      // Create the GenerativeModel instance
      final modelInstance = GenerativeModel(model: model, apiKey: apiKey);

      // Convert to a simple prompt text
      final promptText = _convertMessagesToPrompt(messages);
      developer.log('Sending request to Gemini with model: $model');

      // Create a simple text-only content
      final prompt = [Content.text(promptText)];

      // Generate content
      final response = await modelInstance.generateContent(prompt);

      final String responseText;
      if (response.text != null) {
        responseText = response.text!;
      } else {
        responseText = 'No response from Gemini';
      }

      // Gemini API doesn't currently provide token usage info in the same way as OpenAI
      // But we could estimate it in the future
      final TokenUsage? tokenUsage = null;

      return (responseText, tokenUsage);
    } catch (e) {
      developer.log('Error in Gemini completion: $e');
      throw Exception('Error connecting to Gemini: $e');
    }
  }

  @override
  Stream<String> getCompletionStream(
    List<Message> messages,
    String model,
  ) async* {
    try {
      final apiKey = await _getApiKey();

      if (apiKey.isEmpty) {
        throw Exception(
          'Gemini API key not found. Please add your API key in the Settings.',
        );
      }

      // Create the GenerativeModel instance
      final modelInstance = GenerativeModel(model: model, apiKey: apiKey);

      // Convert to a simple prompt text
      final promptText = _convertMessagesToPrompt(messages);
      developer.log('Starting Gemini streaming with model: $model');

      // Create a simple text-only content
      final prompt = [Content.text(promptText)];

      // Generate content as a stream
      final responseStream = modelInstance.generateContentStream(prompt);

      await for (final response in responseStream) {
        if (response.text != null) {
          yield response.text!;
        }
      }
    } catch (e) {
      developer.log('Error in Gemini streaming: $e');
      throw Exception('Error connecting to Gemini: $e');
    }
  }

  // Helper to convert message list to a structured prompt string
  String _convertMessagesToPrompt(List<Message> messages) {
    final buffer = StringBuffer();

    // First, append any system messages
    final systemMessages =
        messages.where((msg) => msg.role == MessageRole.system).toList();
    if (systemMessages.isNotEmpty) {
      buffer.writeln('System instructions:');
      for (final msg in systemMessages) {
        buffer.writeln(msg.content);
      }
      buffer.writeln();
    } else {
      buffer.writeln(
        'You are a helpful, accurate, and thoughtful AI assistant.',
      );
      buffer.writeln();
    }

    // Then add conversation in a chat-like format
    for (final msg in messages.where((m) => m.role != MessageRole.system)) {
      final roleName = msg.role == MessageRole.user ? 'User' : 'Assistant';
      buffer.writeln('$roleName: ${msg.content}');
    }

    return buffer.toString();
  }

  // Get API key from SharedPreferences first, then fallback to .env
  Future<String> _getApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('GEMINI_API_KEY');

      if (apiKey != null && apiKey.isNotEmpty) {
        return apiKey;
      }

      final envKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      return envKey;
    } catch (e) {
      developer.log('Error retrieving Gemini API key: $e');
      return '';
    }
  }

  @override
  Future<TokenUsage?> getLastStreamTokenUsage() async {
    return _lastStreamTokenUsage;
  }
}
