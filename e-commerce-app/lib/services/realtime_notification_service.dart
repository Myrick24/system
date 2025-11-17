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

  // Track shown FCM messages to prevent duplicate local notifications
  static final Set<String> _shownFCMMessageIds = {};

  // Track when the listener was initialized
  static DateTime? _listenerStartTime;

  // Track first load per user session
  static final Map<String, bool> _isFirstLoadPerUser = {};

  // Track current listener subscription
  static StreamSubscription<QuerySnapshot>? _notificationSubscription;

  // Track current user to detect user changes
  static String? _currentUserId;

  // Track if service is initialized to prevent re-initialization
  static bool _isInitialized = false;

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
    // Prevent re-initialization
    if (_isInitialized) {
      print('ℹ️  Notification service already initialized, skipping...');
      return;
    }

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

    _isInitialized = true;
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
        print('📱 FCM Token obtained: ${token.substring(0, 20)}...');
        // Only save if user is logged in
        final user = _auth.currentUser;
        if (user != null) {
          await _saveTokenToFirestore(token);
        } else {
          print('⚠️ No user logged in, skipping token save');
        }
      }

      // Listen for token refresh - will check user status before saving
      _firebaseMessaging.onTokenRefresh.listen(_saveTokenToFirestore);
    } catch (e) {
      print('❌ Error setting up FCM token: $e');
    }
  }

  /// Save FCM token to Firestore
  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ Cannot save FCM token: No user logged in');
        return;
      }

      print('💾 Saving FCM token for user: ${user.uid}');
      print('   Token: ${token.substring(0, 20)}...');

      // CRITICAL: Remove this exact token from ALL other users in Firestore
      // This prevents old logged-out accounts from receiving notifications
      try {
        final usersWithToken = await _firestore
            .collection('users')
            .where('fcmToken', isEqualTo: token)
            .get();

        print('🔍 Found ${usersWithToken.docs.length} users with this token');

        // Use a batch write for atomic operation
        final batch = _firestore.batch();
        int removedCount = 0;

        for (final doc in usersWithToken.docs) {
          if (doc.id != user.uid) {
            batch.update(doc.reference, {
              'fcmToken': FieldValue.delete(),
              'tokenRemovedAt': FieldValue.serverTimestamp(),
            });
            removedCount++;
            print('🗑️ Queued token removal from user: ${doc.id}');
          }
        }

        if (removedCount > 0) {
          await batch.commit();
          print('✅ Removed token from $removedCount other user(s)');
        }
      } catch (queryError) {
        print('⚠️ Error checking for duplicate tokens: $queryError');
      }

      // Now save token to current user
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('✅ FCM token saved to Firestore for user: ${user.uid}');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  /// Configure message handlers
  static void _configureMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Note: Background message handler is configured in main.dart as a top-level function
    // This is required by Firebase Cloud Messaging

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

    // Check if we already showed this message to prevent duplicates
    final messageId =
        message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();
    if (_shownFCMMessageIds.contains(messageId)) {
      print('⏩ Message already shown, skipping duplicate');
      return;
    }

    // Mark as shown
    _shownFCMMessageIds.add(messageId);

    // Clean up old message IDs (keep last 100)
    if (_shownFCMMessageIds.length > 100) {
      final toRemove = _shownFCMMessageIds.length - 100;
      _shownFCMMessageIds.removeAll(_shownFCMMessageIds.take(toRemove));
    }

    // Always show notification when app is open (foreground)
    // This ensures users see notifications whether app is open or closed
    await _showLocalNotification(message);
    print('✅ Foreground notification displayed');

    // Broadcast to stream for UI updates
    _notificationStreamController.add({
      'messageId': message.messageId,
      'title': message.notification?.title,
      'body': message.notification?.body,
      'data': message.data,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Note: No need to save to Firestore here - Cloud Functions already do this
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

    // Determine notification icon and color based on type
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

    // Use timestamp-based unique ID to avoid collisions
    final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;

    await _localNotifications.show(
      notificationId,
      notification.title,
      notification.body,
      details,
      payload: _createPayload(data),
    );

    print('🔔 Local notification shown (ID: $notificationId)');
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

                      // Clean up old notification IDs periodically
                      _cleanupShownNotifications();

                      // Skip showing floating notifications on first load
                      // Only show for new notifications that arrive after initial load
                      // NOTE: We DON'T show local notifications here because FCM already handles it
                      // This prevents duplicate notifications
                      if (!isFirstLoad) {
                        print(
                            '📨 New notification detected: $title (FCM will handle display)');
                      } else {
                        print('⏭️  Skipping notification (first load): $title');
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
    await _notificationSubscription?.cancel();
    _isInitialized = false;
  }

  /// Clear FCM token when user logs out
  static Future<void> clearFCMToken() async {
    try {
      final currentToken = await _firebaseMessaging.getToken();
      if (currentToken != null) {
        print(
            '🗑️ Deleting FCM token from device: ${currentToken.substring(0, 20)}...');
        // Delete the FCM token from the device
        await _firebaseMessaging.deleteToken();
        print('✅ FCM token deleted from device successfully');
      } else {
        print('ℹ️ No FCM token found on device to delete');
      }

      // Reset initialization flag so service can be re-initialized on next login
      _isInitialized = false;
      _currentUserId = null;

      // Cancel existing listeners
      await _notificationSubscription?.cancel();
      _notificationSubscription = null;

      print('✅ Notification service reset for logout');
    } catch (e) {
      print('⚠️ Error clearing FCM token: $e');
    }
  }

  /// Refresh FCM token after login - call this after user signs in
  static Future<void> refreshTokenAfterLogin() async {
    try {
      print('🔄 Refreshing FCM token after login...');
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No user logged in, cannot refresh token');
        return;
      }

      print('👤 Current user: ${user.uid}');

      // Delete old token from device to force a new one
      await _firebaseMessaging.deleteToken();
      print('🗑️ Old token deleted from device');

      // Wait a bit for the deletion to propagate
      await Future.delayed(const Duration(milliseconds: 500));

      // Get new token
      String? newToken = await _firebaseMessaging.getToken();

      if (newToken != null) {
        print('📱 New FCM token obtained: ${newToken.substring(0, 20)}...');
        await _saveTokenToFirestore(newToken);

        // Reinitialize Firestore listener for new user
        await _notificationSubscription?.cancel();
        _setupFirestoreListener();
        print('✅ Token refresh complete for user: ${user.uid}');
      } else {
        print('⚠️ Failed to obtain new FCM token');
      }
    } catch (e) {
      print('❌ Error refreshing FCM token: $e');
    }
  }

  /// Clean up old shown notification IDs to prevent memory leak
  /// Keeps only the last 100 notification IDs in memory
  static void _cleanupShownNotifications() {
    if (_shownNotificationIds.length > 100) {
      final idsToRemove = _shownNotificationIds.length - 100;
      final iterator = _shownNotificationIds.iterator;
      for (var i = 0; i < idsToRemove && iterator.moveNext(); i++) {
        // Remove the oldest IDs
      }
      // Keep only the last 100
      final lastHundred = _shownNotificationIds
          .skip(_shownNotificationIds.length - 100)
          .toSet();
      _shownNotificationIds.clear();
      _shownNotificationIds.addAll(lastHundred);
      print('🧹 Cleaned up old notification IDs, keeping last 100');
    }
  }
}
