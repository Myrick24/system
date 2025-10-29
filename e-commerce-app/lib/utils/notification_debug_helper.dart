import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Helper class to debug and test notifications
class NotificationDebugHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if there are any notifications for the current user
  static Future<void> checkNotifications() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    print('✅ Checking notifications for user: ${user.email} (${user.uid})');

    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();

      print('📊 Total notifications found: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        print('⚠️  No notifications found for this user');
        print('');
        print('Troubleshooting steps:');
        print('1. Check if notifications are being created in Firestore');
        print('2. Verify the userId field matches: ${user.uid}');
        print('3. Check Firestore rules allow read access');
        print('4. Try creating a test notification');
      } else {
        print('');
        print('📝 Notifications breakdown:');
        
        final byType = <String, int>{};
        final byRead = {'read': 0, 'unread': 0};
        
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final type = data['type'] ?? 'unknown';
          final isRead = data['read'] ?? data['isRead'] ?? false;
          
          byType[type] = (byType[type] ?? 0) + 1;
          if (isRead) {
            byRead['read'] = byRead['read']! + 1;
          } else {
            byRead['unread'] = byRead['unread']! + 1;
          }
          
          print('  - ID: ${doc.id}');
          print('    Type: $type');
          print('    Title: ${data['title'] ?? 'N/A'}');
          print('    Message: ${data['message'] ?? 'N/A'}');
          print('    Read: $isRead');
          print('    Timestamp: ${data['timestamp'] ?? data['createdAt'] ?? 'N/A'}');
          print('');
        }
        
        print('By Type:');
        byType.forEach((type, count) {
          print('  $type: $count');
        });
        print('');
        print('By Read Status:');
        print('  Read: ${byRead['read']}');
        print('  Unread: ${byRead['unread']}');
      }
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      print('');
      print('Common causes:');
      print('1. Firestore rules may be blocking read access');
      print('2. Network connection issues');
      print('3. Index not created (if using complex queries)');
    }
  }

  /// Create a test notification for the current user
  static Future<void> createTestNotification({
    String type = 'test',
    String title = 'Test Notification',
    String message = 'This is a test notification',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    try {
      final docRef = await _firestore.collection('notifications').add({
        'userId': user.uid,
        'type': type,
        'title': title,
        'message': message,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Test notification created successfully!');
      print('   ID: ${docRef.id}');
      print('   User: ${user.email}');
      print('   Type: $type');
    } catch (e) {
      print('❌ Error creating test notification: $e');
    }
  }

  /// Get user role and info
  static Future<void> checkUserInfo() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    print('👤 User Information:');
    print('   UID: ${user.uid}');
    print('   Email: ${user.email}');
    print('   Display Name: ${user.displayName ?? 'N/A'}');

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        print('   Role: ${userData?['role'] ?? 'N/A'}');
        print('   Seller Status: ${userData?['sellerStatus'] ?? 'N/A'}');
      } else {
        print('   ⚠️  User document not found in Firestore');
      }
    } catch (e) {
      print('   ❌ Error fetching user data: $e');
    }
  }

  /// List all notification types in the system
  static Future<void> listAllNotificationTypes() async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .limit(1000)
          .get();

      final types = <String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        types.add(data['type'] ?? 'unknown');
      }

      print('📋 All notification types in system:');
      for (var type in types) {
        print('  - $type');
      }
    } catch (e) {
      print('❌ Error listing notification types: $e');
    }
  }

  /// Run all debug checks
  static Future<void> runAllChecks() async {
    print('🔍 Running Notification Debug Checks');
    print('=' * 50);
    print('');
    
    await checkUserInfo();
    print('');
    print('=' * 50);
    print('');
    
    await checkNotifications();
    print('');
    print('=' * 50);
    print('');
    
    await listAllNotificationTypes();
    print('');
    print('=' * 50);
  }
}
