import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize push notifications
  static Future<void> initialize() async {
    // Initialize local notifications first
    await _initializeLocalNotifications();

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

  // Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'harvest_app_channel',
      'Harvest App Notifications',
      description: 'Notifications for the Harvest App',
      importance: Importance.max, // Maximum importance for system notifications
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color.fromARGB(255, 0, 255, 0), // Green LED
      showBadge: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // You can add navigation logic here based on the payload
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

    // Show local notification when app is in foreground
    await _showLocalNotification(message);

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

  // Send a simple test notification that uses local notifications for immediate display
  static Future<void> sendTestNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Show immediate local notification for testing - this will create real system notifications
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'harvest_app_channel',
      'Harvest App Notifications',
      channelDescription: 'Notifications for the Harvest App',
      importance: Importance.max, // Changed to max for system notifications
      priority: Priority.max, // Changed to max for system notifications
      icon: '@mipmap/ic_launcher',
      showWhen: true,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true, // Added for full screen notifications
      autoCancel: true, // Added to auto-cancel when tapped
      ongoing: false, // Ensure it's dismissible
      setAsGroupSummary: false,
      groupKey: 'harvest_notifications',
      enableLights: true,
      ledColor: const Color.fromARGB(255, 255, 0, 0),
      ledOnMs: 1000,
      ledOffMs: 500,
      ticker: title, // Shows title in status bar
    );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    // Also simulate saving to user's notification history
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .add({
          'title': title,
          'body': body,
          'payload': payload ?? '',
          'type': 'test',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (e) {
      print('Error saving test notification: $e');
    }
  }

  // Clear all notifications for current user
  static Future<void> clearAllNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Get all user notifications
        QuerySnapshot notifications = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .get();

        // Delete all notifications in a batch
        WriteBatch batch = _firestore.batch();
        for (DocumentSnapshot doc in notifications.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        print('Cleared all notifications for user: ${user.uid}');
      }
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }

  // Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'harvest_app_channel',
      'Harvest App Notifications',
      channelDescription: 'Notifications for the Harvest App',
      importance: Importance.max, // Maximum importance for system notifications
      priority: Priority.max, // Maximum priority for system notifications
      icon: '@mipmap/ic_launcher',
      showWhen: true,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true, // Enable full screen notifications
      autoCancel: true, // Auto-cancel when tapped
      ongoing: false, // Ensure it's dismissible
      setAsGroupSummary: false,
      groupKey: 'harvest_notifications',
      enableLights: true,
      ledColor: const Color.fromARGB(255, 0, 255, 0), // Green LED
      ledOnMs: 1000,
      ledOffMs: 500,
      ticker: message.notification?.title, // Shows in status bar
    );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      message.notification?.title ?? 'Harvest App',
      message.notification?.body ?? 'You have a new notification',
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  // ===== NEW ENHANCED NOTIFICATION FUNCTIONS =====

  /// Send order update notification with rich formatting
  static Future<void> sendOrderUpdateNotification({
    required String userId,
    required String orderId,
    required String status,
    String? customerName,
    double? totalAmount,
  }) async {
    String title = '📦 Order Update';
    String body = 'Order #$orderId: $status';

    if (customerName != null) {
      body = '$customerName\'s order #$orderId: $status';
    }
    if (totalAmount != null) {
      body += ' (₱${totalAmount.toStringAsFixed(2)})';
    }

    await sendTestNotification(
      title: title,
      body: body,
      payload: 'order_update|$orderId|$status',
    );

    // Save to Firestore
    await _saveNotificationToFirestore(
      userId: userId,
      title: title,
      message: body,
      type: 'order_update',
      data: {
        'orderId': orderId,
        'status': status,
        'customerName': customerName,
        'totalAmount': totalAmount,
      },
    );
  }

  /// Send new product notification
  static Future<void> sendNewProductNotification({
    required String productId,
    required String productName,
    required String sellerName,
    String? category,
    double? price,
  }) async {
    String title = '🆕 New Product Available';
    String body = '$sellerName added "$productName"';

    if (category != null) {
      body += ' in $category';
    }
    if (price != null) {
      body += ' - ₱${price.toStringAsFixed(2)}';
    }

    await sendTestNotification(
      title: title,
      body: body,
      payload: 'new_product|$productId',
    );
  }

  /// Send product approval notification to seller
  static Future<void> sendProductApprovalNotification({
    required String sellerId,
    required String productName,
    required bool isApproved,
    String? rejectionReason,
  }) async {
    String title = isApproved ? '✅ Product Approved' : '❌ Product Rejected';
    String body = isApproved
        ? '"$productName" is now live!'
        : '"$productName" was rejected';

    if (!isApproved && rejectionReason != null) {
      body += ' - $rejectionReason';
    }

    await sendTestNotification(
      title: title,
      body: body,
      payload: 'product_approval|$productName|$isApproved',
    );

    await _saveNotificationToFirestore(
      userId: sellerId,
      title: title,
      message: body,
      type: isApproved ? 'product_approved' : 'product_rejected',
      data: {
        'productName': productName,
        'isApproved': isApproved,
        'rejectionReason': rejectionReason,
      },
    );
  }

  /// Send payment notification
  static Future<void> sendPaymentNotification({
    required String userId,
    required String orderId,
    required double amount,
    required bool isReceived,
    String? paymentMethod,
  }) async {
    String title = isReceived ? '💰 Payment Received' : '💳 Payment Sent';
    String body = isReceived
        ? 'Received ₱${amount.toStringAsFixed(2)} for order #$orderId'
        : 'Paid ₱${amount.toStringAsFixed(2)} for order #$orderId';

    if (paymentMethod != null) {
      body += ' via $paymentMethod';
    }

    await sendTestNotification(
      title: title,
      body: body,
      payload: 'payment|$orderId|$amount',
    );

    await _saveNotificationToFirestore(
      userId: userId,
      title: title,
      message: body,
      type: isReceived ? 'payment_received' : 'payment_sent',
      data: {
        'orderId': orderId,
        'amount': amount,
        'paymentMethod': paymentMethod,
      },
    );
  }

  /// Send low stock alert to seller
  static Future<void> sendLowStockNotification({
    required String sellerId,
    required String productId,
    required String productName,
    required int currentStock,
    int threshold = 5,
  }) async {
    String title = '⚠️ Low Stock Alert';
    String body = '"$productName" has only $currentStock units left!';

    await sendTestNotification(
      title: title,
      body: body,
      payload: 'low_stock|$productId|$currentStock',
    );

    await _saveNotificationToFirestore(
      userId: sellerId,
      title: title,
      message: body,
      type: 'low_stock',
      data: {
        'productId': productId,
        'productName': productName,
        'currentStock': currentStock,
        'threshold': threshold,
      },
      priority: 'high',
    );
  }

  /// Send welcome notification to new users
  static Future<void> sendWelcomeNotification({
    required String userId,
    required String userName,
    required String userRole,
  }) async {
    String title = '👋 Welcome to Harvest App!';
    String body = 'Hi $userName! ';

    switch (userRole) {
      case 'farmer':
      case 'seller':
        body += 'Start selling your fresh produce today!';
        break;
      case 'buyer':
        body += 'Discover fresh produce from local farmers!';
        break;
      case 'cooperative':
        body += 'Manage your cooperative efficiently!';
        break;
      default:
        body += 'Welcome aboard!';
    }

    await sendTestNotification(
      title: title,
      body: body,
      payload: 'welcome|$userRole',
    );

    await _saveNotificationToFirestore(
      userId: userId,
      title: title,
      message: body,
      type: 'welcome',
      data: {'userName': userName, 'userRole': userRole},
    );
  }

  /// Send checkout notification to seller
  static Future<void> sendCheckoutNotificationToSeller({
    required String sellerId,
    required String orderId,
    required String productName,
    required int quantity,
    required String unit,
    required double totalAmount,
    required String buyerName,
  }) async {
    String title = '🛒 New Purchase!';
    String body = '$buyerName bought $quantity $unit of "$productName" (₱${totalAmount.toStringAsFixed(2)})';

    await sendTestNotification(
      title: title,
      body: body,
      payload: 'checkout_seller|$orderId',
    );

    await _saveNotificationToFirestore(
      userId: sellerId,
      title: title,
      message: body,
      type: 'checkout_seller',
      data: {
        'orderId': orderId,
        'productName': productName,
        'quantity': quantity,
        'unit': unit,
        'totalAmount': totalAmount,
        'buyerName': buyerName,
      },
      priority: 'high',
    );
  }

  /// Send checkout confirmation to buyer
  static Future<void> sendCheckoutConfirmationToBuyer({
    required String buyerId,
    required String orderId,
    required String productName,
    required int quantity,
    required String unit,
    required double totalAmount,
    String? sellerName,
  }) async {
    String title = '✅ Order Confirmed!';
    String body = 'Your order for $quantity $unit of "$productName" (₱${totalAmount.toStringAsFixed(2)})';
    
    if (sellerName != null) {
      body += ' from $sellerName';
    }

    await sendTestNotification(
      title: title,
      body: body,
      payload: 'checkout_buyer|$orderId',
    );

    await _saveNotificationToFirestore(
      userId: buyerId,
      title: title,
      message: body,
      type: 'checkout_buyer',
      data: {
        'orderId': orderId,
        'productName': productName,
        'quantity': quantity,
        'unit': unit,
        'totalAmount': totalAmount,
        'sellerName': sellerName,
      },
      priority: 'high',
    );
  }

  /// Send seller registration approval notification
  static Future<void> sendSellerRegistrationNotification({
    required String userId,
    required String userName,
    required bool isApproved,
    String? rejectionReason,
  }) async {
    String title = isApproved 
        ? '🎉 Seller Account Approved!' 
        : '❌ Seller Application Rejected';
    
    String body = isApproved
        ? 'Congratulations $userName! You can now start selling.'
        : 'Your seller application was rejected';

    if (!isApproved && rejectionReason != null) {
      body += ' - $rejectionReason';
    }

    await sendTestNotification(
      title: title,
      body: body,
      payload: 'seller_registration|$isApproved',
    );

    await _saveNotificationToFirestore(
      userId: userId,
      title: title,
      message: body,
      type: isApproved ? 'seller_approved' : 'seller_rejected',
      data: {
        'userName': userName,
        'isApproved': isApproved,
        'rejectionReason': rejectionReason,
      },
      priority: 'high',
    );
  }

  /// Send product update notification
  static Future<void> sendProductUpdateNotification({
    required String productId,
    required String productName,
    required String sellerName,
    required String updateType,
    String? updateDetails,
  }) async {
    String title = '📝 Product Updated';
    String body = '$sellerName updated "$productName"';

    if (updateDetails != null) {
      body += ' - $updateDetails';
    }

    await sendTestNotification(
      title: title,
      body: body,
      payload: 'product_update|$productId|$updateType',
    );
  }

  /// Send announcement notification
  static Future<void> sendAnnouncementNotification({
    required String title,
    required String message,
    String? targetRole,
  }) async {
    await sendTestNotification(
      title: '📢 $title',
      body: message,
      payload: 'announcement|${targetRole ?? "all"}',
    );
  }

  /// Send farming tip notification
  static Future<void> sendFarmingTipNotification({
    required String tip,
    String? season,
  }) async {
    String title = season != null ? '🌱 $season Farming Tip' : '🌱 Farming Tip';

    await sendTestNotification(
      title: title,
      body: tip,
      payload: 'farming_tip|${season ?? "general"}',
    );
  }

  /// Send market price update notification
  static Future<void> sendMarketPriceUpdateNotification({
    required String productName,
    required double newPrice,
    required double oldPrice,
  }) async {
    double changePercent = ((newPrice - oldPrice) / oldPrice) * 100;
    String changeDirection = changePercent > 0 ? 'increased' : 'decreased';
    String emoji = changePercent > 0 ? '📈' : '📉';

    String title = '$emoji Market Price Update';
    String body = '$productName $changeDirection by ${changePercent.abs().toStringAsFixed(1)}% to ₱${newPrice.toStringAsFixed(2)}';

    await sendTestNotification(
      title: title,
      body: body,
      payload: 'market_price|$productName|$newPrice',
    );
  }

  /// Send reminder notification
  static Future<void> sendReminderNotification({
    required String userId,
    required String reminderType,
    required String message,
  }) async {
    await sendTestNotification(
      title: '⏰ Reminder',
      body: message,
      payload: 'reminder|$reminderType',
    );

    await _saveNotificationToFirestore(
      userId: userId,
      title: '⏰ Reminder',
      message: message,
      type: 'reminder',
      data: {'reminderType': reminderType},
    );
  }

  /// Send delivery status notification
  static Future<void> sendDeliveryStatusNotification({
    required String userId,
    required String orderId,
    required String status,
    String? estimatedTime,
  }) async {
    String title = '🚚 Delivery Update';
    String body = 'Order #$orderId: $status';

    if (estimatedTime != null) {
      body += ' - ETA: $estimatedTime';
    }

    await sendTestNotification(
      title: title,
      body: body,
      payload: 'delivery|$orderId|$status',
    );

    await _saveNotificationToFirestore(
      userId: userId,
      title: title,
      message: body,
      type: 'delivery_status',
      data: {
        'orderId': orderId,
        'status': status,
        'estimatedTime': estimatedTime,
      },
    );
  }

  /// Send review request notification
  static Future<void> sendReviewRequestNotification({
    required String userId,
    required String orderId,
    required String productName,
  }) async {
    String title = '⭐ How was your purchase?';
    String body = 'Please rate your experience with "$productName"';

    await sendTestNotification(
      title: title,
      body: body,
      payload: 'review_request|$orderId',
    );

    await _saveNotificationToFirestore(
      userId: userId,
      title: title,
      message: body,
      type: 'review_request',
      data: {
        'orderId': orderId,
        'productName': productName,
      },
    );
  }

  /// Send new review notification to seller
  static Future<void> sendNewReviewNotification({
    required String sellerId,
    required String productName,
    required int rating,
    String? reviewerName,
  }) async {
    String stars = '⭐' * rating;
    String title = '⭐ New Review';
    String body = '${reviewerName ?? "A buyer"} rated "$productName" $stars';

    await sendTestNotification(
      title: title,
      body: body,
      payload: 'new_review|$productName|$rating',
    );

    await _saveNotificationToFirestore(
      userId: sellerId,
      title: title,
      message: body,
      type: 'new_review',
      data: {
        'productName': productName,
        'rating': rating,
        'reviewerName': reviewerName,
      },
    );
  }

  /// Send bulk notification to multiple users
  static Future<void> sendBulkNotification({
    required List<String> userIds,
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    for (String userId in userIds) {
      await _saveNotificationToFirestore(
        userId: userId,
        title: title,
        message: body,
        type: type ?? 'general',
        data: data,
      );
    }

    // Also send one local notification as a sample
    await sendTestNotification(
      title: title,
      body: body,
      payload: 'bulk|${type ?? "general"}',
    );
  }

  /// Helper method to save notification to Firestore
  static Future<void> _saveNotificationToFirestore({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
    String priority = 'normal',
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'priority': priority,
        'data': data ?? {},
      });
    } catch (e) {
      print('Error saving notification to Firestore: $e');
    }
  }

  /// Get unread notification count
  static Future<int> getUnreadNotificationCount(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for a user
  static Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      WriteBatch batch = _firestore.batch();
      for (DocumentSnapshot doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  /// Delete a notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Get user's notification history
  static Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Schedule a notification for later
  static Future<void> scheduleNotification({
    required String userId,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('scheduled_notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type ?? 'scheduled',
        'scheduledTime': Timestamp.fromDate(scheduledTime),
        'sent': false,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }
}
