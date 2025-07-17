import 'push_notification_service.dart';

enum NotificationType {
  orderUpdate,
  newProduct,
  productApproval,
  payment,
  general,
  announcement,
  reminder,
}

class NotificationManager {
  // Send direct local test notification (bypasses FCM for immediate system notification)
  static Future<bool> sendDirectTestNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await PushNotificationService.sendTestNotification(
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
      await PushNotificationService.sendTestNotification(
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
      await PushNotificationService.sendTestNotification(
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
      await PushNotificationService.sendTestNotification(
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
        ? 'You received a payment of \$${amount.toStringAsFixed(2)} for order #$orderId'
        : 'Payment of \$${amount.toStringAsFixed(2)} sent for order #$orderId';

    // Use direct local notification for immediate floating popup
    try {
      await PushNotificationService.sendTestNotification(
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
      await PushNotificationService.sendTestNotification(
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
      await PushNotificationService.sendTestNotification(
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
      await PushNotificationService.sendTestNotification(
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
      await PushNotificationService.sendTestNotification(
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
      await PushNotificationService.sendTestNotification(
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
        '$productName price has $changeDirection by ${changePercent.abs().toStringAsFixed(1)}% to \$${newPrice.toStringAsFixed(2)}';

    // Use direct local notification for immediate floating popup
    try {
      await PushNotificationService.sendTestNotification(
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
    await PushNotificationService.subscribeToTopic('all_users');
    await PushNotificationService.subscribeToTopic(userRole);

    switch (userRole) {
      case 'farmer':
        await PushNotificationService.subscribeToTopic('farmers');
        await PushNotificationService.subscribeToTopic('market_updates');
        await PushNotificationService.subscribeToTopic('farming_tips');
        break;
      case 'buyer':
        await PushNotificationService.subscribeToTopic('buyers');
        await PushNotificationService.subscribeToTopic('new_products');
        await PushNotificationService.subscribeToTopic('deals');
        break;
      case 'cooperative':
        await PushNotificationService.subscribeToTopic('cooperatives');
        await PushNotificationService.subscribeToTopic('admin_updates');
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
      await PushNotificationService.unsubscribeFromTopic(topic);
    }
  }
}
