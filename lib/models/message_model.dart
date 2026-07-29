import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, document, voice }

class MessageModel {
  final String messageId;
  final String senderId;
  final String text;
  final MessageType type;
  final String mediaUrl;
  final String fileName;
  final int duration; // voice ki length (seconds)
  final DateTime timestamp;
  final bool seen;

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.text,
    this.type = MessageType.text,
    this.mediaUrl = '',
    this.fileName = '',
    this.duration = 0,
    required this.timestamp,
    this.seen = false,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    MessageType parseType(String? t) {
      if (t == 'image') return MessageType.image;
      if (t == 'document') return MessageType.document;
      if (t == 'voice') return MessageType.voice;
      return MessageType.text;
    }

    return MessageModel(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      type: parseType(map['type']),
      mediaUrl: map['mediaUrl'] ?? '',
      fileName: map['fileName'] ?? '',
      duration: map['duration'] ?? 0,
      timestamp:
      (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      seen: map['seen'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    String typeStr() {
      if (type == MessageType.image) return 'image';
      if (type == MessageType.document) return 'document';
      if (type == MessageType.voice) return 'voice';
      return 'text';
    }

    return {
      'messageId': messageId,
      'senderId': senderId,
      'text': text,
      'type': typeStr(),
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'duration': duration,
      'timestamp': Timestamp.fromDate(timestamp),
      'seen': seen,
    };
  }
}