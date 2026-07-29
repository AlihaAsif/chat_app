import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser!.uid;

  // ---------------- USERS ----------------

  Stream<List<UserModel>> getAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .where((user) => user.uid != currentUserId)
          .toList();
    });
  }

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  Stream<UserModel?> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) return UserModel.fromMap(doc.data()!);
      return null;
    });
  }

  // ---------------- NICKNAMES ----------------

  Future<void> setNickname(String otherUserId, String nickname) async {
    await _firestore.collection('users').doc(currentUserId).set({
      'nicknames': {otherUserId: nickname.trim()},
    }, SetOptions(merge: true));
  }

  Future<void> removeNickname(String otherUserId) async {
    await _firestore.collection('users').doc(currentUserId).update({
      'nicknames.$otherUserId': FieldValue.delete(),
    });
  }

  Future<Map<String, String>> getMyNicknames() async {
    final doc = await _firestore.collection('users').doc(currentUserId).get();
    if (doc.exists) {
      final data = doc.data();
      final nicknames = data?['nicknames'] as Map<String, dynamic>?;
      if (nicknames != null) {
        return nicknames.map((key, value) => MapEntry(key, value.toString()));
      }
    }
    return {};
  }

  Future<String> getDisplayName(String otherUserId, String realName) async {
    final nicknames = await getMyNicknames();
    if (nicknames.containsKey(otherUserId) &&
        nicknames[otherUserId]!.isNotEmpty) {
      return nicknames[otherUserId]!;
    }
    return realName;
  }

  // ---------------- PRESENCE ----------------

  Future<void> setOnline(bool online) async {
    await _firestore.collection('users').doc(currentUserId).set({
      'isOnline': online,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------- NAME UPDATE (apna) ----------------

  Future<void> updateName(String newName) async {
    await _firestore.collection('users').doc(currentUserId).set({
      'name': newName.trim(),
    }, SetOptions(merge: true));
  }

  // ---------------- TYPING ----------------

  Future<void> setTyping(String otherUserId, bool typing) async {
    final chatId = getChatId(otherUserId);
    await _firestore.collection('chats').doc(chatId).set({
      'typing_$currentUserId': typing,
    }, SetOptions(merge: true));
  }

  // ---------------- CHAT ID ----------------

  String getChatId(String otherUserId) {
    final ids = [currentUserId, otherUserId];
    ids.sort();
    return ids.join('_');
  }

  // ---------------- MESSAGES ----------------

  Future<void> sendMessage({
    required String otherUserId,
    required String text,
  }) async {
    final chatId = getChatId(otherUserId);
    final timestamp = DateTime.now();

    final message = MessageModel(
      messageId: '',
      senderId: currentUserId,
      text: text,
      timestamp: timestamp,
    );

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message.toMap());

    await _firestore.collection('chats').doc(chatId).set({
      'chatId': chatId,
      'participants': [currentUserId, otherUserId],
      'lastMessage': text,
      'lastMessageTime': Timestamp.fromDate(timestamp),
      'lastSenderId': currentUserId,
      'seenBy': [currentUserId],
    }, SetOptions(merge: true));
  }

  // Image message
  Future<void> sendImageMessage({
    required String otherUserId,
    required String imageUrl,
  }) async {
    final chatId = getChatId(otherUserId);
    final timestamp = DateTime.now();

    final message = MessageModel(
      messageId: '',
      senderId: currentUserId,
      text: '',
      type: MessageType.image,
      mediaUrl: imageUrl,
      timestamp: timestamp,
    );

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message.toMap());

    await _firestore.collection('chats').doc(chatId).set({
      'chatId': chatId,
      'participants': [currentUserId, otherUserId],
      'lastMessage': '📷 Photo',
      'lastMessageTime': Timestamp.fromDate(timestamp),
      'lastSenderId': currentUserId,
      'seenBy': [currentUserId],
    }, SetOptions(merge: true));
  }

  // Document message
  Future<void> sendDocumentMessage({
    required String otherUserId,
    required String fileUrl,
    required String fileName,
  }) async {
    final chatId = getChatId(otherUserId);
    final timestamp = DateTime.now();

    final message = MessageModel(
      messageId: '',
      senderId: currentUserId,
      text: '',
      type: MessageType.document,
      mediaUrl: fileUrl,
      fileName: fileName,
      timestamp: timestamp,
    );

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message.toMap());

    await _firestore.collection('chats').doc(chatId).set({
      'chatId': chatId,
      'participants': [currentUserId, otherUserId],
      'lastMessage': '📄 Document',
      'lastMessageTime': Timestamp.fromDate(timestamp),
      'lastSenderId': currentUserId,
      'seenBy': [currentUserId],
    }, SetOptions(merge: true));
  }

  Stream<List<MessageModel>> getMessages(String otherUserId) {
    final chatId = getChatId(otherUserId);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['messageId'] = doc.id;
        return MessageModel.fromMap(data);
      }).toList();
    });
  }

  Future<void> deleteMessage({
    required String otherUserId,
    required String messageId,
  }) async {
    final chatId = getChatId(otherUserId);
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> markChatAsSeen(String otherUserId) async {
    final chatId = getChatId(otherUserId);
    await _firestore.collection('chats').doc(chatId).set({
      'seenBy': FieldValue.arrayUnion([currentUserId]),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> getChatDoc(String otherUserId) {
    final chatId = getChatId(otherUserId);
    return _firestore.collection('chats').doc(chatId).snapshots();
  }

  // ---------------- CHAT DELETE / CLEAR ----------------

  Future<void> deleteChat(String otherUserId) async {
    final chatId = getChatId(otherUserId);

    final messagesSnapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    for (final doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    await _firestore.collection('chats').doc(chatId).delete();
  }

  Future<void> clearChat(String otherUserId) async {
    final chatId = getChatId(otherUserId);

    final messagesSnapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    for (final doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    await _firestore.collection('chats').doc(chatId).set({
      'lastMessage': '',
    }, SetOptions(merge: true));
  }

  // ---------------- CHAT LIST ----------------

  Stream<QuerySnapshot> getMyChats() {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }
}