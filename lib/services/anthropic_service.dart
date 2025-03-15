import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../utils/network_diagnostics.dart';
import 'ai_service.dart';
import 'dart:developer' as developer;

class AnthropicService implements AIService {
  static bool _hasRunDiagnostics = false;
  late final Dio _dio;
  
  AnthropicService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
      validateStatus: (status) => true, // Accept all status codes and handle them manually
    ));
    
    // Add logging interceptor
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (log) => developer.log(log.toString()),
    ));
  }

  @override
  Future<String> getCompletion(List<Message> messages, String model) async {
    final apiKey = await _getApiKey();
    final endpoint = await _getEndpoint();

    if (apiKey.isEmpty) {
      throw Exception('Anthropic API key not found. Please add your API key in the Settings.');
    }

    // Run diagnostics once if not already done
    if (!_hasRunDiagnostics) {
      await _runDiagnostics(apiKey, endpoint);
    }

    final headers = {
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
      'x-api-key': apiKey,
    };

    // Convert our messages to Anthropic format
    final formattedMessages = messages.map((msg) => {
      'role': msg.role == MessageRole.assistant ? 'assistant' : msg.role == MessageRole.system ? 'system' : 'user',
      'content': msg.content,
    }).toList();

    final data = {
      'model': model,
      'messages': formattedMessages,
      'max_tokens': 1000,
      'temperature': 0.7,
    };

    developer.log('Attempting to connect to Anthropic API with Dio at: $endpoint');
    developer.log('Using model: $model');
    
    try {
      // Implement retry logic
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          developer.log('Anthropic API request attempt $attempt with Dio');
          
          final response = await _dio.post(
            endpoint,
            options: Options(headers: headers),
            data: data,
          );

          developer.log('Anthropic API response status: ${response.statusCode}');
          
          if (response.statusCode == 200) {
            final jsonResponse = response.data;
            
            // Handle both old and new API formats
            if (jsonResponse.containsKey('content') && jsonResponse['content'] is List) {
              return jsonResponse['content'][0]['text'];
            } else if (jsonResponse.containsKey('content')) {
              return jsonResponse['content'];
            } else {
              throw Exception('Unexpected response format from Anthropic API');
            }
          } else {
            developer.log('Anthropic API error: ${response.statusCode} - ${response.data}');
            
            // If this is the last attempt, throw the exception
            if (attempt == 3) {
              throw Exception('Failed to get response from Anthropic: ${response.statusCode} - ${response.data}');
            }
            
            // Wait before retrying
            await Future.delayed(Duration(seconds: 2 * attempt));
          }
        } on DioException catch (e) {
          developer.log('Dio exception on attempt $attempt: ${e.message}');
          developer.log('Dio error type: ${e.type}');
          
          if (attempt == 3) {
            // On final failure, provide a more helpful error message based on the error type
            switch (e.type) {
              case DioExceptionType.connectionTimeout:
                throw Exception('Connection to Anthropic API timed out. Please check your internet connection or try again later.');
              case DioExceptionType.sendTimeout:
                throw Exception('Sending request to Anthropic API timed out. Your network may be slow or unstable.');
              case DioExceptionType.receiveTimeout:
                throw Exception('Waiting for Anthropic API response timed out. The service might be overloaded.');
              case DioExceptionType.badResponse:
                throw Exception('Received invalid response from Anthropic API: ${e.response?.statusCode} - ${e.response?.data}');
              case DioExceptionType.connectionError:
                // Run additional diagnostics on connection errors
                await _runDiagnostics(apiKey, endpoint);
                throw Exception('Connection error with Anthropic API. Please check your network settings and API endpoint configuration.');
              default:
                throw Exception('Error connecting to Anthropic: ${e.message}');
            }
          }
          await Future.delayed(Duration(seconds: 2 * attempt));
        } catch (e) {
          developer.log('Other exception on attempt $attempt: $e');
          if (attempt == 3) {
            throw Exception('Error connecting to Anthropic: $e');
          }
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
      
      // Should never reach here but just in case
      throw Exception('Failed to connect to Anthropic after multiple attempts');
    } catch (e) {
      developer.log('Error connecting to Anthropic: $e');
      throw Exception('Error connecting to Anthropic: $e');
    }
  }

  Future<void> _runDiagnostics(String apiKey, String endpoint) async {
    try {
      _hasRunDiagnostics = true;
      developer.log('Running Anthropic API connection diagnostics');
      
      final diagnostics = await NetworkDiagnostics.testApiEndpoint(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'anthropic-version': '2023-06-01',
          'x-api-key': apiKey,
        },
      );
      
      developer.log('Anthropic connection diagnostics result: ${jsonEncode(diagnostics)}');
      
      if (diagnostics['socket_connection'] == 'failed') {
        developer.log('WARNING: Failed to establish basic socket connection to Anthropic API');
      }
      
      if (diagnostics['head_request_status'] == 'failed') {
        developer.log('WARNING: Failed to make HEAD request to Anthropic API');
      }
    } catch (e) {
      developer.log('Error running diagnostics: $e');
    }
  }

  @override
  Stream<String> getCompletionStream(List<Message> messages, String model) async* {
    final apiKey = await _getApiKey();
    final endpoint = await _getEndpoint();

    if (apiKey.isEmpty) {
      throw Exception('Anthropic API key not found. Please add your API key in the Settings.');
    }

    // Run diagnostics once if not already done
    if (!_hasRunDiagnostics) {
      await _runDiagnostics(apiKey, endpoint);
    }

    // Add a system message instructing to use LaTeX for math
    Message systemMessage;
    
    // Check if there's already a system message
    final hasSystemMessage = messages.any((msg) => msg.role == MessageRole.system);
    
    if (hasSystemMessage) {
      // Find the system message and append math formatting instructions
      final existingSystemMsgIdx = messages.indexWhere((msg) => msg.role == MessageRole.system);
      final existingSystemMsg = messages[existingSystemMsgIdx];
      
      systemMessage = Message(
        id: existingSystemMsg.id,
        content: '${existingSystemMsg.content}\n\nWhen including mathematical expressions or equations in your response, use LaTeX notation. For inline equations, use single dollar signs like \$x^2\$. For display equations, use double dollar signs like \$\$E=mc^2\$\$.',
        role: MessageRole.system,
        timestamp: existingSystemMsg.timestamp,
      );
      
      // Replace the system message
      messages = [...messages];  // Create a copy to avoid modifying the original
      messages[existingSystemMsgIdx] = systemMessage;
    } else {
      // Create a new system message
      systemMessage = Message(
        id: 'math-format',
        content: 'When including mathematical expressions or equations in your response, use LaTeX notation. For inline equations, use single dollar signs like \$x^2\$. For display equations, use double dollar signs like \$\$E=mc^2\$\$.',
        role: MessageRole.system,
        timestamp: DateTime.now(),
      );
      
      // Add it to the beginning
      messages = [systemMessage, ...messages];
    }

    final headers = {
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
      'x-api-key': apiKey,
    };

    // Convert our messages to Anthropic format
    final formattedMessages = messages.map((msg) => {
      'role': msg.role == MessageRole.assistant ? 'assistant' : msg.role == MessageRole.system ? 'system' : 'user',
      'content': msg.content,
    }).toList();

    final data = {
      'model': model,
      'messages': formattedMessages,
      'max_tokens': 1000,
      'temperature': 0.7,
      'stream': true,  // Enable streaming
    };

    developer.log('Attempting to connect to Anthropic API streaming with Dio at: $endpoint');
    developer.log('Using model: $model');

    final client = http.Client();

    try {
      // Dio doesn't support streaming responses well, so we'll use http for streaming
      try {
        // First, try a simple HEAD request with Dio to see if the endpoint is reachable
        try {
          final testResponse = await _dio.head(
            endpoint,
            options: Options(headers: {'Content-Type': 'application/json'}),
          );
          
          developer.log('Anthropic API HEAD request status with Dio: ${testResponse.statusCode}');
        } catch (e) {
          developer.log('Warning: Basic HEAD request to Anthropic API failed with Dio: $e');
          // Don't throw here, just log the warning
        }
        
        developer.log('Attempting to set up streaming connection to Anthropic API');
        final request = http.Request('POST', Uri.parse(endpoint));
        request.headers.addAll(headers);
        request.body = jsonEncode(data);

        final response = await client.send(request).timeout(const Duration(seconds: 90));

        if (response.statusCode != 200) {
          final errorBody = await response.stream.bytesToString();
          developer.log('Anthropic streaming error: ${response.statusCode} - $errorBody');
          client.close();
          throw Exception('Failed to get streaming response from Anthropic: ${response.statusCode} - $errorBody');
        }
        
        developer.log('Anthropic streaming connection established');

        // Process the stream
        await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
          if (chunk.startsWith('data: ') && chunk.length > 6) {
            final jsonStr = chunk.substring(6);
            
            if (jsonStr == '[DONE]') {
              break;  // End of stream
            }
            
            try {
              final jsonData = jsonDecode(jsonStr);
              
              // Handle different streaming event types
              if (jsonData['type'] == 'content_block_delta') {
                final delta = jsonData['delta'];
                final text = delta['text'];
                
                if (text != null && text.isNotEmpty) {
                  yield text;
                }
              } else if (jsonData['type'] == 'content_block_start' && 
                        jsonData['content_block'] != null &&
                        jsonData['content_block']['type'] == 'text') {
                // Handle initial content block
                final text = jsonData['content_block']['text'] ?? '';
                if (text.isNotEmpty) {
                  yield text;
                }
              } else if (jsonData['type'] == 'message_delta' && 
                        jsonData['delta'] != null &&
                        jsonData['delta']['text'] != null) {
                // Handle older format
                final text = jsonData['delta']['text'];
                if (text != null && text.isNotEmpty) {
                  yield text;
                }
              }
            } catch (e) {
              // Skip invalid JSON
              developer.log('Error parsing JSON from stream: $e');
            }
          }
        }
        
        client.close();
      } catch (e) {
        client.close();
        // If streaming failed, try to fall back to non-streaming to at least get a response
        developer.log('Streaming failed, attempting to fall back to non-streaming request: $e');
        
        // Remove the stream flag from the request
        data.remove('stream');
        
        try {
          final response = await _dio.post(
            endpoint,
            options: Options(headers: headers),
            data: data,
          );
          
          if (response.statusCode == 200 && response.data != null) {
            developer.log('Successfully fell back to non-streaming request');
            
            final jsonResponse = response.data;
            String content = '';
            
            // Handle both old and new API formats
            if (jsonResponse.containsKey('content') && jsonResponse['content'] is List) {
              content = jsonResponse['content'][0]['text'];
            } else if (jsonResponse.containsKey('content')) {
              content = jsonResponse['content'];
            }
            
            if (content.isNotEmpty) {
              yield content;
            }
          } else {
            throw Exception('Failed to get fallback response from Anthropic: ${response.statusCode}');
          }
        } catch (fallbackError) {
          developer.log('Fallback request also failed: $fallbackError');
          throw Exception('Error connecting to Anthropic: $e');
        }
      }
    } catch (e) {
      client.close();
      developer.log('Error during Anthropic streaming: $e');
      throw Exception('Error connecting to Anthropic: $e');
    }
  }

  // Get API key from SharedPreferences first, then fallback to .env
  Future<String> _getApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('ANTHROPIC_API_KEY');
      
      if (apiKey != null && apiKey.isNotEmpty) {
        return apiKey;
      }
      
      final envKey = dotenv.env['ANTHROPIC_API_KEY'] ?? '';
      return envKey;
    } catch (e) {
      developer.log('Error retrieving Anthropic API key: $e');
      return '';
    }
  }

  // Get endpoint from SharedPreferences first, then fallback to .env
  Future<String> _getEndpoint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final endpoint = prefs.getString('ANTHROPIC_API_ENDPOINT');
      
      if (endpoint != null && endpoint.isNotEmpty) {
        return endpoint;
      }
      
      return dotenv.env['ANTHROPIC_API_ENDPOINT'] ?? 'https://api.anthropic.com/v1/messages';
    } catch (e) {
      developer.log('Error retrieving Anthropic endpoint: $e');
      return 'https://api.anthropic.com/v1/messages';
    }
  }
} 