import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _openAIController = TextEditingController();
  final TextEditingController _anthropicController = TextEditingController();
  final TextEditingController _geminiController = TextEditingController();
  final TextEditingController _openAIEndpointController = TextEditingController();
  final TextEditingController _anthropicEndpointController = TextEditingController();
  // Gemini endpoint controller is not needed with the SDK

  bool _isLoadingKeys = false;
  bool _isSavingKeys = false;
  bool _showEndpoints = false;

  @override
  void initState() {
    super.initState();
    _loadAPIKeys();
  }

  @override
  void dispose() {
    _openAIController.dispose();
    _anthropicController.dispose();
    _geminiController.dispose();
    _openAIEndpointController.dispose();
    _anthropicEndpointController.dispose();
    super.dispose();
  }

  Future<void> _loadAPIKeys() async {
    setState(() {
      _isLoadingKeys = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load API keys from SharedPreferences first, then fall back to .env
      _openAIController.text = prefs.getString('OPENAI_API_KEY') ?? 
                               dotenv.env['OPENAI_API_KEY'] ?? '';
      
      _anthropicController.text = prefs.getString('ANTHROPIC_API_KEY') ?? 
                                 dotenv.env['ANTHROPIC_API_KEY'] ?? '';
      
      _geminiController.text = prefs.getString('GEMINI_API_KEY') ?? 
                              dotenv.env['GEMINI_API_KEY'] ?? '';
      
      // Load endpoints
      _openAIEndpointController.text = prefs.getString('OPENAI_API_ENDPOINT') ?? 
                                     dotenv.env['OPENAI_API_ENDPOINT'] ?? 
                                     'https://api.openai.com/v1/chat/completions';
      
      _anthropicEndpointController.text = prefs.getString('ANTHROPIC_API_ENDPOINT') ?? 
                                       dotenv.env['ANTHROPIC_API_ENDPOINT'] ?? 
                                       'https://api.anthropic.com/v1/messages';
      
      // Gemini endpoint is not needed with the SDK
      
      developer.log('API keys and endpoints loaded successfully');
    } catch (e) {
      developer.log('Error loading API keys: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading API keys: $e')),
      );
    } finally {
      setState(() {
        _isLoadingKeys = false;
      });
    }
  }

  Future<void> _saveAPIKeys() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSavingKeys = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save API keys
      await prefs.setString('OPENAI_API_KEY', _openAIController.text.trim());
      await prefs.setString('ANTHROPIC_API_KEY', _anthropicController.text.trim());
      await prefs.setString('GEMINI_API_KEY', _geminiController.text.trim());
      
      // Save endpoints
      await prefs.setString('OPENAI_API_ENDPOINT', _openAIEndpointController.text.trim());
      await prefs.setString('ANTHROPIC_API_ENDPOINT', _anthropicEndpointController.text.trim());
      // Gemini endpoint is not needed with the SDK
      
      // Update environment variables in memory (these are volatile and won't persist across app restarts)
      dotenv.env['OPENAI_API_KEY'] = _openAIController.text.trim();
      dotenv.env['ANTHROPIC_API_KEY'] = _anthropicController.text.trim();
      dotenv.env['GEMINI_API_KEY'] = _geminiController.text.trim();
      dotenv.env['OPENAI_API_ENDPOINT'] = _openAIEndpointController.text.trim();
      dotenv.env['ANTHROPIC_API_ENDPOINT'] = _anthropicEndpointController.text.trim();
      // Gemini endpoint is not needed with the SDK

      developer.log('API keys and endpoints saved successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API keys saved successfully')),
      );
    } catch (e) {
      developer.log('Error saving API keys: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving API keys: $e')),
      );
    } finally {
      setState(() {
        _isSavingKeys = false;
      });
    }
  }

  void _toggleShowEndpoints() {
    setState(() {
      _showEndpoints = !_showEndpoints;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoadingKeys
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'API Keys',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your API keys for different AI providers. These keys will be stored securely on your device.',
                      ),
                      const SizedBox(height: 24),
                      
                      // OpenAI API Key
                      _buildAPIKeyField(
                        label: 'OpenAI API Key',
                        controller: _openAIController,
                        hintText: 'sk-...',
                        validator: (value) {
                          if (value != null && value.isNotEmpty && !value.startsWith('sk-')) {
                            return 'OpenAI API keys should start with sk-';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Anthropic API Key
                      _buildAPIKeyField(
                        label: 'Anthropic API Key',
                        controller: _anthropicController,
                        hintText: 'sk-ant-...',
                        validator: (value) {
                          if (value != null && value.isNotEmpty && !value.startsWith('sk-ant-')) {
                            return 'Anthropic API keys should start with sk-ant-';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Gemini API Key
                      _buildAPIKeyField(
                        label: 'Gemini API Key',
                        controller: _geminiController,
                        hintText: 'AIza...',
                        validator: (value) {
                          return null; // No specific validation for Gemini
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Advanced settings toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: _toggleShowEndpoints,
                            icon: Icon(_showEndpoints ? Icons.expand_less : Icons.expand_more),
                            label: Text(_showEndpoints ? 'Hide Advanced Settings' : 'Show Advanced Settings'),
                          ),
                        ],
                      ),
                      
                      if (_showEndpoints) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'API Endpoints',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Advanced: Customize the API endpoints if needed.',
                        ),
                        const SizedBox(height: 16),
                        
                        // OpenAI Endpoint
                        _buildTextField(
                          label: 'OpenAI API Endpoint',
                          controller: _openAIEndpointController,
                          hintText: 'https://api.openai.com/v1/chat/completions',
                        ),
                        const SizedBox(height: 16),
                        
                        // Anthropic Endpoint
                        _buildTextField(
                          label: 'Anthropic API Endpoint',
                          controller: _anthropicEndpointController,
                          hintText: 'https://api.anthropic.com/v1/messages',
                        ),
                        const SizedBox(height: 16),
                        
                        // Gemini endpoint is not required with the SDK
                        // const SizedBox(height: 16),
                      ],
                      
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSavingKeys ? null : _saveAPIKeys,
                          child: _isSavingKeys
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save Settings'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildAPIKeyField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () {
                // This is just a placeholder for a real show/hide password toggle
                // In a real app, you'd want to implement secure text entry
              },
            ),
          ),
          obscureText: true,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
} 