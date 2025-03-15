import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/chat_provider.dart';
import '../models/chat.dart';
import '../router/app_navigation.dart';
import 'dart:developer' as developer;

// Use conditional imports
import 'web_utils.dart'
    if (dart.library.io) 'mobile_utils.dart'
    as platform_utils;

// For non-web platforms
import 'dart:io' as io;

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  final TextEditingController _importController = TextEditingController();

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _showExportDialog() async {
    setState(() {
      _isExporting = true;
    });

    try {
      // Get chat history JSON
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final exportJson = await chatProvider.exportChatHistory();

      // Show dialog with the JSON
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Export Chat History'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose how to export your chat history:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    // Save to file button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              if (kIsWeb) {
                                // Web handling - use download API
                                platform_utils.saveFileOnWeb(
                                  exportJson,
                                  'chat_history_${DateTime.now().millisecondsSinceEpoch}.json',
                                );
                                Navigator.pop(context);
                              } else {
                                // Native platforms (mobile/desktop)
                                String?
                                outputFile = await FilePicker.platform.saveFile(
                                  dialogTitle: 'Save Chat History',
                                  fileName:
                                      'chat_history_${DateTime.now().millisecondsSinceEpoch}.json',
                                  type: FileType.custom,
                                  allowedExtensions: ['json'],
                                );

                                if (outputFile != null) {
                                  // Save the file
                                  final file = io.File(outputFile);
                                  await file.writeAsString(exportJson);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Saved to ${file.path}'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );

                                  Navigator.pop(context);
                                }
                              }
                            } catch (e) {
                              developer.log('Error saving file: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error saving file: ${e.toString()}',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Save to File'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    // Copy to clipboard button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: exportJson));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy to Clipboard'),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      developer.log('Error in export dialog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  void _showImportDialog() {
    _importController.clear();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Import Chat History'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose a method to import your chat history:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            FilePickerResult? result = await FilePicker.platform
                                .pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['json'],
                                  dialogTitle: 'Select JSON Chat History File',
                                );

                            if (result != null) {
                              String jsonData;

                              if (kIsWeb) {
                                // Web handling - read bytes directly
                                final bytes = result.files.single.bytes;
                                if (bytes != null) {
                                  jsonData = utf8.decode(bytes);
                                } else {
                                  throw Exception(
                                    'Unable to read file content',
                                  );
                                }
                              } else {
                                // Native platforms (mobile/desktop)
                                String? filePath = result.files.single.path;
                                if (filePath != null) {
                                  final file = io.File(filePath);

                                  // Show loading indicator
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Reading file...'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );

                                  jsonData = await file.readAsString();
                                } else {
                                  throw Exception('File path is null');
                                }
                              }

                              Navigator.pop(context);
                              _processImport(jsonData);
                            }
                          } catch (e) {
                            developer.log('Error picking file: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error selecting file: ${e.toString()}',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.file_upload),
                        label: const Text('Upload JSON File'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Or paste your exported chat history below:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _importController,
                    decoration: const InputDecoration(
                      hintText: 'Paste JSON data here',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 8,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Note: The JSON should contain chat history in the same format as exported from this app.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_importController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please paste valid JSON data'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  _processImport(_importController.text);
                },
                child: const Text('Import'),
              ),
            ],
          ),
    );
  }

  Future<void> _processImport(String jsonData) async {
    setState(() {
      _isImporting = true;
    });

    try {
      // Basic validation
      final data = jsonDecode(jsonData);
      if (!data.containsKey('chats') || data['chats'] is! List) {
        throw FormatException('Invalid chat history format');
      }

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final success = await chatProvider.importChatHistory(jsonData);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat history imported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to import chat history'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      developer.log('Error processing import: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid data format: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  Future<void> _confirmClearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Chat History'),
            content: const Text(
              'Are you sure you want to clear all chat history? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Clear All'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      await chatProvider.clearChatHistory();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat history cleared')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat History'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isExporting ? null : _showExportDialog,
                  icon:
                      _isExporting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.download),
                  label: const Text('Export History'),
                ),
                ElevatedButton.icon(
                  onPressed: _isImporting ? null : _showImportDialog,
                  icon:
                      _isImporting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.upload),
                  label: const Text('Import History'),
                ),
                ElevatedButton.icon(
                  onPressed: _confirmClearHistory,
                  icon: const Icon(Icons.delete),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.errorContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  label: const Text('Clear All'),
                ),
              ],
            ),
          ),

          const Divider(),

          // Chat history list
          Expanded(
            child:
                chatProvider.chatMetadata.isEmpty
                    ? const Center(child: Text('No chat history'))
                    : ListView.builder(
                      itemCount: chatProvider.chatMetadata.length,
                      itemBuilder: (context, index) {
                        final metadata = chatProvider.chatMetadata[index];
                        final isActive =
                            chatProvider.activeChat?.id == metadata.id;

                        return ListTile(
                          title: Text(
                            metadata.title,
                            style: TextStyle(
                              fontWeight:
                                  isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '${metadata.provider.name} - ${metadata.model} • ${metadata.messageCount} messages • ${_formatDate(metadata.updatedAt)}',
                          ),
                          leading: Icon(
                            _getProviderIcon(metadata.provider),
                            color:
                                isActive
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                          ),
                          selected: isActive,
                          onTap: () {
                            AppNavigation.toChat(metadata.id);
                            Navigator.pop(context);
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed:
                                () => chatProvider.deleteChat(metadata.id),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  IconData _getProviderIcon(AIProvider provider) {
    switch (provider) {
      case AIProvider.openai:
        return Icons.lightbulb_outline;
      case AIProvider.anthropic:
        return Icons.psychology;
      case AIProvider.gemini:
        return Icons.auto_awesome;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
