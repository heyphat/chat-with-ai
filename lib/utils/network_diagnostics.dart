import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

class NetworkDiagnostics {
  static Future<Map<String, dynamic>> testApiEndpoint(String endpoint, {Map<String, String>? headers}) async {
    final results = <String, dynamic>{};
    
    developer.log('Starting network diagnostics for endpoint: $endpoint');
    
    // Test basic connectivity with ping
    try {
      final uri = Uri.parse(endpoint);
      results['host'] = uri.host;
      
      final socket = await Socket.connect(uri.host, uri.port > 0 ? uri.port : 443, 
          timeout: const Duration(seconds: 5));
      results['socket_connection'] = 'success';
      results['local_address'] = socket.address.address;
      results['local_port'] = socket.port;
      results['remote_address'] = socket.remoteAddress.address;
      results['remote_port'] = socket.remotePort;
      socket.destroy();
    } catch (e) {
      results['socket_connection'] = 'failed';
      results['socket_error'] = e.toString();
      developer.log('Socket connection error: $e');
    }
    
    // Test simple HEAD request
    try {
      final headResponse = await http.head(
        Uri.parse(endpoint),
        headers: headers ?? {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      results['head_request_status'] = headResponse.statusCode;
      results['head_request_headers'] = headResponse.headers;
    } catch (e) {
      results['head_request_status'] = 'failed';
      results['head_request_error'] = e.toString();
      developer.log('HEAD request error: $e');
    }
    
    // If using a proxy, try to detect it
    try {
      String? httpProxy = Platform.environment['HTTP_PROXY'] ?? 
                          Platform.environment['http_proxy'];
      String? httpsProxy = Platform.environment['HTTPS_PROXY'] ?? 
                           Platform.environment['https_proxy'];
      
      results['http_proxy'] = httpProxy;
      results['https_proxy'] = httpsProxy;
      
      if (httpProxy != null || httpsProxy != null) {
        developer.log('Proxy environment variables detected: HTTP_PROXY=$httpProxy, HTTPS_PROXY=$httpsProxy');
      }
    } catch (e) {
      developer.log('Error detecting proxy settings: $e');
    }
    
    developer.log('Network diagnostics completed for $endpoint: ${jsonEncode(results)}');
    return results;
  }

  static Future<void> runAnthropicDiagnostics(String apiKey) async {
    try {
      final endpoint = 'https://api.anthropic.com/v1/messages';
      
      final headers = {
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01',
        'x-api-key': apiKey,
      };
      
      // Test basic connectivity
      final diagnosticResults = await testApiEndpoint(endpoint, headers: headers);
      developer.log('Anthropic API connectivity diagnostics: ${jsonEncode(diagnosticResults)}');
      
      // If basic connection succeeded, try a minimal API request
      if (diagnosticResults['socket_connection'] == 'success') {
        try {
          // Create a minimal test request to Anthropic
          final body = jsonEncode({
            'model': 'claude-3-haiku',
            'messages': [
              {'role': 'user', 'content': 'Hello, this is a diagnostic test.'},
            ],
            'max_tokens': 10,
          });
          
          final response = await http.post(
            Uri.parse(endpoint),
            headers: headers,
            body: body,
          ).timeout(const Duration(seconds: 15));
          
          developer.log('Anthropic test request status: ${response.statusCode}');
          developer.log('Anthropic test response: ${response.body}');
        } catch (e) {
          developer.log('Error during Anthropic test request: $e');
        }
      }
    } catch (e) {
      developer.log('Error running Anthropic diagnostics: $e');
    }
  }
} 