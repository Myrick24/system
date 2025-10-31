import 'realtime_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  orderUpdate,
  newProduct,
  productApproval,
  payment,
  general,
  announcement,
  reminder,
  checkout,
  sellerRegistration,
  productUpdate,
}

class NotificationManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Send direct local test notification (bypasses FCM for immediate system notification)
  static Future<bool> sendDirectTestNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: title,
        body: body,
        payload: payload,
      );
      return true;
    } catch (e) {
      print('Error sending direct test notification: $e');
      return false;
    }
  }

  // Send order update notification
  static Future<bool> sendOrderUpdateNotification({
    required String userId,
    required String orderId,
    required String status,
    String? customerName,
  }) async {
    String title = '📦 Order Update';
    String body = 'Your order #$orderId has been updated to: $status';

    if (customerName != null) {
      body = 'Order #$orderId from $customerName has been updated to: $status';
    }

    // Use direct local notification for immediate floating popup
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: title,
        body: body,
        payload: 'order_update|$orderId|$status',
      );
      return true;
    } catch (e) {
      print('Error sending order update notification: $e');
      return false;
    }
  }

  // Send new product notification to buyers
  static Future<bool> sendNewProductNotification({
    required String productId,
    required String productName,
    required String sellerName,
    String? category,
  }) async {
    String title = '🆕 New Product Available';
    String body = '$sellerName has added a new product: $productName';

    if (category != null) {
      body += ' in $category category';
    }

    // Use direct local notification for immediate floating popup
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: title,
        body: body,
        payload: 'new_product|$productId|$sellerName',
      );
      return true;
    } catch (e) {
      print('Error sending new product notification: $e');
      return false;
    }
  }

  // Send product approval notification to seller
  static Future<bool> sendProductApprovalNotification({
    required String sellerId,
    required String productName,
    required bool isApproved,
    String? rejectionReason,
  }) async {
    String title = isApproved ? '✅ Product Approved' : '❌ Product Rejected';
    String body = isApproved
        ? 'Your product "$productName" has been approved and is now live!'
        : 'Your product "$productName" has been rejected.';

    if (!isApproved && rejectionReason != null) {
      body += ' Reason: $rejectionReason';
    }

    // Use direct local notification for immediate floating popup
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: title,
        body: body,
        payload: 'product_approval|$productName|$isApproved',
      );
      return true;
    } catch (e) {
      print('Error sending product approval notification: $e');
      return false;
    }
  }

  // Send payment notification
  static Future<bool> sendPaymentNotification({
    required String userId,
    required String orderId,
    required double amount,
    required bool isReceived,
  }) async {
    String title = isReceived ? '💰 Payment Received' : '💳 Payment Sent';
    String body = isReceived
        ? 'You received a payment of ₱${amount.toStringAsFixed(2)} for order #$orderId'
        : 'Payment of ₱${amount.toStringAsFixed(2)} sent for order #$orderId';

    // Use direct local notification for immediate floating popup
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: title,
        body: body,
        payload: 'payment|$orderId|$amount|$isReceived',
      );
      return true;
    } catch (e) {
      print('Error sending payment notification: $e');
      return false;
    }
  }

  // Send low stock notification to seller
  static Future<bool> sendLowStockNotification({
    required String sellerId,
    required String productName,
    required int currentStock,
    int threshold = 5,
  }) async {
    String title = '⚠️ Low Stock Alert';
    String body =
        'Your product "$productName" is running low (only $currentStock left)';

    // Use direct local notification for immediate floating popup
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: title,
        body: body,
        payload: 'low_stock|$productName|$currentStock',
      );
      return true;
    } catch (e) {
      print('Error sending low stock notification: $e');
      return false;
    }
  }

  // Send welcome notification to new users
  static Future<bool> sendWelcomeNotification({
    required String userId,
    required String userName,
    required String userRole,
  }) async {
    String title = '👋 Welcome to Harvest App!';
    String body = 'Hi $userName! Welcome to our farming marketplace.';

    switch (userRole) {
      case 'farmer':
        body += ' Start selling your fresh produce today!';
        break;
      case 'buyer':
        body += ' Discover fresh produce from local farmers!';
        break;
      case 'cooperative':
        body += ' Connect farmers with buyers in your area!';
        break;
    }

    // Use direct local notification for immediate floating popup
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: title,
        body: body,
        payload: 'welcome|$userName|$userRole',
      );
      return true;
    } catch (e) {
      print('Error sending welcome notification: $e');
      return false;
    }
  }

  // Send reminder notification
  static Future<bool> sendReminderNotification({
    required String userId,
    required String reminderType,
    required String message,
  }) async {
    String title = '⏰ Reminder';

    // Use direct local notification for immediate floating popup
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: title,
        body: message,
        payload: 'reminder|$reminderType',
      );
      return true;
    } catch (e) {
      print('Error sending reminder notification: $e');
      return false;
    }
  }

  // Send announcement to all users
  static Future<bool> sendAnnouncement({
    required String title,
    required String message,
    String? targetRole, // null means all users
  }) async {
    String notificationTitle = '📢 $title';

    // Use direct local notification for immediate floating popup
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: notificationTitle,
        body: message,
        payload: 'announcement|$title|${targetRole ?? "all"}',
      );
      return true;
    } catch (e) {
      print('Error sending announcement: $e');
      return false;
    }
  }

  // Send seasonal/farming tip notification
  static Future<bool> sendFarmingTip({
    required String tip,
    String? season,
  }) async {
    String title = season != null ? '🌱 $season Farming Tip' : '🌱 Farming Tip';

    // Use direct local notification for immediate floating popup
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: title,
        body: tip,
        payload: 'farming_tip|${season ?? "general"}',
      );
      return true;
    } catch (e) {
      print('Error sending farming tip: $e');
      return false;
    }
  }

  // Send market price update notification
  static Future<bool> sendMarketPriceUpdate({
    required String productName,
    required double newPrice,
    required double oldPrice,
  }) async {
    String title = '📈 Market Price Update';
    double changePercent = ((newPrice - oldPrice) / oldPrice) * 100;
    String changeDirection = changePercent > 0 ? 'increased' : 'decreased';

    String body =
        '$productName price has $changeDirection by ${changePercent.abs().toStringAsFixed(1)}% to ₱${newPrice.toStringAsFixed(2)}';

    // Use direct local notification for immediate floating popup
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: title,
        body: body,
        payload: 'market_price|$productName|$newPrice|$oldPrice',
      );
      return true;
    } catch (e) {
      print('Error sending market price update: $e');
      return false;
    }
  }

  // Subscribe user to relevant notification topics based on their role
  static Future<void> subscribeToRoleBasedTopics(String userRole) async {
    await RealtimeNotificationService.subscribeToTopic('all_users');
    await RealtimeNotificationService.subscribeToTopic(userRole);

    switch (userRole) {
      case 'farmer':
        await RealtimeNotificationService.subscribeToTopic('farmers');
        await RealtimeNotificationService.subscribeToTopic('market_updates');
        await RealtimeNotificationService.subscribeToTopic('farming_tips');
        break;
      case 'buyer':
        await RealtimeNotificationService.subscribeToTopic('buyers');
        await RealtimeNotificationService.subscribeToTopic('new_products');
        await RealtimeNotificationService.subscribeToTopic('deals');
        break;
      case 'cooperative':
        await RealtimeNotificationService.subscribeToTopic('cooperatives');
        await RealtimeNotificationService.subscribeToTopic('admin_updates');
        break;
    }
  }

  // Unsubscribe from topics when user changes role or logs out
  static Future<void> unsubscribeFromAllTopics() async {
    final topics = [
      'all_users',
      'farmer',
      'buyer',
      'cooperative',
      'farmers',
      'buyers',
      'cooperatives',
      'market_updates',
      'farming_tips',
      'new_products',
      'deals',
      'admin_updates',
    ];

    for (String topic in topics) {
      await RealtimeNotificationService.unsubscribeFromTopic(topic);
    }
  }

  // ===== NEW NOTIFICATION METHODS =====

  // Send checkout notification to seller when buyer purchases their product
  static Future<bool> sendCheckoutNotificationToSeller({
    required String sellerId,
    required String productName,
    required int quantity,
    required String unit,
    required double totalAmount,
    required String buyerName,
    required String orderId,
  }) async {
    String title = '🛒 New Purchase!';
    String body = '$buyerName just purchased $quantity $unit of "$productName" (₱${totalAmount.toStringAsFixed(2)})';

    // Send push notification
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: title,
        body: body,
        payload: 'checkout|seller|$orderId|$productName',
      );

      // Store notification in Firestore for seller
      await _firestore.collection('notifications').add({
        'userId': sellerId,
        'title': title,
        'message': body,
        'type': 'checkout_seller',
        'orderId': orderId,
        'productName': productName,
        'quantity': quantity,
        'totalAmount': totalAmount,
        'buyerName': buyerName,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'priority': 'high',
      });

      return true;
    } catch (e) {
      print('Error sending checkout notification to seller: $e');
      return false;
    }
  }

  // Send checkout confirmation to buyer
  static Future<bool> sendCheckoutConfirmationToBuyer({
    required String buyerId,
    required String productName,
    required int quantity,
    required String unit,
    required double totalAmount,
    required String orderId,
  }) async {
    String title = '✅ Order Confirmed!';
    String body = 'Your order for $quantity $unit of "$productName" has been confirmed (₱${totalAmount.toStringAsFixed(2)})';

    // Send push notification
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: title,
        body: body,
        payload: 'checkout|buyer|$orderId|$productName',
      );

      // Store notification in Firestore for buyer
      await _firestore.collection('notifications').add({
        'userId': buyerId,
        'title': title,
        'message': body,
        'type': 'checkout_buyer',
        'orderId': orderId,
        'productName': productName,
        'quantity': quantity,
        'totalAmount': totalAmount,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'priority': 'high',
      });

      return true;
    } catch (e) {
      print('Error sending checkout confirmation to buyer: $e');
      return false;
    }
  }

  // Send seller registration approval notification
  static Future<bool> sendSellerRegistrationNotification({
    required String userId,
    required String userName,
    required bool isApproved,
    String? rejectionReason,
  }) async {
    String title = isApproved ? '🎉 Seller Account Approved!' : '❌ Seller Application Rejected';
    String body = isApproved
        ? 'Congratulations $userName! Your seller account has been approved. You can now start selling products.'
        : 'Your seller application has been rejected.';

    if (!isApproved && rejectionReason != null) {
      body += ' Reason: $rejectionReason';
    }

    // Send push notification
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: title,
        body: body,
        payload: 'seller_registration|$isApproved',
      );

      // Store notification in Firestore
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': body,
        'type': isApproved ? 'seller_approved' : 'seller_rejected',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'priority': 'high',
      });

      return true;
    } catch (e) {
      print('Error sending seller registration notification: $e');
      return false;
    }
  }

  // Send product update notification to buyers (when existing product is updated)
  static Future<bool> sendProductUpdateNotification({
    required String productId,
    required String productName,
    required String sellerName,
    required String updateType, // 'price', 'stock', 'details'
    String? updateDetails,
  }) async {
    String title = '📝 Product Updated';
    String body = '$sellerName updated "$productName"';

    if (updateDetails != null) {
      body += ' - $updateDetails';
    }

    // Send push notification
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: title,
        body: body,
        payload: 'product_update|$productId|$updateType',
      );

      // Store notification in Firestore for all buyers (or targeted buyers)
      // Note: In a real app, you might want to only notify buyers who favorited/purchased this product
      await _firestore.collection('product_updates').add({
        'productId': productId,
        'productName': productName,
        'sellerName': sellerName,
        'updateType': updateType,
        'updateDetails': updateDetails,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error sending product update notification: $e');
      return false;
    }
  }

  // Send notification when another seller adds a new product (notify all sellers)
  static Future<bool> sendNewProductToSellers({
    required String productId,
    required String productName,
    required String sellerName,
    required String category,
    String? excludeSellerId, // Don't notify the seller who added the product
  }) async {
    String title = '🆕 New Product Added';
    String body = '$sellerName added "$productName" in $category category';

    // Send push notification
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: title,
        body: body,
        payload: 'new_product_seller|$productId|$category',
      );

      // Store notification in Firestore for sellers
      await _firestore.collection('seller_market_updates').add({
        'productId': productId,
        'productName': productName,
        'sellerName': sellerName,
        'category': category,
        'excludeSellerId': excludeSellerId,
        'type': 'new_product_market',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error sending new product notification to sellers: $e');
      return false;
    }
  }

  // Send notification to all buyers about new product
  static Future<bool> sendNewProductToBuyers({
    required String productId,
    required String productName,
    required String sellerName,
    required String category,
    double? price,
  }) async {
    String title = '🎁 New Product Available!';
    String body = 'Check out "$productName" from $sellerName in $category';
    
    if (price != null) {
      body += ' - ₱${price.toStringAsFixed(2)}';
    }

    // Send push notification
    try {
      await RealtimeNotificationService.sendTestNotification(
        title: title,
        body: body,
        payload: 'new_product_buyer|$productId|$category',
      );

      // Get all buyers and send individual notifications
      final usersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'buyer')
          .get();

      // Create individual notifications for each buyer
      final batch = _firestore.batch();
      for (var userDoc in usersSnapshot.docs) {
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': userDoc.id,
          'title': title,
          'message': body,
          'type': 'new_product_buyer',
          'productId': productId,
          'productName': productName,
          'sellerName': sellerName,
          'category': category,
          'price': price,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'priority': 'normal',
        });
      }
      
      // Commit all notifications at once
      await batch.commit();
      
      print('Sent new product notification to ${usersSnapshot.docs.length} buyers');

      return true;
    } catch (e) {
      print('Error sending new product notification to buyers: $e');
      return false;
    }
  }

  // Create a general notification record in Firestore
  static Future<bool> createNotificationRecord({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
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
      return true;
    } catch (e) {
      print('Error creating notification record: $e');
      return false;
    }
  }
}
