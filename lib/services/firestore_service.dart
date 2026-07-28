import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser!.uid;

  // ---------------- USERS ----------------

  // Saare users fetch karo (apne aap ko chhod ke) — new chat ke liye
  Stream<List<UserModel>> getAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .where((user) => user.uid != currentUserId)
          .toList();
    });
  }

  // Ek user ka data lao (uid se)
  Future<UserModel?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  // ---------------- CHAT ID ----------------

  // Do users ke beech unique chatId banao (hamesha same order)
  String getChatId(String otherUserId) {
    final ids = [currentUserId, otherUserId];
    ids.sort();
    return ids.join('_');
  }

  // ---------------- MESSAGES ----------------

  // Message bhejo
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

    // 1. Message ko subcollection mein add karo
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message.toMap());

    // 2. Chat document update karo (last message + participants + sender + seen)
    await _firestore.collection('chats').doc(chatId).set({
      'chatId': chatId,
      'participants': [currentUserId, otherUserId],
      'lastMessage': text,
      'lastMessageTime': Timestamp.fromDate(timestamp),
      'lastSenderId': currentUserId, // kisne bheja
      'seenBy': [currentUserId], // sender ne to dekha hi hai
    }, SetOptions(merge: true));
  }

  // Ek chat ke messages real-time suno (naye niche)
  Stream<List<MessageModel>> getMessages(String otherUserId) {
    final chatId = getChatId(otherUserId);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data()))
          .toList();
    });
  }

  // Chat ko "seen" mark karo (jab user chat kholta hai)
  Future<void> markChatAsSeen(String otherUserId) async {
    final chatId = getChatId(otherUserId);
    await _firestore.collection('chats').doc(chatId).set({
      'seenBy': FieldValue.arrayUnion([currentUserId]),
    }, SetOptions(merge: true));
  }

  // ---------------- CHAT LIST (Home screen) ----------------

  // Meri saari chats real-time (recent upar)
  Stream<QuerySnapshot> getMyChats() {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }
}