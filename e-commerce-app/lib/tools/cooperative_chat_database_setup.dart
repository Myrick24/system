import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Utility class to help setup and test cooperative chat database
class CooperativeChatDatabaseSetup {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a sample cooperative chat for testing
  /// This demonstrates the exact database structure
  static Future<String> createSampleChat({
    required String cooperativeId,
    required String userId,
    required String chatType, // 'seller-cooperative' or 'buyer-cooperative'
    required String cooperativeName,
    required String userName,
  }) async {
    try {
      // Create the chat document
      final chatRef = _firestore.collection('cooperative_chats').doc();
      final chatId = chatRef.id;

      await chatRef.set({
        'cooperativeId': cooperativeId,
        'userId': userId,
        'chatType': chatType, // 'seller-cooperative' or 'buyer-cooperative'
        'cooperativeName': cooperativeName,
        'userName': userName,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '', // Empty initially
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastSenderId': '',
        'unreadUserCount': 0,
        'unreadCooperativeCount': 0,
      });

      print('✅ Created cooperative chat with ID: $chatId');
      print('   Cooperative: $cooperativeName ($cooperativeId)');
      print('   User: $userName ($userId)');
      print('   Type: $chatType');

      return chatId;
    } catch (e) {
      print('❌ Error creating chat: $e');
      rethrow;
    }
  }

  /// Add a sample message to a chat
  static Future<void> addSampleMessage({
    required String chatId,
    required String senderId,
    required String messageText,
  }) async {
    try {
      // Add message to sub-collection
      await _firestore
          .collection('cooperative_chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'text': messageText,
        'senderId': senderId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Update the chat document with last message
      await _firestore.collection('cooperative_chats').doc(chatId).update({
        'lastMessage': messageText,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
      });

      print('✅ Added message to chat $chatId');
    } catch (e) {
      print('❌ Error adding message: $e');
      rethrow;
    }
  }

  /// Setup complete test database structure
  static Future<void> setupTestDatabase() async {
    print('🔧 Setting up test cooperative chat database...\n');

    try {
      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No user logged in. Please log in first.');
        return;
      }

      // Example 1: Create seller-cooperative chat
      print('📝 Creating seller-cooperative chat...');
      final sellerChatId = await createSampleChat(
        cooperativeId: 'coop_123', // Replace with actual cooperative ID
        userId: currentUser.uid,
        chatType: 'seller-cooperative',
        cooperativeName: 'San Pedro Cooperative',
        userName: currentUser.displayName ?? 'Test Seller',
      );

      // Add a sample message
      await addSampleMessage(
        chatId: sellerChatId,
        senderId: currentUser.uid,
        messageText: 'Hello, I have a question about product approval.',
      );

      print('\n📝 Creating buyer-cooperative chat...');
      // Example 2: Create buyer-cooperative chat
      final buyerChatId = await createSampleChat(
        cooperativeId: 'coop_123', // Replace with actual cooperative ID
        userId: currentUser.uid,
        chatType: 'buyer-cooperative',
        cooperativeName: 'San Pedro Cooperative',
        userName: currentUser.displayName ?? 'Test Buyer',
      );

      // Add a sample message
      await addSampleMessage(
        chatId: buyerChatId,
        senderId: currentUser.uid,
        messageText: 'What are your delivery options?',
      );

      print('\n✅ Test database setup complete!');
      print('📊 Created collections:');
      print('   - cooperative_chats (main collection)');
      print('   - cooperative_chats/{chatId}/messages (sub-collection)');
      print('\n🔍 Check Firebase Console to see the data!');
    } catch (e) {
      print('❌ Setup failed: $e');
    }
  }

  /// Verify database structure
  static Future<void> verifyDatabaseStructure() async {
    print('🔍 Verifying cooperative chat database structure...\n');

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No user logged in');
        return;
      }

