import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart' as picker;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../models/message_model.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/chat_background.dart';
import '../profile/user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  Timer? _typingTimer;
  Timer? _recordTimer;
  bool _isTyping = false;
  bool _isUploading = false;
  bool _isRecording = false;
  int _recordDuration = 0;
  String _displayName = '';

  static const Color _teal = Color(0xFF0F766E);

  @override
  void initState() {
    super.initState();
    _displayName = widget.otherUserName;
    _loadDisplayName();
    _firestoreService.markChatAsSeen(widget.otherUserId);
    _messageController.addListener(_onTypingChanged);
  }

  Future<void> _loadDisplayName() async {
    final name = await _firestoreService.getDisplayName(
        widget.otherUserId, widget.otherUserName);
    if (mounted) setState(() => _displayName = name);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _firestoreService.setTyping(widget.otherUserId, false);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTypingChanged() {
    if (_messageController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _firestoreService.setTyping(widget.otherUserId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      _firestoreService.setTyping(widget.otherUserId, false);
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    _isTyping = false;
    _firestoreService.setTyping(widget.otherUserId, false);

    await _firestoreService.sendMessage(
      otherUserId: widget.otherUserId,
      text: text,
    );

    _scrollToBottom();
    setState(() {});
  }

  // ---------------- VOICE RECORDING ----------------

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);

        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordDuration++);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission denied'),
              backgroundColor: Color(0xFFB91C1C),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      _uploadError(e);
    }
  }

  Future<void> _stopAndSendRecording() async {
    try {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();

      final duration = _recordDuration;
      setState(() {
        _isRecording = false;
        _recordDuration = 0;
      });

      if (path == null || duration < 1) return;

      setState(() => _isUploading = true);

      final url = await _storageService.uploadFile(
        file: File(path),
        folder: 'voice',
      );

      if (url == null) {
        _uploadFailed();
        return;
      }

      await _firestoreService.sendVoiceMessage(
        otherUserId: widget.otherUserId,
        voiceUrl: url,
        duration: duration,
      );

      if (mounted) setState(() => _isUploading = false);
      _scrollToBottom();
    } catch (e) {
      _uploadError(e);
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordDuration = 0;
    });
  }

  // ---------------- IMAGE / DOCUMENT ----------------

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (picked == null) return;

      setState(() => _isUploading = true);

      final url = await _storageService.uploadFile(
        file: File(picked.path),
        folder: 'images',
      );

      if (url == null) {
        _uploadFailed();
        return;
      }

      await _firestoreService.sendImageMessage(
        otherUserId: widget.otherUserId,
        imageUrl: url,
      );

      if (mounted) setState(() => _isUploading = false);
      _scrollToBottom();
    } catch (e) {
      _uploadError(e);
    }
  }

  Future<void> _pickAndSendDocument() async {
    try {
      final result = await picker.FilePicker.platform.pickFiles(
        type: picker.FileType.any,
      );
      if (result == null) return;

      final pickedFile = result.files.single;
      if (pickedFile.path == null) return;

      final file = File(pickedFile.path!);
      final fileName = pickedFile.name;

      setState(() => _isUploading = true);

      final url = await _storageService.uploadFile(
        file: file,
        folder: 'docs',
      );

      if (url == null) {
        _uploadFailed();
        return;
      }

      await _firestoreService.sendDocumentMessage(
        otherUserId: widget.otherUserId,
        fileUrl: url,
        fileName: fileName,
      );

      if (mounted) setState(() => _isUploading = false);
      _scrollToBottom();
    } catch (e) {
      _uploadError(e);
    }
  }

  void _uploadFailed() {
    if (mounted) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload failed'),
          backgroundColor: Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _uploadError(Object e) {
    if (mounted) {
      setState(() {
        _isUploading = false;
        _isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: _teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAttachOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Small drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Share content',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 20),

              // Grid of colored options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _attachOption(
                    ctx,
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: const Color(0xFF7C3AED), // purple
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendImage(ImageSource.gallery);
                    },
                  ),
                  _attachOption(
                    ctx,
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: const Color(0xFFEC4899), // pink
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendImage(ImageSource.camera);
                    },
                  ),
                  _attachOption(
                    ctx,
                    icon: Icons.insert_drive_file,
                    label: 'Document',
                    color: const Color(0xFF2563EB), // blue
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendDocument();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Ek attach option (colored circle + label)
  Widget _attachOption(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _openUserProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: widget.otherUserId),
      ),
    );
    _loadDisplayName();
  }

  void _openImageFullScreen(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(imageUrl: url),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open: $e'),
            backgroundColor: const Color(0xFFB91C1C),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showMessageOptions(MessageModel message, bool isMe) {
    if (!isMe) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Color(0xFFB91C1C)),
              title: const Text('Delete message',
                  style: TextStyle(color: Color(0xFFB91C1C))),
              onTap: () async {
                Navigator.pop(ctx);
                await _firestoreService.deleteMessage(
                  otherUserId: widget.otherUserId,
                  messageId: message.messageId,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Color(0xFF6B7280)),
              title: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF6B7280))),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F5),
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: InkWell(
          onTap: _openUserProfile,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                child: Text(
                  Helpers.getInitials(_displayName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    _buildStatusLine(),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () => _showComingSoon('Video call'),
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () => _showComingSoon('Voice call'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ChatBackground(
        child: Column(
          children: [
            Expanded(child: _buildMessagesList()),
            if (_isUploading) _buildUploadingBar(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _teal.withValues(alpha: 0.1),
      child: Row(
        children: const [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: _teal),
          ),
          SizedBox(width: 12),
          Text('Uploading...',
              style: TextStyle(fontSize: 13, color: _teal)),
        ],
      ),
    );
  }

  Widget _buildStatusLine() {
    return StreamBuilder(
      stream: _firestoreService.getUserStream(widget.otherUserId),
      builder: (context, userSnapshot) {
        return StreamBuilder<DocumentSnapshot>(
          stream: _firestoreService.getChatDoc(widget.otherUserId),
          builder: (context, chatSnapshot) {
            bool typing = false;
            if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
              final data =
                  chatSnapshot.data!.data() as Map<String, dynamic>?;
              typing = data?['typing_${widget.otherUserId}'] ?? false;
            }

            final user = userSnapshot.data;
            String text;
            if (typing) {
              text = 'typing...';
            } else if (user?.isOnline ?? false) {
              text = 'online';
            } else {
              text = Helpers.formatLastSeen(false, user?.lastSeen);
            }

            return Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
                fontStyle: typing ? FontStyle.italic : FontStyle.normal,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<List<MessageModel>>(
      stream: _firestoreService.getMessages(widget.otherUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _teal),
          );
        }

        final messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return _buildEmptyChat();
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: _firestoreService.getChatDoc(widget.otherUserId),
          builder: (context, chatSnapshot) {
            bool otherHasSeen = false;
            if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
              final chatData =
                  chatSnapshot.data!.data() as Map<String, dynamic>?;
              final seenBy = List<String>.from(chatData?['seenBy'] ?? []);
              otherHasSeen = seenBy.contains(widget.otherUserId);
            }

            return ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isMe =
                    message.senderId == _firestoreService.currentUserId;

                bool showDateSeparator = false;
                if (index == messages.length - 1) {
                  showDateSeparator = true;
                } else {
                  final olderMessage = messages[index + 1];
                  if (!Helpers.isSameDay(
                      message.timestamp, olderMessage.timestamp)) {
                    showDateSeparator = true;
                  }
                }

                return Column(
                  children: [
                    if (showDateSeparator)
                      _buildDateSeparator(message.timestamp),
                    GestureDetector(
                      onLongPress: () => _showMessageOptions(message, isMe),
                      child: _buildMessageBubble(message, isMe, otherHasSeen),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 52,
                    color: _teal.withValues(alpha: 0.4),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Say hello to start the conversation!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          Helpers.formatDateSeparator(time),
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
      MessageModel message, bool isMe, bool otherHasSeen) {
    final isImage = message.type == MessageType.image;
    final isDocument = message.type == MessageType.document;
    final isVoice = message.type == MessageType.voice;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: isImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? _teal : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isImage)
              GestureDetector(
                onTap: () => _openImageFullScreen(message.mediaUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: message.mediaUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey.withValues(alpha: 0.2),
                      child: const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _teal),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey.withValues(alpha: 0.2),
                      child: const Icon(Icons.broken_image,
                          color: Color(0xFF9CA3AF)),
                    ),
                  ),
                ),
              )
            else if (isDocument)
              GestureDetector(
                onTap: () => _openDocument(message.mediaUrl),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.2)
                            : _teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.insert_drive_file,
                        color: isMe ? Colors.white : _teal,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        message.fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color:
                              isMe ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (isVoice)
              VoiceBubble(
                url: message.mediaUrl,
                duration: message.duration,
                isMe: isMe,
              )
            else
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 15,
                  color: isMe ? Colors.white : const Color(0xFF111827),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(top: 3, right: isImage ? 6 : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Helpers.formatMessageTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? (isImage
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.7))
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      otherHasSeen ? Icons.done_all : Icons.done,
                      size: 14,
                      color: otherHasSeen
                          ? Colors.lightBlueAccent
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    if (_isRecording) {
      return Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Color(0xFFB91C1C)),
                  onPressed: _cancelRecording,
                ),
                const Icon(Icons.mic, color: Color(0xFFB91C1C), size: 20),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_recordDuration),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Recording...',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
                GestureDetector(
                  onTap: _stopAndSendRecording,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F766E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final hasText = _messageController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file, color: _teal),
              onPressed: _isUploading ? null : _showAttachOptions,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 5,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: hasText ? _sendMessage : null,
              onLongPress: hasText ? null : _startRecording,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: _teal,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasText ? Icons.send : Icons.mic,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ---------------- VOICE BUBBLE ----------------

class VoiceBubble extends StatefulWidget {
  final String url;
  final int duration;
  final bool isMe;

  const VoiceBubble({
    super.key,
    required this.url,
    required this.duration,
    required this.isMe,
  });

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  static const Color _teal = Color(0xFF0F766E);

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(UrlSource(widget.url));
      setState(() => _isPlaying = true);
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white : _teal;

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8 - 40,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Icon(
              _isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              color: color,
              size: 36,
            ),
          ),
          const SizedBox(width: 10),
          // Waveform bars
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(24, (index) {
                final heights = [
                  8.0, 14.0, 20.0, 12.0, 24.0, 16.0, 10.0, 18.0,
                  22.0, 14.0, 8.0, 20.0, 26.0, 12.0, 16.0, 22.0,
                  10.0, 18.0, 14.0, 24.0, 8.0, 16.0, 20.0, 12.0,
                ];
                final barColor = _isPlaying 
                    ? color 
                    : color.withValues(alpha: 0.6);
                return Container(
                  width: 3.0,
                  height: heights[index % heights.length],
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatDuration(widget.duration),
            style: TextStyle(
              fontSize: 12,
              color: widget.isMe ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}