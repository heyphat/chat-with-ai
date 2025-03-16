import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../models/token_usage.dart';
import 'ai_service.dart';
import 'logger_service.dart';

class OpenAIService implements AIService {
  final LoggerService _logger = LoggerService();
  TokenUsage? _lastStreamTokenUsage;

  @override
  Future<(String, TokenUsage?)> getCompletion(
    List<Message> messages,
    String model,
  ) async {
    _logger.info(
      'Getting OpenAI completion',
      tag: 'OPENAI',
      data: {'model': model},
    );

    final apiKey = await _getApiKey();
    final endpoint = await _getEndpoint();

    if (apiKey.isEmpty) {
      _logger.error('OpenAI API key not found', tag: 'OPENAI');
      throw Exception(
        'OpenAI API key not found. Please add your API key in the Settings.',
      );
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final body = jsonEncode({
      'model': model,
      'messages':
          messages
              .map((msg) => {'role': msg.role.name, 'content': msg.content})
              .toList(),
      'temperature': 0.7,
    });

    try {
      _logger.debug('Sending request to OpenAI API', tag: 'OPENAI');

      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        _logger.info('Received successful response from OpenAI', tag: 'OPENAI');
        final jsonResponse = jsonDecode(response.body);
        final String content = jsonResponse['choices'][0]['message']['content'];

        // Parse token usage information with pricing info
        final TokenUsage? tokenUsage = TokenUsage.fromOpenAI(
          jsonResponse,
          model,
          costPerThousandTokens:
              TokenPricing.defaultPricing().pricePerThousandTokens,
        );

        // Log token usage information
        if (tokenUsage != null) {
          _logger.info(
            'Token usage information',
            tag: 'OPENAI',
            data: {
              'promptTokens': tokenUsage.promptTokens,
              'completionTokens': tokenUsage.completionTokens,
              'totalTokens': tokenUsage.totalTokens,
              'totalCost': tokenUsage.totalCost,
            },
          );
        }

        return (content, tokenUsage);
      } else {
        _logger.error(
          'OpenAI API error',
          tag: 'OPENAI',
          data: {'statusCode': response.statusCode, 'response': response.body},
        );
        throw Exception(
          'Failed to get response from OpenAI: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      _logger.error('Error connecting to OpenAI', tag: 'OPENAI', error: e);
      throw Exception('Error connecting to OpenAI: $e');
    }
  }

  @override
  Stream<String> getCompletionStream(
    List<Message> messages,
    String model,
  ) async* {
    final apiKey = await _getApiKey();
    final endpoint = await _getEndpoint();

    if (apiKey.isEmpty) {
      throw Exception(
        'OpenAI API key not found. Please add your API key in the Settings.',
      );
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final body = jsonEncode({
      'stream': true,
      'model': model,
      'messages':
          messages
              .map((msg) => {'role': msg.role.name, 'content': msg.content})
              .toList(),
      'temperature': 0.7,
    });

    try {
      final request = http.Request('POST', Uri.parse(endpoint));
      request.headers.addAll(headers);
      request.body = body;

      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        _logger.error(
          'OpenAI streaming error',
          tag: 'OPENAI',
          data: {'statusCode': response.statusCode, 'response': errorBody},
        );
        throw Exception(
          'Failed to get response from OpenAI: ${response.statusCode} - $errorBody',
        );
      }

      // Clear the previous token usage in case we're reusing this service instance
      _lastStreamTokenUsage = null;

      // Keep track of recent chunks to look for token usage data that often appears right before [DONE]
      final recentChunks = <Map<String, dynamic>>[];
      final maxRecentChunks =
          5; // Store the last 5 chunks to check for token usage

      // Process the stream
      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.startsWith('data: ') && chunk.length > 6) {
          final jsonStr = chunk.substring(6);

          if (jsonStr == '[DONE]') {
            // When we get [DONE], check the recent chunks for token usage data
            _logger.debug(
              'Received [DONE], checking recent chunks for token usage',
              tag: 'OPENAI',
            );

            // Check recent chunks in reverse order (most recent first)
            for (final recentChunk in recentChunks.reversed) {
              if (recentChunk.containsKey('usage')) {
                _lastStreamTokenUsage = TokenUsage.fromOpenAI(
                  recentChunk,
                  model,
                  costPerThousandTokens:
                      TokenPricing.defaultPricing().pricePerThousandTokens,
                );
                _logger.info(
                  'Stream token usage information found in recent chunk before [DONE]',
                  tag: 'OPENAI',
                  data: {
                    'promptTokens': _lastStreamTokenUsage?.promptTokens,
                    'completionTokens': _lastStreamTokenUsage?.completionTokens,
                    'totalTokens': _lastStreamTokenUsage?.totalTokens,
                    'totalCost': _lastStreamTokenUsage?.totalCost,
                  },
                );
                break;
              }
            }
            break; // End of stream
          }

          try {
            final jsonData = jsonDecode(jsonStr);

            // Store this chunk for later inspection
            recentChunks.add(jsonData);
            if (recentChunks.length > maxRecentChunks) {
              recentChunks.removeAt(
                0,
              ); // Remove oldest chunk if we exceed our limit
            }

            // Check for token usage information in this chunk
            if (jsonData.containsKey('usage')) {
              _lastStreamTokenUsage = TokenUsage.fromOpenAI(
                jsonData,
                model,
                costPerThousandTokens:
                    TokenPricing.defaultPricing().pricePerThousandTokens,
              );
              _logger.info(
                'Stream token usage information found in current chunk',
                tag: 'OPENAI',
                data: {
                  'promptTokens': _lastStreamTokenUsage?.promptTokens,
                  'completionTokens': _lastStreamTokenUsage?.completionTokens,
                  'totalTokens': _lastStreamTokenUsage?.totalTokens,
                  'totalCost': _lastStreamTokenUsage?.totalCost,
                },
              );
            }

            final delta = jsonData['choices'][0]['delta'];
            if (delta != null && delta.containsKey('content')) {
              final content = delta['content'];
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            }
          } catch (e) {
            // Skip invalid JSON
            _logger.debug('Error parsing JSON chunk: $e', tag: 'OPENAI');
          }
        }
      }

      // If we didn't get token usage from the stream, make a separate API call to get it
      if (_lastStreamTokenUsage == null) {
        _logger.info(
          'No token usage found in stream, attempting to get it separately',
          tag: 'OPENAI',
        );

        try {
          // Make a non-streaming call to get token usage
          final nonStreamBody = jsonEncode({
            'model': model,
            'messages':
                messages
                    .map(
                      (msg) => {'role': msg.role.name, 'content': msg.content},
                    )
                    .toList(),
            'temperature': 0.7,
            'max_tokens': 1, // Minimize token usage for this call
          });

          final usageResponse = await http.post(
            Uri.parse(endpoint),
            headers: headers,
            body: nonStreamBody,
          );

          if (usageResponse.statusCode == 200) {
            final jsonResponse = jsonDecode(usageResponse.body);
            _lastStreamTokenUsage = TokenUsage.fromOpenAI(
              jsonResponse,
              model,
              costPerThousandTokens:
                  TokenPricing.defaultPricing().pricePerThousandTokens,
            );
            _logger.info(
              'Retrieved token usage from separate API call',
              tag: 'OPENAI',
              data: {
                'promptTokens': _lastStreamTokenUsage?.promptTokens,
                'completionTokens': _lastStreamTokenUsage?.completionTokens,
                'totalTokens': _lastStreamTokenUsage?.totalTokens,
                'totalCost': _lastStreamTokenUsage?.totalCost,
              },
            );
          }
        } catch (e) {
          _logger.error(
            'Error getting token usage from separate call',
            tag: 'OPENAI',
            error: e,
          );
        }
      }
    } catch (e) {
      _logger.error('Error during OpenAI streaming', tag: 'OPENAI', error: e);
      throw Exception('Error connecting to OpenAI: $e');
    }
  }

  @override
  Future<TokenUsage?> getLastStreamTokenUsage() async {
    return _lastStreamTokenUsage;
  }

  // Get API key from SharedPreferences first, then fallback to .env
  Future<String> _getApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('OPENAI_API_KEY');

      if (apiKey != null && apiKey.isNotEmpty) {
        return apiKey;
      }

      final envKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      return envKey;
    } catch (e) {
      _logger.error('Error retrieving OpenAI API key', tag: 'OPENAI', error: e);
      return '';
    }
  }

  // Get endpoint from SharedPreferences first, then fallback to .env
  Future<String> _getEndpoint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final endpoint = prefs.getString('OPENAI_API_ENDPOINT');

      if (endpoint != null && endpoint.isNotEmpty) {
        return endpoint;
      }

      return dotenv.env['OPENAI_API_ENDPOINT'] ??
          'https://api.openai.com/v1/chat/completions';
    } catch (e) {
      _logger.error(
        'Error retrieving OpenAI endpoint',
        tag: 'OPENAI',
        error: e,
      );
      return 'https://api.openai.com/v1/chat/completions';
    }
  }
}
