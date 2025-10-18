import 'package:flutter/material.dart';
import '../utils/notification_debug_helper.dart';

/// A debug widget to test notifications - remove in production
class NotificationDebugWidget extends StatelessWidget {
  const NotificationDebugWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report, color: Colors.orange),
              const SizedBox(width: 8),
              const Text(
                'Debug Tools',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await NotificationDebugHelper.runAllChecks();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Check console for debug info'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: const Text('Run Checks'),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Create Test Notifications:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DebugButton(
                label: 'Product Approved',
                color: Colors.green,
                onTap: () async {
                  await NotificationDebugHelper.createTestNotification(
                    type: 'product_approved',
                    title: 'Product Approved! 🎉',
                    message: 'Your product "Test Product" has been approved by the admin',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Product approval notification created')),
                    );
                  }
                },
              ),
              _DebugButton(
                label: 'Product Rejected',
                color: Colors.red,
                onTap: () async {
                  await NotificationDebugHelper.createTestNotification(
                    type: 'product_rejected',
                    title: 'Product Rejected',
                    message: 'Your product needs revision. Please check the details.',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('❌ Product rejection notification created')),
                    );
                  }
                },
              ),
              _DebugButton(
                label: 'New Order',
                color: Colors.blue,
                onTap: () async {
                  await NotificationDebugHelper.createTestNotification(
                    type: 'checkout_seller',
                    title: 'New Order Received! 📦',
                    message: 'You have a new order for 5kg of Rice',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📦 New order notification created')),
                    );
                  }
                },
              ),
              _DebugButton(
                label: 'Order Update',
                color: Colors.purple,
                onTap: () async {
                  await NotificationDebugHelper.createTestNotification(
                    type: 'order_status',
                    title: 'Order Status Update',
                    message: 'Your order has been approved and is being processed',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📝 Order update notification created')),
                    );
                  }
                },
              ),
              _DebugButton(
                label: 'Seller Approved',
                color: Colors.teal,
                onTap: () async {
                  await NotificationDebugHelper.createTestNotification(
                    type: 'seller_approved',
                    title: 'Seller Account Approved! ✅',
                    message: 'Congratulations! Your seller account has been approved. You can now list products.',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Seller approval notification created')),
                    );
                  }
                },
              ),
              _DebugButton(
                label: 'Low Stock',
                color: Colors.orange,
                onTap: () async {
                  await NotificationDebugHelper.createTestNotification(
                    type: 'low_stock',
                    title: 'Low Stock Alert! ⚠️',
                    message: 'Your product "Rice" is running low on stock (5 units remaining)',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('⚠️ Low stock notification created')),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'This is a debug widget. Remove it in production.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebugButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DebugButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(label),
    );
  }
}
