import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Real-time Push Notification Service
/// Handles FCM push notifications, local notifications, and real-time Firestore updates
class RealtimeNotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream controllers for real-time updates
  static final StreamController<Map<String, dynamic>>
      _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Track shown notifications to prevent duplicates
  static final Set<String> _shownNotificationIds = {};

  // Track when the listener was initialized
  static DateTime? _listenerStartTime;

  // Track first load per user session
  static final Map<String, bool> _isFirstLoadPerUser = {};

  // Track current listener subscription
  static StreamSubscription<QuerySnapshot>? _notificationSubscription;

  // Track current user to detect user changes
  static String? _currentUserId;

  // Stream for listening to new notifications
  static Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStreamController.stream;

  // Notification count stream
  static Stream<int> get unreadCountStream {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Initialize the notification service
  static Future<void> initialize() async {
    print('🔔 Initializing Real-time Notification Service...');

    // Mark the initialization time
    _listenerStartTime = DateTime.now();

    // Initialize local notifications
    await _initializeLocalNotifications();
    print('✅ Local notifications initialized');

    // Request permission
    await _requestPermission();
    print('✅ Permission requested');

    // Get and save FCM token
    await _setupFCMToken();
    print('✅ FCM token setup complete');

    // Configure message handlers
    _configureMessageHandlers();
    print('✅ Message handlers configured');

    // Setup Firestore listener for real-time updates
    _setupFirestoreListener();
    print('✅ Firestore listener active');

    print('🎉 Real-time Notification Service ready!');
  }

  /// Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'harvest_notifications',
      'Harvest App Notifications',
      description: 'Real-time notifications for orders, products, and updates',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 76, 175, 80), // Green LED
      showBadge: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(channel);
  }

  /// Request notification permissions
  static Future<void> _requestPermission() async {
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
      print('✅ User granted notification permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('⚠️  User granted provisional permission');
    } else {
      print('❌ User declined notification permission');
    }
  }

  /// Setup FCM token
  static Future<void> _setupFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
        print('📱 FCM Token: $token');
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_saveTokenToFirestore);
    } catch (e) {
      print('❌ Error setting up FCM token: $e');
    }
  }

  /// Save FCM token to Firestore
  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('💾 FCM token saved to Firestore');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  /// Configure message handlers
  static void _configureMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification opened when app was terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);

    // Check for initial message if app was opened from terminated state
    _checkInitialMessage();
  }

  /// Handle foreground messages (app is open)
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 Foreground message received: ${message.messageId}');
    print('   Title: ${message.notification?.title}');
    print('   Body: ${message.notification?.body}');

    // Show local notification
    await _showLocalNotification(message);

    // Broadcast to stream
    _notificationStreamController.add({
      'messageId': message.messageId,
      'title': message.notification?.title,
      'body': message.notification?.body,
      'data': message.data,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Save to Firestore if not already saved
    await _saveNotificationToFirestore(message);
  }

  /// Handle background messages (app is in background)
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    print('📨 Background message received: ${message.messageId}');
    await _saveNotificationToFirestore(message);
  }

  /// Handle notification opened
  static void _handleNotificationOpened(RemoteMessage message) {
    print('🔔 Notification opened: ${message.messageId}');
    print('   Data: ${message.data}');

    // Broadcast to stream with action
    _notificationStreamController.add({
      'messageId': message.messageId,
      'title': message.notification?.title,
      'body': message.notification?.body,
      'data': message.data,
      'action': 'opened',
      'timestamp': DateTime.now().toIso8601String(),
    });

    // You can add navigation logic here based on message.data
    _navigateBasedOnNotification(message);
  }

  /// Check initial message when app opened from terminated state
  static Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('🚀 App opened from notification: ${initialMessage.messageId}');
      _handleNotificationOpened(initialMessage);
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    print('👆 Local notification tapped: ${response.payload}');

    if (response.payload != null) {
      // Parse payload and navigate
      final parts = response.payload!.split('|');
      if (parts.isNotEmpty) {
        _notificationStreamController.add({
          'action': 'tapped',
          'payload': response.payload,
          'parts': parts,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  /// Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final data = message.data;
    final type = data['type'] ?? 'general';

    // Determine notification icon and color based on type
    final notificationDetails = _getNotificationDetails(type);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'harvest_notifications',
      'Harvest App Notifications',
      channelDescription:
          'Real-time notifications for orders, products, and updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 76, 175, 80),
      ledOnMs: 1000,
      ledOffMs: 500,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
      ticker: 'New notification',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: _createPayload(data),
    );

    print('🔔 Local notification shown');
  }

  /// Get notification details based on type
  static Map<String, dynamic> _getNotificationDetails(String type) {
    switch (type) {
      case 'product_approved':
      case 'product_approval':
        return {'icon': '✅', 'color': Colors.green};
      case 'product_rejected':
      case 'product_rejection':
        return {'icon': '❌', 'color': Colors.red};
      case 'checkout_seller':
      case 'checkout_buyer':
        return {'icon': '🛒', 'color': Colors.blue};
      case 'order_status':
      case 'order_update':
        return {'icon': '📦', 'color': Colors.orange};
      case 'seller_approved':
        return {'icon': '🎉', 'color': Colors.green};
      case 'seller_rejected':
        return {'icon': '⚠️', 'color': Colors.red};
      case 'low_stock':
        return {'icon': '⚠️', 'color': Colors.orange};
      default:
        return {'icon': '🔔', 'color': Colors.blue};
    }
  }

  /// Create payload for notification
  static String _createPayload(Map<String, dynamic> data) {
    final type = data['type'] ?? 'general';
    final orderId = data['orderId'] ?? '';
    final productId = data['productId'] ?? '';
    final productName = data['productName'] ?? '';

    return '$type|$orderId|$productId|$productName';
  }

  /// Navigate based on notification
  static void _navigateBasedOnNotification(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';

    // You can implement navigation logic here
    print('📍 Navigation requested for type: $type');
    // Example: Navigate to specific screen based on type
    // Navigator.pushNamed(context, '/route', arguments: data);
  }

  /// Save notification to Firestore
  static Future<void> _saveNotificationToFirestore(
      RemoteMessage message) async {
    try {
      final data = message.data;
      final userId = data['userId'];

      if (userId == null) {
        print('⚠️  No userId in notification data, skipping Firestore save');
        return;
      }

      final notificationData = {
        'userId': userId,
        'title': message.notification?.title ?? 'Notification',
        'message': message.notification?.body ?? '',
        'type': data['type'] ?? 'general',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'messageId': message.messageId,
        'data': data,
      };

      // Check if notification already exists
      final existing = await _firestore
          .collection('notifications')
          .where('messageId', isEqualTo: message.messageId)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        await _firestore.collection('notifications').add(notificationData);
        print('💾 Notification saved to Firestore');
      } else {
        print('ℹ️  Notification already exists in Firestore');
      }
    } catch (e) {
      print('❌ Error saving notification to Firestore: $e');
    }
  }

  /// Setup Firestore listener for real-time notification updates
  static void _setupFirestoreListener() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        // Check if this is a new user
        final isNewUser = _currentUserId != user.uid;

        print('👤 Setting up Firestore listener for user: ${user.uid}');
        print('   Is new user: $isNewUser');

        // If it's a new user, cancel previous subscription and clear data
        if (isNewUser) {
          _notificationSubscription?.cancel();
          _shownNotificationIds.clear();
          _currentUserId = user.uid;
          print('   Cleared previous data for new user');
        }

        // Initialize first load flag for this user if not exists
        if (!_isFirstLoadPerUser.containsKey(user.uid)) {
          _isFirstLoadPerUser[user.uid] = true;
        }

        // Listen to notifications collection for this user
        _notificationSubscription = _firestore
            .collection('notifications')
            .where('userId', isEqualTo: user.uid)
            .where('read', isEqualTo: false)
            .snapshots()
            .listen(
          (snapshot) {
            final isFirstLoad = _isFirstLoadPerUser[user.uid] ?? false;

            print('📨 Snapshot callback triggered');
            print('   Total unread notifications: ${snapshot.docs.length}');
            print('   Document changes: ${snapshot.docChanges.length}');
            print('   Is first load: $isFirstLoad');

            if (snapshot.docChanges.isNotEmpty) {
              for (var change in snapshot.docChanges) {
                if (change.type == DocumentChangeType.added) {
                  final docId = change.doc.id;
                  final data = change.doc.data();

                  if (data != null) {
                    final title = data['title'] ?? 'Notification';
                    final body = data['body'] ?? data['message'] ?? '';

                    print(
                        '🔔 Notification change detected: $title (ID: $docId)');
                    print('   Body: $body');
                    print('   Type: ${data['type']}');
                    print(
                        '   Already shown: ${_shownNotificationIds.contains(docId)}');

                    if (!_shownNotificationIds.contains(docId)) {
                      // Mark as shown IMMEDIATELY to prevent duplicates
                      _shownNotificationIds.add(docId);
                      print(
                          '   Added to shown list. Total shown: ${_shownNotificationIds.length}');

                      // Skip showing floating notifications on first load
                      // Only show for new notifications that arrive after initial load
                      if (!isFirstLoad) {
                        print('✅✅✅ SHOWING FLOATING NOTIFICATION: $title');
                        _showFirestoreNotification(data);
                      } else {
                        print(
                            '⏭️  Skipping floating notification (first load): $title');
                      }

                      // Always broadcast to stream for UI updates
                      _notificationStreamController.add({
                        'source': 'firestore',
                        'id': docId,
                        'data': data,
                        'timestamp': DateTime.now().toIso8601String(),
                      });
                    } else {
                      print('⏩ Notification already processed, skipping');
                    }
                  }
                }
              }
            }

            // ALWAYS mark first load as complete after the first snapshot
            // This happens regardless of whether there were changes or not
            if (isFirstLoad) {
              _isFirstLoadPerUser[user.uid] = false;
              print(
                  '✅✅✅ FIRST LOAD COMPLETE - All future notifications will show as floating');
              print(
                  '   Shown notification IDs count: ${_shownNotificationIds.length}');
            }
          },
          onError: (error) {
            print('❌ Error in Firestore listener: $error');
            print(
                '⚠️  Make sure to create a composite index for notifications collection');
          },
        );
      } else {
        print('⚠️  No user logged in, skipping Firestore listener');
        // Clear shown notifications when user logs out
        _shownNotificationIds.clear();
      }
    });
  }

  /// Show notification from Firestore data
  static Future<void> _showFirestoreNotification(
      Map<String, dynamic> data) async {
    final title = data['title'] ?? 'Notification';
    // Support both 'message' and 'body' fields
    final message = data['body'] ?? data['message'] ?? '';
    final type = data['type'] ?? 'general';

    print('📱 Showing phone notification: $title - $message');

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'harvest_notifications',
      'Harvest App Notifications',
      channelDescription: 'Real-time notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 76, 175, 80),
      ledOnMs: 1000,
      ledOffMs: 500,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      message,
      details,
      payload: _createPayload(data),
    );
  }

  /// Send notification to a specific user
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Save to Firestore
      final notificationData = {
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        ...?additionalData,
      };

      await _firestore.collection('notifications').add(notificationData);
      print('✅ Notification sent to user: $userId');

      // Note: For FCM push notifications, you would call your backend API here
      // to send the actual push notification using the user's FCM token
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  /// Get unread notification count
  static Future<int> getUnreadCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ All notifications marked as read');
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  /// Send a direct test notification (shows immediately without FCM)
  static Future<void> sendTestNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'harvest_notifications',
      'Harvest App Notifications',
      channelDescription: 'Real-time notifications',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 76, 175, 80),
      ledOnMs: 1000,
      ledOffMs: 500,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      ticker: 'New notification',
      fullScreenIntent: true,
      autoCancel: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
      payload: payload,
    );

    print('🔔 Test notification sent: $title');

    // Also save to Firestore for history
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('notifications').add({
          'userId': user.uid,
          'title': title,
          'message': body,
          'type': 'test',
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'payload': payload ?? '',
        });
      }
    } catch (e) {
      print('⚠️  Error saving test notification: $e');
    }
  }

  /// Subscribe to a notification topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a notification topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ Error unsubscribing from topic $topic: $e');
    }
  }

  /// Check if notification permission is granted
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

  /// Get current FCM token
  static Future<String?> getCurrentToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  /// Clear all notifications
  static Future<void> clearAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      print('All notifications cleared');
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    await _notificationStreamController.close();
  }
}
