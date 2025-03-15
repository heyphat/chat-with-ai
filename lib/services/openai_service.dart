import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import 'ai_service.dart';
import 'logger_service.dart';

class OpenAIService implements AIService {
  final LoggerService _logger = LoggerService();

  @override
  Future<String> getCompletion(List<Message> messages, String model) async {
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
        return jsonResponse['choices'][0]['message']['content'];
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
      // 'stream': true, // Enable streaming
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

      // Process the stream
      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.startsWith('data: ') && chunk.length > 6) {
          final jsonStr = chunk.substring(6);

          if (jsonStr == '[DONE]') {
            break; // End of stream
          }

          try {
            final jsonData = jsonDecode(jsonStr);

            final delta = jsonData['choices'][0]['delta'];
            if (delta != null && delta.containsKey('content')) {
              final content = delta['content'];
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            }
          } catch (e) {
            // Skip invalid JSON
          }
        }
      }
    } catch (e) {
      _logger.error('Error during OpenAI streaming', tag: 'OPENAI', error: e);
      throw Exception('Error connecting to OpenAI: $e');
    }
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
