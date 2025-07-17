import 'package:flutter/material.dart';

class NotificationTestButton extends StatelessWidget {
  const NotificationTestButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.pushNamed(context, '/notification-test');
      },
      icon: const Icon(Icons.notifications_active),
      label: const Text('Test Notifications'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }
}
