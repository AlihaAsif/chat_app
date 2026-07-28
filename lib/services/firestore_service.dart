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
          .where((user) => user.uid != currentUserId) // khud ko hatao
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

  // Do users ke beech unique chatId banao (hamesha same order mein)
  String getChatId(String otherUserId) {
    final ids = [currentUserId, otherUserId];
    ids.sort(); // sort karne se dono taraf same id banti hai
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
      messageId: '', // Firestore khud id dega
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

    // 2. Chat document update karo (last message + participants)
    await _firestore.collection('chats').doc(chatId).set({
      'chatId': chatId,
      'participants': [currentUserId, otherUserId],
      'lastMessage': text,
      'lastMessageTime': Timestamp.fromDate(timestamp),
    }, SetOptions(merge: true)); // merge = purana data na mite
  }

  // Ek chat ke messages real-time suno (naye niche)
  Stream<List<MessageModel>> getMessages(String otherUserId) {
    final chatId = getChatId(otherUserId);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true) // naye pehle (list reverse hogi)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data()))
          .toList();
    });
  }

  // ---------------- CHAT LIST (Home screen) ----------------

  // Meri saari chats real-time (recent upar) — home screen ke liye
  Stream<QuerySnapshot> getMyChats() {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true) // recent chat upar
        .snapshots();
  }
}