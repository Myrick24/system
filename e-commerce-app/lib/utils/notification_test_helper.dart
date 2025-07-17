import '../services/notification_manager.dart';
import '../services/push_notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationTestHelper {
  // Test a welcome notification
  static Future<void> testWelcomeNotification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await NotificationManager.sendWelcomeNotification(
        userId: user.uid,
        userName: user.displayName ?? 'Test User',
        userRole: 'farmer', // or 'buyer', 'cooperative'
      );

      // Also send a direct test notification
      await PushNotificationService.sendTestNotification(
        title: 'Welcome to Harvest! 🌱',
        body: 'Thank you for joining our farming community!',
      );
    }
  }

  // Test an order update notification
  static Future<void> testOrderNotification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await NotificationManager.sendOrderUpdateNotification(
        userId: user.uid,
        orderId: 'TEST_ORDER_001',
        status: 'Processing',
      );

      // Direct test notification
      await PushNotificationService.sendTestNotification(
        title: 'Order Update 📦',
        body: 'Your order #TEST_ORDER_001 is now Processing',
      );
    }
  }

  // Test a new product notification
  static Future<void> testProductNotification() async {
    await NotificationManager.sendNewProductNotification(
      productId: 'TEST_PRODUCT_001',
      productName: 'Fresh Tomatoes',
      sellerName: 'Test Farmer',
      category: 'vegetables',
    );

    // Direct test notification
    await PushNotificationService.sendTestNotification(
      title: 'New Product Available! 🍅',
      body: 'Test Farmer has added Fresh Tomatoes to the marketplace',
    );
  }

  // Test a payment confirmation
  static Future<void> testPaymentNotification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await NotificationManager.sendPaymentNotification(
        userId: user.uid,
        orderId: 'TEST_ORDER_001',
        amount: 25.50,
        isReceived: true,
      );

      // Direct test notification
      await PushNotificationService.sendTestNotification(
        title: 'Payment Received! 💰',
        body: 'You received \$25.50 for order #TEST_ORDER_001',
      );
    }
  }

  // Test a general announcement
  static Future<void> testAnnouncementNotification() async {
    await NotificationManager.sendAnnouncement(
      title: 'Test Announcement',
      message: 'This is a test announcement to all users!',
      targetRole: 'all',
    );

    // Direct test notification
    await PushNotificationService.sendTestNotification(
      title: 'Announcement 📢',
      body: 'This is a test announcement to all users!',
    );
  }

  // Test a low stock notification
  static Future<void> testLowStockNotification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await NotificationManager.sendLowStockNotification(
        sellerId: user.uid,
        productName: 'Organic Tomatoes',
        currentStock: 2,
        threshold: 10,
      );

      // Direct test notification
      await PushNotificationService.sendTestNotification(
        title: 'Low Stock Alert! ⚠️',
        body: 'Your Organic Tomatoes are running low (only 2 left)',
      );
    }
  }

  // Test a market price update
  static Future<void> testMarketPriceUpdate() async {
    await NotificationManager.sendMarketPriceUpdate(
      productName: 'Organic Tomatoes',
      newPrice: 4.50,
      oldPrice: 4.00,
    );

    // Direct test notification
    await PushNotificationService.sendTestNotification(
      title: 'Market Price Update 📈',
      body: 'Organic Tomatoes price increased by 12.5% to \$4.50',
    );
  }

  // Test a farming tip
  static Future<void> testFarmingTipNotification() async {
    await NotificationManager.sendFarmingTip(
      tip:
          'Remember to water your crops early in the morning for best results!',
      season: 'spring',
    );

    // Direct test notification
    await PushNotificationService.sendTestNotification(
      title: 'Spring Farming Tip 🌱',
      body:
          'Remember to water your crops early in the morning for best results!',
    );
  }
}
