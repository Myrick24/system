import 'package:flutter/material.dart';
import '../services/notification_manager.dart';
import '../services/push_notification_service.dart';
import '../utils/notification_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({Key? key}) : super(key: key);

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _fcmToken;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationInfo();
  }

  Future<void> _loadNotificationInfo() async {
    final token = await PushNotificationService.getCurrentToken();
    final permission = await PushNotificationService.hasPermission();

    setState(() {
      _fcmToken = token;
      _hasPermission = permission;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notification Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _hasPermission ? Icons.check_circle : Icons.error,
                          color: _hasPermission ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Permission: ${_hasPermission ? "Granted" : "Denied"}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'FCM Token: ${_fcmToken?.substring(0, 20) ?? "Not available"}...',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Add validation widget
            const NotificationValidationWidget(),

            const SizedBox(height: 16),

            const Text(
              'Test Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // Test buttons
            Expanded(
              child: ListView(
                children: [
                  _buildTestButton(
                    title: 'Direct System Notification',
                    subtitle: 'Test real system notification (floating popup)',
                    icon: Icons.notification_important,
                    onPressed: () => _sendDirectSystemNotification(),
                  ),
                  _buildTestButton(
                    title: 'Welcome Notification',
                    subtitle: 'Test welcome message for new users',
                    icon: Icons.waving_hand,
                    onPressed: () => _sendWelcomeNotification(),
                  ),
                  _buildTestButton(
                    title: 'Order Update',
                    subtitle: 'Simulate an order status change',
                    icon: Icons.shopping_cart,
                    onPressed: () => _sendOrderUpdateNotification(),
                  ),
                  _buildTestButton(
                    title: 'New Product Alert',
                    subtitle: 'Alert about a new product (for buyers)',
                    icon: Icons.new_releases,
                    onPressed: () => _sendNewProductNotification(),
                  ),
                  _buildTestButton(
                    title: 'Payment Notification',
                    subtitle: 'Payment received confirmation',
                    icon: Icons.payment,
                    onPressed: () => _sendPaymentNotification(),
                  ),
                  _buildTestButton(
                    title: 'Low Stock Alert',
                    subtitle: 'Warn about low inventory (for farmers)',
                    icon: Icons.warning,
                    onPressed: () => _sendLowStockNotification(),
                  ),
                  _buildTestButton(
                    title: 'Farming Tip',
                    subtitle: 'Seasonal farming advice',
                    icon: Icons.eco,
                    onPressed: () => _sendFarmingTip(),
                  ),
                  _buildTestButton(
                    title: 'General Announcement',
                    subtitle: 'Platform-wide announcement',
                    icon: Icons.campaign,
                    onPressed: () => _sendAnnouncement(),
                  ),
                  _buildTestButton(
                    title: 'Market Price Update',
                    subtitle: 'Commodity price change alert',
                    icon: Icons.trending_up,
                    onPressed: () => _sendMarketPriceUpdate(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _refreshInfo,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Info'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearNotifications,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.send),
        onTap: onPressed,
      ),
    );
  }

  Future<void> _sendDirectSystemNotification() async {
    final success = await NotificationManager.sendDirectTestNotification(
      title: 'System Notification Test',
      body:
          'This is a real system notification that should appear as a floating popup and in the notification tray!',
      payload: 'direct_test',
    );

    _showResult(success, 'Direct system notification');
  }

  Future<void> _sendWelcomeNotification() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final success = await NotificationManager.sendWelcomeNotification(
      userId: user.uid,
      userName: user.displayName ?? 'User',
      userRole: 'farmer', // You can make this dynamic
    );

    _showResult(success, 'Welcome notification');
  }

  Future<void> _sendOrderUpdateNotification() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final success = await NotificationManager.sendOrderUpdateNotification(
      userId: user.uid,
      orderId: 'ORDER-12345',
      status: 'Delivered',
      customerName: 'John Doe',
    );

    _showResult(success, 'Order update notification');
  }

  Future<void> _sendNewProductNotification() async {
    final success = await NotificationManager.sendNewProductNotification(
      productId: 'PROD-67890',
      productName: 'Fresh Organic Tomatoes',
      sellerName: 'Green Valley Farm',
      category: 'Vegetables',
    );

    _showResult(success, 'New product notification');
  }

  Future<void> _sendPaymentNotification() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final success = await NotificationManager.sendPaymentNotification(
      userId: user.uid,
      orderId: 'ORDER-12345',
      amount: 45.99,
      isReceived: true,
    );

    _showResult(success, 'Payment notification');
  }

  Future<void> _sendLowStockNotification() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final success = await NotificationManager.sendLowStockNotification(
      sellerId: user.uid,
      productName: 'Organic Carrots',
      currentStock: 3,
      threshold: 10,
    );

    _showResult(success, 'Low stock notification');
  }

  Future<void> _sendFarmingTip() async {
    final success = await NotificationManager.sendFarmingTip(
      tip:
          'Spring is the perfect time to plant tomatoes and peppers. Make sure the soil temperature is above 60°F.',
      season: 'Spring',
    );

    _showResult(success, 'Farming tip notification');
  }

  Future<void> _sendAnnouncement() async {
    final success = await NotificationManager.sendAnnouncement(
      title: 'Platform Maintenance',
      message:
          'We will be performing scheduled maintenance tonight from 11 PM to 2 AM. The app may be temporarily unavailable.',
    );

    _showResult(success, 'Announcement notification');
  }

  Future<void> _sendMarketPriceUpdate() async {
    final success = await NotificationManager.sendMarketPriceUpdate(
      productName: 'Organic Tomatoes',
      newPrice: 4.50,
      oldPrice: 4.00,
    );

    _showResult(success, 'Market price update notification');
  }

  void _showResult(bool success, String notificationType) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '$notificationType sent successfully!'
              : 'Failed to send $notificationType',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _refreshInfo() async {
    await _loadNotificationInfo();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification info refreshed'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _clearNotifications() async {
    await PushNotificationService.clearAllNotifications();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications cleared'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
