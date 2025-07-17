import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize push notifications
  static Future<void> initialize() async {
    // Request permission for notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission for notifications');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('User granted provisional permission for notifications');
    } else {
      print('User declined or has not accepted permission for notifications');
    }

    // Get FCM token
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
      print('FCM Token: $token');
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToFirestore);

    // Configure message handlers
    _configureMessageHandlers();
  }

  // Save FCM token to Firestore
  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Configure message handlers
  static void _configureMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    // Handle notification opened when app is terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);
  }

  // Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.messageId}');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');

    // Save notification to local storage
    await _saveNotificationLocally(message);
  }

  // Handle background messages
  @pragma('vm:entry-point')
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Received background message: ${message.messageId}');

    // Save notification to local storage
    await _saveNotificationLocally(message);
  }

  // Handle notification opened
  static Future<void> _handleNotificationOpened(RemoteMessage message) async {
    print('Notification opened: ${message.messageId}');

    // Navigate to appropriate screen based on notification data
    await _navigateBasedOnNotification(message);
  }

  // Save notification locally
  static Future<void> _saveNotificationLocally(RemoteMessage message) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Save to user's notifications collection
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add({
        'id': message.messageId,
        'title': message.notification?.title ?? 'Notification',
        'body': message.notification?.body ?? '',
        'data': message.data,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': message.data['type'] ?? 'general',
      });

      // Also save to global notifications collection
      await _firestore.collection('notifications').add({
        'id': message.messageId,
        'userId': user.uid,
        'title': message.notification?.title ?? 'Notification',
        'body': message.notification?.body ?? '',
        'data': message.data,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': message.data['type'] ?? 'general',
      });
    } catch (e) {
      print('Error saving notification locally: $e');
    }
  }

  // Navigate based on notification
  static Future<void> _navigateBasedOnNotification(
      RemoteMessage message) async {
    // Implementation depends on your navigation setup
    // You can add navigation logic here based on message.data
    print('Navigate based on notification: ${message.data}');
  }

  // Send notification to specific user
  static Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        print('User document not found');
        return false;
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String? fcmToken = userData['fcmToken'];

      if (fcmToken == null) {
        print('User does not have FCM token');
        return false;
      }

      // Create notification data
      Map<String, String> notificationData = {
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'userId': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      if (data != null) {
        data.forEach((key, value) {
          notificationData[key] = value.toString();
        });
      }

      // Save notification to Firestore (will trigger FCM via server-side function)
      await _firestore.collection('fcm_messages').add({
        'to': fcmToken,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': notificationData,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error sending notification: $e');
      return false;
    }
  }

  // Send notification to role-based topic
  static Future<bool> sendNotificationToRole({
    required String role,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      Map<String, String> notificationData = {
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'role': role,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      if (data != null) {
        data.forEach((key, value) {
          notificationData[key] = value.toString();
        });
      }

      // Save notification for topic (will trigger FCM via server-side function)
      await _firestore.collection('fcm_topic_messages').add({
        'topic': role,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': notificationData,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error sending role notification: $e');
      return false;
    }
  }

  // Subscribe to role-based topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  // Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }

  // Get current FCM token
  static Future<String?> getCurrentToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  // Check if notifications are enabled
  static Future<bool> hasPermission() async {
    try {
      NotificationSettings settings =
          await _firebaseMessaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      print('Error checking notification permission: $e');
      return false;
    }
  }

  // Send a simple test notification that uses FCM's system notification display
  static Future<void> sendTestNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Send to current user using FCM
        await sendNotificationToUser(
          userId: user.uid,
          title: title,
          body: body,
          data: {'payload': payload ?? '', 'type': 'test'},
        );
      }
    } catch (e) {
      print('Error sending test notification: $e');
    }
  }
}
