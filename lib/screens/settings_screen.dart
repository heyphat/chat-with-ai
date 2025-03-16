import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'dart:async';

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
  final TextEditingController _openAIEndpointController =
      TextEditingController();
  final TextEditingController _anthropicEndpointController =
      TextEditingController();
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
      _openAIController.text =
          prefs.getString('OPENAI_API_KEY') ??
          dotenv.env['OPENAI_API_KEY'] ??
          '';

      _anthropicController.text =
          prefs.getString('ANTHROPIC_API_KEY') ??
          dotenv.env['ANTHROPIC_API_KEY'] ??
          '';

      _geminiController.text =
          prefs.getString('GEMINI_API_KEY') ??
          dotenv.env['GEMINI_API_KEY'] ??
          '';

      // Load endpoints
      _openAIEndpointController.text =
          prefs.getString('OPENAI_API_ENDPOINT') ??
          dotenv.env['OPENAI_API_ENDPOINT'] ??
          'https://api.openai.com/v1/chat/completions';

      _anthropicEndpointController.text =
          prefs.getString('ANTHROPIC_API_ENDPOINT') ??
          dotenv.env['ANTHROPIC_API_ENDPOINT'] ??
          'https://api.anthropic.com/v1/messages';

      // Gemini endpoint is not needed with the SDK

      developer.log('API keys and endpoints loaded successfully');
    } catch (e) {
      developer.log('Error loading API keys: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading API keys: $e')));
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
      await prefs.setString(
        'ANTHROPIC_API_KEY',
        _anthropicController.text.trim(),
      );
      await prefs.setString('GEMINI_API_KEY', _geminiController.text.trim());

      // Save endpoints
      await prefs.setString(
        'OPENAI_API_ENDPOINT',
        _openAIEndpointController.text.trim(),
      );
      await prefs.setString(
        'ANTHROPIC_API_ENDPOINT',
        _anthropicEndpointController.text.trim(),
      );
      // Gemini endpoint is not needed with the SDK

      // Update environment variables in memory (these are volatile and won't persist across app restarts)
      dotenv.env['OPENAI_API_KEY'] = _openAIController.text.trim();
      dotenv.env['ANTHROPIC_API_KEY'] = _anthropicController.text.trim();
      dotenv.env['GEMINI_API_KEY'] = _geminiController.text.trim();
      dotenv.env['OPENAI_API_ENDPOINT'] = _openAIEndpointController.text.trim();
      dotenv.env['ANTHROPIC_API_ENDPOINT'] =
          _anthropicEndpointController.text.trim();
      // Gemini endpoint is not needed with the SDK

      developer.log('API keys and endpoints saved successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API keys saved successfully')),
      );
    } catch (e) {
      developer.log('Error saving API keys: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving API keys: $e')));
    } finally {
      setState(() {
        _isSavingKeys = false;
      });
    }
  }

  // Add auto-save function to save after pasting
  Future<void> _autoSaveAfterPaste(String providerName) async {
    // First validate the form
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSavingKeys = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // Save API keys
      await prefs.setString('OPENAI_API_KEY', _openAIController.text.trim());
      await prefs.setString(
        'ANTHROPIC_API_KEY',
        _anthropicController.text.trim(),
      );
      await prefs.setString('GEMINI_API_KEY', _geminiController.text.trim());

      // Save endpoints
      await prefs.setString(
        'OPENAI_API_ENDPOINT',
        _openAIEndpointController.text.trim(),
      );
      await prefs.setString(
        'ANTHROPIC_API_ENDPOINT',
        _anthropicEndpointController.text.trim(),
      );

      // Update environment variables in memory (these are volatile and won't persist across app restarts)
      dotenv.env['OPENAI_API_KEY'] = _openAIController.text.trim();
      dotenv.env['ANTHROPIC_API_KEY'] = _anthropicController.text.trim();
      dotenv.env['GEMINI_API_KEY'] = _geminiController.text.trim();
      dotenv.env['OPENAI_API_ENDPOINT'] = _openAIEndpointController.text.trim();
      dotenv.env['ANTHROPIC_API_ENDPOINT'] =
          _anthropicEndpointController.text.trim();

      developer.log('API keys saved automatically after pasting');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$providerName API key pasted and saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      developer.log('Error auto-saving API keys: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving key: $e'),
          backgroundColor: Colors.red,
        ),
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
      appBar: AppBar(title: const Text('Settings')),
      body:
          _isLoadingKeys
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

                        // Add a direct paste option
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Quick Paste from Clipboard',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Copy your API key first, then click the button below:',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.paste),
                                  label: const Text('Paste API Key'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24.0,
                                      vertical: 12.0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                  onPressed: () async {
                                    try {
                                      final data = await Clipboard.getData(
                                        Clipboard.kTextPlain,
                                      );
                                      if (data != null && data.text != null) {
                                        // Show selection dialog
                                        showDialog(
                                          context: context,
                                          builder:
                                              (context) => AlertDialog(
                                                title: const Text(
                                                  'Select API Provider',
                                                ),
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'Paste "${data.text!.length > 20 ? "${data.text!.substring(0, 20)}..." : data.text!}" to:',
                                                    ),
                                                    const SizedBox(height: 16),
                                                    ListTile(
                                                      leading: const Icon(
                                                        Icons.api,
                                                      ),
                                                      title: const Text(
                                                        'OpenAI',
                                                      ),
                                                      onTap: () {
                                                        _openAIController.text =
                                                            data.text!.trim();
                                                        Navigator.of(
                                                          context,
                                                        ).pop();
                                                        _autoSaveAfterPaste(
                                                          'OpenAI',
                                                        );
                                                      },
                                                    ),
                                                    ListTile(
                                                      leading: const Icon(
                                                        Icons.api,
                                                      ),
                                                      title: const Text(
                                                        'Anthropic',
                                                      ),
                                                      onTap: () {
                                                        _anthropicController
                                                                .text =
                                                            data.text!.trim();
                                                        Navigator.of(
                                                          context,
                                                        ).pop();
                                                        _autoSaveAfterPaste(
                                                          'Anthropic',
                                                        );
                                                      },
                                                    ),
                                                    ListTile(
                                                      leading: const Icon(
                                                        Icons.api,
                                                      ),
                                                      title: const Text(
                                                        'Gemini',
                                                      ),
                                                      onTap: () {
                                                        _geminiController.text =
                                                            data.text!.trim();
                                                        Navigator.of(
                                                          context,
                                                        ).pop();
                                                        _autoSaveAfterPaste(
                                                          'Gemini',
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'No text in clipboard',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Clipboard error: $e'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // OpenAI API Key
                        _buildAPIKeyField(
                          label: 'OpenAI API Key',
                          controller: _openAIController,
                          hintText: 'sk-...',
                          validator: (value) {
                            if (value != null &&
                                value.isNotEmpty &&
                                value.trim().isEmpty) {
                              return 'API key cannot be just whitespace';
                            }
                            return null;
                          },
                        ),

                        // Direct manual input option for OpenAI
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 16.0),
                                child: Text(
                                  "Or enter your OpenAI key directly:",
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                decoration: const InputDecoration(
                                  hintText: "Type or paste OpenAI key here...",
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 12.0,
                                  ),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (value) {
                                  // Update the OpenAI controller with the input value
                                  _openAIController.text = value.trim();

                                  // Add a small delay before saving to avoid saving on each keystroke
                                  Future.delayed(
                                    const Duration(milliseconds: 1000),
                                    () {
                                      if (_openAIController.text ==
                                          value.trim()) {
                                        _autoSaveAfterPaste('OpenAI');
                                      }
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Anthropic API Key
                        _buildAPIKeyField(
                          label: 'Anthropic API Key',
                          controller: _anthropicController,
                          hintText: 'sk-ant-...',
                          validator: (value) {
                            if (value != null &&
                                value.isNotEmpty &&
                                value.trim().isEmpty) {
                              return 'API key cannot be just whitespace';
                            }
                            return null;
                          },
                        ),

                        // Direct manual input option for Anthropic
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 16.0),
                                child: Text(
                                  "Or enter your Anthropic key directly:",
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                decoration: const InputDecoration(
                                  hintText:
                                      "Type or paste Anthropic key here...",
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 12.0,
                                  ),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (value) {
                                  _anthropicController.text = value.trim();

                                  // Add a small delay before saving to avoid saving on each keystroke
                                  Future.delayed(
                                    const Duration(milliseconds: 1000),
                                    () {
                                      if (_anthropicController.text ==
                                          value.trim()) {
                                        _autoSaveAfterPaste('Anthropic');
                                      }
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
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

                        // Direct manual input option for Gemini
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 16.0),
                                child: Text(
                                  "Or enter your Gemini key directly:",
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                decoration: const InputDecoration(
                                  hintText: "Type or paste Gemini key here...",
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 12.0,
                                  ),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (value) {
                                  _geminiController.text = value.trim();

                                  // Add a small delay before saving to avoid saving on each keystroke
                                  Future.delayed(
                                    const Duration(milliseconds: 1000),
                                    () {
                                      if (_geminiController.text ==
                                          value.trim()) {
                                        _autoSaveAfterPaste('Gemini');
                                      }
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Advanced settings toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: _toggleShowEndpoints,
                              icon: Icon(
                                _showEndpoints
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              label: Text(
                                _showEndpoints
                                    ? 'Hide Advanced Settings'
                                    : 'Show Advanced Settings',
                              ),
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
                            hintText:
                                'https://api.openai.com/v1/chat/completions',
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
                          child: Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  "API keys are saved automatically after pasting or editing",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _isSavingKeys ? null : _saveAPIKeys,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16.0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                child:
                                    _isSavingKeys
                                        ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Text(
                                          'Manual Save (Not Usually Needed)',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                              ),
                            ],
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ApiKeyTextField(
          controller: controller,
          hintText: hintText,
          validator: validator,
          onPaste: (text) {
            controller.text = text;
            _autoSaveAfterPaste(
              label.split(' ')[0],
            ); // Extract provider name from label
          },
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
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

class ApiKeyTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;
  final Function(String) onPaste;

  const ApiKeyTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.validator,
    required this.onPaste,
  });

  @override
  State<ApiKeyTextField> createState() => _ApiKeyTextFieldState();
}

class _ApiKeyTextFieldState extends State<ApiKeyTextField> {
  bool _obscureText = true;
  String? _lastValue;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _lastValue = widget.controller.text;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (_lastValue != widget.controller.text) {
      _lastValue = widget.controller.text;

      // Cancel existing timer if it exists
      _debounceTimer?.cancel();

      // Set a new timer to auto-save after typing stops
      _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
        widget.onPaste(widget.controller.text);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Simple text field without any fancy wrappers
        TextFormField(
          controller: widget.controller,
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureText ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _obscureText = !_obscureText;
                });
              },
            ),
          ),
          obscureText: _obscureText,
          validator: widget.validator,
        ),
        // Add a dedicated paste button below the field for reliability
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.paste, size: 16),
                label: const Text('Paste Key'),
                onPressed: () async {
                  try {
                    ClipboardData? data = await Clipboard.getData(
                      Clipboard.kTextPlain,
                    );
                    if (data != null && data.text != null) {
                      setState(() {
                        widget.controller.text = data.text!.trim();
                      });
                      widget.onPaste(data.text!);
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Clipboard error: $e')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (widget.controller.text.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                  onPressed: () {
                    setState(() {
                      widget.controller.clear();
                    });
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
