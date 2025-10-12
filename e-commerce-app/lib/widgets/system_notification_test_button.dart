import 'package:flutter/material.dart';
import '../services/push_notification_service.dart';

class SystemNotificationTestButton extends StatelessWidget {
  const SystemNotificationTestButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _testSystemNotification(context),
      icon: const Icon(Icons.notifications_active),
      label: const Text('Test System Notification'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  Future<void> _testSystemNotification(BuildContext context) async {
    try {
      // Show immediate system notification
      await PushNotificationService.sendTestNotification(
        title: '🔔 System Notification Test',
        body:
            'This is a real Android system notification! It should appear as a floating popup and in your notification tray.',
        payload: 'test_system_notification',
      );

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('System notification sent! Check your notification tray.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Error sending system notification: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
