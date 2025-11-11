import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/cooperative_chat_screen.dart';

/// Service class to help create and manage cooperative chats
class CooperativeChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Start a chat between a seller and their cooperative
  /// Called from seller screens
  static Future<void> startSellerCooperativeChat({
    required BuildContext context,
    required String cooperativeId,
    required String cooperativeName,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to chat'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Check if there's an existing chat
      final chatQuery = await _firestore
          .collection('cooperative_chats')
          .where('cooperativeId', isEqualTo: cooperativeId)
          .where('userId', isEqualTo: currentUser.uid)
          .where('chatType', isEqualTo: 'seller-cooperative')
          .limit(1)
          .get();

      String chatId;

      if (chatQuery.docs.isEmpty) {
        // Create a new chat
        final chatRef = _firestore.collection('cooperative_chats').doc();
        chatId = chatRef.id;

        await chatRef.set({
          'cooperativeId': cooperativeId,
          'userId': currentUser.uid,
          'chatType': 'seller-cooperative',
          'cooperativeName': cooperativeName,
          'userName': currentUser.displayName ?? currentUser.email ?? 'Seller',
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'lastSenderId': '',
          'unreadUserCount': 0,
          'unreadCooperativeCount': 0,
        });
      } else {
        // Use existing chat
        chatId = chatQuery.docs.first.id;
      }

      // Navigate to chat screen
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CooperativeChatScreen(
              chatId: chatId,
              otherPartyName: cooperativeName,
              cooperativeId: cooperativeId,
              userId: currentUser.uid,
              isCooperative: false,
              chatType: 'seller-cooperative',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Start a chat between a buyer and a cooperative
  /// Called from buyer screens
  static Future<void> startBuyerCooperativeChat({
    required BuildContext context,
    required String cooperativeId,
    required String cooperativeName,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to chat'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Check if there's an existing chat
      final chatQuery = await _firestore
          .collection('cooperative_chats')
          .where('cooperativeId', isEqualTo: cooperativeId)
          .where('userId', isEqualTo: currentUser.uid)
          .where('chatType', isEqualTo: 'buyer-cooperative')
          .limit(1)
          .get();

      String chatId;

      if (chatQuery.docs.isEmpty) {
        // Create a new chat
        final chatRef = _firestore.collection('cooperative_chats').doc();
        chatId = chatRef.id;

        await chatRef.set({
          'cooperativeId': cooperativeId,
          'userId': currentUser.uid,
          'chatType': 'buyer-cooperative',
          'cooperativeName': cooperativeName,
          'userName': currentUser.displayName ?? currentUser.email ?? 'Buyer',
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'lastSenderId': '',
          'unreadUserCount': 0,
          'unreadCooperativeCount': 0,
        });
      } else {
        // Use existing chat
        chatId = chatQuery.docs.first.id;
      }

      // Navigate to chat screen
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CooperativeChatScreen(
              chatId: chatId,
              otherPartyName: cooperativeName,
              cooperativeId: cooperativeId,
              userId: currentUser.uid,
              isCooperative: false,
              chatType: 'buyer-cooperative',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Get cooperative info from seller's profile
  /// Returns cooperativeId and cooperativeName
  static Future<Map<String, String>?> getSellerCooperativeInfo(
      String sellerId) async {
    try {
      final sellerDoc =
          await _firestore.collection('users').doc(sellerId).get();

      if (sellerDoc.exists) {
        final sellerData = sellerDoc.data() as Map<String, dynamic>;
        final cooperativeId = sellerData['cooperativeId'] as String?;

        if (cooperativeId != null) {
          final coopDoc =
              await _firestore.collection('users').doc(cooperativeId).get();

          if (coopDoc.exists) {
            final coopData = coopDoc.data() as Map<String, dynamic>;
            return {
              'cooperativeId': cooperativeId,
              'cooperativeName': coopData['name'] ?? 'Cooperative',
            };
          }
        }
      }
      return null;
    } catch (e) {
      print('Error getting seller cooperative info: $e');
      return null;
    }
  }

  /// Get cooperative info from product's cooperative
  static Future<Map<String, String>?> getProductCooperativeInfo(
      String productId) async {
    try {
      final productDoc =
          await _firestore.collection('products').doc(productId).get();

      if (productDoc.exists) {
        final productData = productDoc.data() as Map<String, dynamic>;
        final cooperativeId = productData['cooperativeId'] as String?;

        if (cooperativeId != null) {
          final coopDoc =
              await _firestore.collection('users').doc(cooperativeId).get();

          if (coopDoc.exists) {
            final coopData = coopDoc.data() as Map<String, dynamic>;
            return {
              'cooperativeId': cooperativeId,
              'cooperativeName': coopData['name'] ?? 'Cooperative',
            };
          }
        }
      }
      return null;
    } catch (e) {
      print('Error getting product cooperative info: $e');
      return null;
    }
  }

  /// Get count of unread cooperative chat messages for current user
  static Stream<int> getUnreadCooperativeMessagesCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(0);
    }

    // Check user role first
    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .asyncMap((userDoc) async {
      if (!userDoc.exists) return 0;

      final userData = userDoc.data() as Map<String, dynamic>;
      final role = userData['role'] as String?;

      if (role == 'cooperative') {
        // For cooperative users, count chats where they have unread messages
        final chatsSnapshot = await _firestore
            .collection('cooperative_chats')
            .where('cooperativeId', isEqualTo: currentUser.uid)
            .where('unreadCooperativeCount', isGreaterThan: 0)
            .get();

        int totalUnread = 0;
        for (var doc in chatsSnapshot.docs) {
          final data = doc.data();
          totalUnread += (data['unreadCooperativeCount'] as int?) ?? 0;
        }
        return totalUnread;
      } else {
        // For sellers/buyers, count their chats where they have unread messages
        final chatsSnapshot = await _firestore
            .collection('cooperative_chats')
            .where('userId', isEqualTo: currentUser.uid)
            .where('unreadUserCount', isGreaterThan: 0)
            .get();

        int totalUnread = 0;
        for (var doc in chatsSnapshot.docs) {
          final data = doc.data();
          totalUnread += (data['unreadUserCount'] as int?) ?? 0;
        }
        return totalUnread;
      }
    });
  }
}