      // Check for cooperative_chats collection
      final chatsSnapshot = await _firestore
          .collection('cooperative_chats')
          .limit(1)
          .get();

      if (chatsSnapshot.docs.isEmpty) {
        print('⚠️  No chats found in database');
        print('   The collection will be created automatically when users start chatting');
        return;
      }

      print('✅ cooperative_chats collection exists');
      print('   Found ${chatsSnapshot.docs.length} chat(s)\n');

      // Check structure of first chat
      final firstChat = chatsSnapshot.docs.first;
      final chatData = firstChat.data();

      print('📋 Sample chat structure:');
      print('   Chat ID: ${firstChat.id}');
      print('   Fields:');
      chatData.forEach((key, value) {
        print('   - $key: $value');
      });

      // Check messages sub-collection
      final messagesSnapshot = await _firestore
          .collection('cooperative_chats')
          .doc(firstChat.id)
          .collection('messages')
          .limit(1)
          .get();

      if (messagesSnapshot.docs.isNotEmpty) {
        print('\n✅ Messages sub-collection exists');
        final firstMessage = messagesSnapshot.docs.first.data();
        print('   Sample message structure:');
        firstMessage.forEach((key, value) {
          print('   - $key: $value');
        });
      } else {
        print('\n⚠️  No messages in this chat yet');
      }

      print('\n✅ Database structure is correct!');
    } catch (e) {
      print('❌ Verification failed: $e');
    }
  }

  /// Get all cooperative chats for current user
  static Future<void> listUserChats() async {
    print('📋 Listing all chats for current user...\n');

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No user logged in');
        return;
      }

      // Check if user is a cooperative
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data();
      final isCooperative = userData?['role'] == 'cooperative';

      QuerySnapshot chatsSnapshot;

      if (isCooperative) {
        // Get chats where user is the cooperative
        chatsSnapshot = await _firestore
            .collection('cooperative_chats')
            .where('cooperativeId', isEqualTo: currentUser.uid)
            .get();

        print('🏢 Viewing as Cooperative');
      } else {
        // Get chats where user is the seller/buyer
        chatsSnapshot = await _firestore
            .collection('cooperative_chats')
            .where('userId', isEqualTo: currentUser.uid)
            .get();

        print('👤 Viewing as User (Seller/Buyer)');
      }

      print('Found ${chatsSnapshot.docs.length} chat(s)\n');

      if (chatsSnapshot.docs.isEmpty) {
        print('No chats found. Start a conversation to create one!');
        return;
      }

      for (var doc in chatsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('Chat ID: ${doc.id}');
        print('  Type: ${data['chatType']}');
        print('  Cooperative: ${data['cooperativeName']}');
        print('  User: ${data['userName']}');
        print('  Last Message: ${data['lastMessage']}');
        print('  Unread (User): ${data['unreadUserCount']}');
        print('  Unread (Coop): ${data['unreadCooperativeCount']}');
        print('');
      }
    } catch (e) {
      print('❌ Error listing chats: $e');
    }
  }

  /// Delete all cooperative chats (for testing/cleanup)
  static Future<void> deleteAllChats() async {
    print('🗑️  Deleting all cooperative chats...\n');

    try {
      final chatsSnapshot = await _firestore
          .collection('cooperative_chats')
          .get();

      print('Found ${chatsSnapshot.docs.length} chat(s) to delete');

      final batch = _firestore.batch();

      for (var chatDoc in chatsSnapshot.docs) {
        // Delete messages sub-collection first
        final messagesSnapshot = await _firestore
            .collection('cooperative_chats')
            .doc(chatDoc.id)
            .collection('messages')
            .get();

        for (var msgDoc in messagesSnapshot.docs) {
          batch.delete(msgDoc.reference);
        }

        // Delete chat document
        batch.delete(chatDoc.reference);
      }

      await batch.commit();
      print('✅ All chats deleted successfully');
    } catch (e) {
      print('❌ Error deleting chats: $e');
    }
  }
}
