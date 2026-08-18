import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/llama_model_manager.dart';
import '../../services/llama_chat_service.dart';

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage(this.text, this.isUser);

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
      };

  factory _ChatMessage.fromJson(Map<String, dynamic> json) =>
      _ChatMessage(json['text'] as String, json['isUser'] as bool);
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  static const Color _teal = Color(0xFF0F766E);

  final _modelManager = LlamaModelManager();
  final _chatService = LlamaChatService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];

  bool _modelReady = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isGenerating = false;
  bool _downloadFailed = false;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _prepareModel();
  }

  String _getChatKey() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'guest';
    return 'ai_chat_history_$uid';
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getChatKey();
      final history = prefs.getStringList(key);
      if (history != null && history.isNotEmpty) {
        final loadedMessages = history.map((item) {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          return _ChatMessage.fromJson(decoded);
        }).toList();
        setState(() {
          _messages.addAll(loadedMessages);
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Failed to load chat history: $e');
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getChatKey();
      final history = _messages.map((msg) => jsonEncode(msg.toJson())).toList();
      await prefs.setStringList(key, history);
    } catch (e) {
      debugPrint('Failed to save chat history: $e');
    }
  }

  Future<void> _clearChatHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat?'),
        content: const Text('Are you sure you want to clear the AI assistant chat history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _messages.clear();
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = _getChatKey();
        await prefs.remove(key);
      } catch (e) {
        debugPrint('Failed to clear chat history: $e');
      }
    }
  }

  Future<void> _prepareModel() async {
    if (mounted) {
      setState(() {
        _isDownloading = true;
        _downloadFailed = false;
        _downloadError = null;
        _downloadProgress = 0.0;
      });
    }

    final alreadyThere = await _modelManager.isModelDownloaded();

    if (!alreadyThere) {
      try {
        await _modelManager.downloadModel(
          onProgress: (p) {
            if (mounted) setState(() => _downloadProgress = p);
          },
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _downloadFailed = true;
            _downloadError = e.toString();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: $e')),
          );
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isDownloading = false;
        _downloadFailed = false;
        _downloadError = null;
        _modelReady = true;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isGenerating) return;

    setState(() {
      _messages.add(_ChatMessage(text, true));
      _messages.add(_ChatMessage('', false)); // Placeholder for AI reply
      _isGenerating = true;
    });
    _messageController.clear();
    _scrollToBottom();
    _saveChatHistory();

    try {
      await _chatService.sendMessage(
        text,
        onToken: (partial) {
          if (mounted) {
            setState(() {
              _messages[_messages.length - 1] = _ChatMessage(partial, false);
            });
            _scrollToBottom();
          }
        },
      );
    } catch (e) {
      setState(() {
        _messages[_messages.length - 1] =
            _ChatMessage('Something went wrong. ($e)', false);
      });
    } finally {
      _saveChatHistory();
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'AI Assistant',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear Chat',
              onPressed: _clearChatHistory,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: !_modelReady
                ? _buildLoadingState()
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) =>
                            _buildBubble(_messages[index]),
                      ),
          ),
          if (_modelReady) _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_downloadFailed) ...[
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to load model',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _downloadError ?? 'Unknown error occurred.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Download'),
                onPressed: _prepareModel,
              ),
            ] else if (_isDownloading) ...[
              const Text(
                'Downloading AI model...',
                style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 280,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : 0.0,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.lerp(Colors.grey.shade400, Colors.green, _downloadProgress.clamp(0.0, 1.0)) ?? Colors.grey,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'One-time download',
                          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              const CircularProgressIndicator(color: _teal),
              const SizedBox(height: 16),
              const Text('Getting ready...'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.smart_toy_outlined,
                size: 52, color: _teal.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text(
              'Chat with your AI Assistant',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fully offline — no internet required',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(_ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: msg.isUser ? _teal : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          msg.text.isEmpty ? '...' : msg.text,
          style: TextStyle(
            color: msg.isUser ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  enabled: !_isGenerating,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: _teal,
              child: IconButton(
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _isGenerating ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}