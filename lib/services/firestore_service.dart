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

  // Messages real-time suno — ab document id bhi laate hain (delete ke liye)
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
        data['messageId'] = doc.id; // document id ko messageId bana do
        return MessageModel.fromMap(data);
      }).toList();
    });
  }

  // Message delete karo
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

  // ---------------- CHAT LIST ----------------

  Stream<QuerySnapshot> getMyChats() {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }
}