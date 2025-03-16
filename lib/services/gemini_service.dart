import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../models/token_usage.dart';
import '../models/chat.dart';
import 'ai_service.dart';
import 'logger_service.dart';

class GeminiService implements AIService {
  final LoggerService _logger = LoggerService();
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
      _logger.info(
        'Sending request to Gemini',
        tag: 'GEMINI',
        data: {'model': model},
      );

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

      // Extract token usage from Gemini response if available
      TokenUsage? tokenUsage;
      if (response.usageMetadata != null) {
        // Get cost calculation pricing data
        final pricingData =
            TokenPricing.defaultPricing().pricePerThousandTokens;

        // Calculate costs
        final promptTokens = response.usageMetadata?.promptTokenCount ?? 0;
        final completionTokens =
            response.usageMetadata?.candidatesTokenCount ?? 0;
        final totalTokens = response.usageMetadata?.totalTokenCount ?? 0;

        final String modelKey =
            pricingData.containsKey(model) ? model : 'default';
        final promptRate =
            pricingData['${modelKey}_prompt'] ??
            pricingData['default_prompt'] ??
            0;
        final completionRate =
            pricingData['${modelKey}_completion'] ??
            pricingData['default_completion'] ??
            0;

        final promptCost = (promptTokens / 1000) * promptRate;
        final completionCost = (completionTokens / 1000) * completionRate;
        final totalCost = promptCost + completionCost;

        tokenUsage = TokenUsage(
          promptTokens: promptTokens,
          completionTokens: completionTokens,
          totalTokens: totalTokens,
          promptCost: promptCost,
          completionCost: completionCost,
          totalCost: totalCost,
          model: model,
          provider: AIProvider.gemini,
        );

        _logger.info(
          'Token usage information',
          tag: 'GEMINI',
          data: {
            'promptTokens': tokenUsage.promptTokens,
            'completionTokens': tokenUsage.completionTokens,
            'totalTokens': tokenUsage.totalTokens,
            'totalCost': tokenUsage.totalCost,
          },
        );
      }

      return (responseText, tokenUsage);
    } catch (e) {
      _logger.error('Error in Gemini completion', tag: 'GEMINI', error: e);
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
      _logger.info(
        'Starting Gemini streaming',
        tag: 'GEMINI',
        data: {'model': model},
      );

      // Create a simple text-only content
      final prompt = [Content.text(promptText)];

      // Clear the previous token usage in case we're reusing this service instance
      _lastStreamTokenUsage = null;

      // Generate content as a stream
      final responseStream = modelInstance.generateContentStream(prompt);
      int chunkCount = 0;
      GenerateContentResponse? lastResponse;

      await for (final response in responseStream) {
        lastResponse = response;
        chunkCount++;

        // Process the chunk
        if (response.text != null) {
          yield response.text!;
        }
      }

      // After streaming is complete, extract token usage from the last response if available
      if (lastResponse != null && lastResponse.usageMetadata != null) {
        // Get cost calculation pricing data
        final pricingData =
            TokenPricing.defaultPricing().pricePerThousandTokens;

        // Calculate costs
        final promptTokens = lastResponse.usageMetadata?.promptTokenCount ?? 0;
        final completionTokens =
            lastResponse.usageMetadata?.candidatesTokenCount ?? 0;
        final totalTokens = lastResponse.usageMetadata?.totalTokenCount ?? 0;

        final String modelKey =
            pricingData.containsKey(model) ? model : 'default';
        final promptRate =
            pricingData['${modelKey}_prompt'] ??
            pricingData['default_prompt'] ??
            0;
        final completionRate =
            pricingData['${modelKey}_completion'] ??
            pricingData['default_completion'] ??
            0;

        final promptCost = (promptTokens / 1000) * promptRate;
        final completionCost = (completionTokens / 1000) * completionRate;
        final totalCost = promptCost + completionCost;

        _lastStreamTokenUsage = TokenUsage(
          promptTokens: promptTokens,
          completionTokens: completionTokens,
          totalTokens: totalTokens,
          promptCost: promptCost,
          completionCost: completionCost,
          totalCost: totalCost,
          model: model,
          provider: AIProvider.gemini,
        );

        _logger.info(
          'Stream token usage information found after streaming complete',
          tag: 'GEMINI',
          data: {
            'promptTokens': _lastStreamTokenUsage?.promptTokens,
            'completionTokens': _lastStreamTokenUsage?.completionTokens,
            'totalTokens': _lastStreamTokenUsage?.totalTokens,
            'totalCost': _lastStreamTokenUsage?.totalCost,
            'chunkCount': chunkCount,
          },
        );
      } else {
        _logger.info(
          'No token usage information available in streaming response',
          tag: 'GEMINI',
          data: {'chunkCount': chunkCount},
        );
      }
    } catch (e) {
      _logger.error('Error in Gemini streaming', tag: 'GEMINI', error: e);
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
      _logger.error('Error retrieving Gemini API key', tag: 'GEMINI', error: e);
      return '';
    }
  }

  @override
  Future<TokenUsage?> getLastStreamTokenUsage() async {
    return _lastStreamTokenUsage;
  }
}
