import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image }

class MessageModel {
  final String messageId;
  final String senderId;
  final String text;
  final MessageType type;
  final String mediaUrl; // image ka URL (agar image message ho)
  final DateTime timestamp;
  final bool seen;

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.text,
    this.type = MessageType.text,
    this.mediaUrl = '',
    required this.timestamp,
    this.seen = false,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      type: (map['type'] == 'image') ? MessageType.image : MessageType.text,
      mediaUrl: map['mediaUrl'] ?? '',
      timestamp:
      (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      seen: map['seen'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'text': text,
      'type': type == MessageType.image ? 'image' : 'text',
      'mediaUrl': mediaUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'seen': seen,
    };
  }
}