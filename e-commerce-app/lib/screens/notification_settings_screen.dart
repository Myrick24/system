import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/push_notification_service.dart';
import '../services/notification_manager.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final String userRole;

  const NotificationSettingsScreen({
    Key? key,
    required this.userRole,
  }) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // Notification preferences
  bool _pushNotificationsEnabled = true;
  bool _orderUpdatesEnabled = true;
  bool _newProductsEnabled = true;
  bool _paymentNotificationsEnabled = true;
  bool _lowStockAlertsEnabled = true;
  bool _announcementsEnabled = true;
  bool _marketUpdatesEnabled = true;
  bool _farmingTipsEnabled = true;
  bool _remindersEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotificationsEnabled =
          prefs.getBool('push_notifications_enabled') ?? true;
      _orderUpdatesEnabled = prefs.getBool('order_updates_enabled') ?? true;
      _newProductsEnabled = prefs.getBool('new_products_enabled') ?? true;
      _paymentNotificationsEnabled =
          prefs.getBool('payment_notifications_enabled') ?? true;
      _lowStockAlertsEnabled =
          prefs.getBool('low_stock_alerts_enabled') ?? true;
      _announcementsEnabled = prefs.getBool('announcements_enabled') ?? true;
      _marketUpdatesEnabled = prefs.getBool('market_updates_enabled') ?? true;
      _farmingTipsEnabled = prefs.getBool('farming_tips_enabled') ?? true;
      _remindersEnabled = prefs.getBool('reminders_enabled') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        'push_notifications_enabled', _pushNotificationsEnabled);
    await prefs.setBool('order_updates_enabled', _orderUpdatesEnabled);
    await prefs.setBool('new_products_enabled', _newProductsEnabled);
    await prefs.setBool(
        'payment_notifications_enabled', _paymentNotificationsEnabled);
    await prefs.setBool('low_stock_alerts_enabled', _lowStockAlertsEnabled);
    await prefs.setBool('announcements_enabled', _announcementsEnabled);
    await prefs.setBool('market_updates_enabled', _marketUpdatesEnabled);
    await prefs.setBool('farming_tips_enabled', _farmingTipsEnabled);
    await prefs.setBool('reminders_enabled', _remindersEnabled);

    // Update topic subscriptions based on settings
    await _updateTopicSubscriptions();
  }

  Future<void> _updateTopicSubscriptions() async {
    if (_pushNotificationsEnabled) {
      // Subscribe to role-based topics
      await NotificationManager.subscribeToRoleBasedTopics(widget.userRole);

      // Subscribe/unsubscribe from specific topics based on preferences
      if (_announcementsEnabled) {
        await PushNotificationService.subscribeToTopic('announcements');
      } else {
        await PushNotificationService.unsubscribeFromTopic('announcements');
      }

      if (_marketUpdatesEnabled && widget.userRole == 'farmer') {
        await PushNotificationService.subscribeToTopic('market_updates');
      } else if (!_marketUpdatesEnabled) {
        await PushNotificationService.unsubscribeFromTopic('market_updates');
      }

      if (_farmingTipsEnabled && widget.userRole == 'farmer') {
        await PushNotificationService.subscribeToTopic('farming_tips');
      } else if (!_farmingTipsEnabled) {
        await PushNotificationService.unsubscribeFromTopic('farming_tips');
      }

      if (_newProductsEnabled && widget.userRole == 'buyer') {
        await PushNotificationService.subscribeToTopic('new_products');
      } else if (!_newProductsEnabled) {
        await PushNotificationService.unsubscribeFromTopic('new_products');
      }
    } else {
      // Unsubscribe from all topics if push notifications are disabled
      await NotificationManager.unsubscribeFromAllTopics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Main toggle for push notifications
          Card(
            child: SwitchListTile(
              title: const Text(
                'Push Notifications',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Enable or disable all push notifications'),
              value: _pushNotificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _pushNotificationsEnabled = value;
                });
              },
              secondary: const Icon(Icons.notifications),
            ),
          ),

          const SizedBox(height: 16),

          // Notification categories
          if (_pushNotificationsEnabled) ...[
            const Text(
              'Notification Categories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Order updates
            _buildNotificationTile(
              title: 'Order Updates',
              subtitle: 'Get notified about order status changes',
              icon: Icons.shopping_cart,
              value: _orderUpdatesEnabled,
              onChanged: (value) =>
                  setState(() => _orderUpdatesEnabled = value),
            ),

            // Payment notifications
            _buildNotificationTile(
              title: 'Payment Notifications',
              subtitle: 'Receive alerts for payments and transactions',
              icon: Icons.payment,
              value: _paymentNotificationsEnabled,
              onChanged: (value) =>
                  setState(() => _paymentNotificationsEnabled = value),
            ),

            // Announcements
            _buildNotificationTile(
              title: 'Announcements',
              subtitle: 'Important updates and news from the platform',
              icon: Icons.campaign,
              value: _announcementsEnabled,
              onChanged: (value) =>
                  setState(() => _announcementsEnabled = value),
            ),

            // Reminders
            _buildNotificationTile(
              title: 'Reminders',
              subtitle: 'Task reminders and important dates',
              icon: Icons.schedule,
              value: _remindersEnabled,
              onChanged: (value) => setState(() => _remindersEnabled = value),
            ),

            // Role-specific notifications
            if (widget.userRole == 'farmer') ...[
              const SizedBox(height: 16),
              const Text(
                'Farmer Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildNotificationTile(
                title: 'Low Stock Alerts',
                subtitle: 'Get notified when product stock is running low',
                icon: Icons.warning,
                value: _lowStockAlertsEnabled,
                onChanged: (value) =>
                    setState(() => _lowStockAlertsEnabled = value),
              ),
              _buildNotificationTile(
                title: 'Market Updates',
                subtitle: 'Price changes and market trends',
                icon: Icons.trending_up,
                value: _marketUpdatesEnabled,
                onChanged: (value) =>
                    setState(() => _marketUpdatesEnabled = value),
              ),
              _buildNotificationTile(
                title: 'Farming Tips',
                subtitle: 'Seasonal advice and farming best practices',
                icon: Icons.eco,
                value: _farmingTipsEnabled,
                onChanged: (value) =>
                    setState(() => _farmingTipsEnabled = value),
              ),
            ],

            if (widget.userRole == 'buyer') ...[
              const SizedBox(height: 16),
              const Text(
                'Buyer Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildNotificationTile(
                title: 'New Products',
                subtitle: 'Be first to know about new products and deals',
                icon: Icons.new_releases,
                value: _newProductsEnabled,
                onChanged: (value) =>
                    setState(() => _newProductsEnabled = value),
              ),
            ],
          ],

          const SizedBox(height: 32),

          // Additional options
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Notification Info'),
                  subtitle:
                      const Text('View notification permissions and token'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: _showNotificationInfo,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.clear_all),
                  title: const Text('Clear All Notifications'),
                  subtitle: const Text('Remove all existing notifications'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: _clearAllNotifications,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Reset to Defaults'),
                  subtitle: const Text('Restore default notification settings'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: _resetToDefaults,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon),
      ),
    );
  }

  Future<void> _showNotificationInfo() async {
    final hasPermission = await PushNotificationService.hasPermission();
    final token = await PushNotificationService.getCurrentToken();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Permission: ${hasPermission ? "Granted" : "Denied"}'),
            const SizedBox(height: 8),
            const Text('FCM Token:'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                token ?? 'Not available',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content:
            const Text('Are you sure you want to clear all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PushNotificationService.clearAllNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
            'Are you sure you want to reset all notification settings to defaults?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _pushNotificationsEnabled = true;
        _orderUpdatesEnabled = true;
        _newProductsEnabled = true;
        _paymentNotificationsEnabled = true;
        _lowStockAlertsEnabled = true;
        _announcementsEnabled = true;
        _marketUpdatesEnabled = true;
        _farmingTipsEnabled = true;
        _remindersEnabled = true;
      });

      await _saveSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings reset to defaults'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
