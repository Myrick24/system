import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../services/realtime_notification_service.dart';
import '../../widgets/realtime_notification_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // Listen to real-time notification updates
    RealtimeNotificationService.notificationStream.listen((notification) {
      if (mounted && notification['source'] == 'firestore') {
        // Show snackbar for new notifications
        RealtimeNotificationSnackbar.show(
          context,
          title: notification['data']['title'] ?? 'New Notification',
          message: notification['data']['message'] ?? '',
          onTap: () {
            setState(() {}); // Refresh the list
          },
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Please log in to view notifications'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            const SizedBox(width: 8),
            StreamBuilder<int>(
              stream: RealtimeNotificationService.unreadCountStream,
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text(
              'Mark All Read',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .where('userId', isEqualTo: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading notifications: ${snapshot.error}'),
                  const SizedBox(height: 8),
                  Text(
                    'Try refreshing the page',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          var notifications = snapshot.data?.docs ?? [];

          // Sort notifications by timestamp/createdAt (handle both field names)
          notifications.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            
            final aTime = aData['timestamp'] ?? aData['createdAt'];
            final bTime = bData['timestamp'] ?? bData['createdAt'];
            
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            
            final aDate = (aTime as Timestamp).toDate();
            final bDate = (bTime as Timestamp).toDate();
            
            return bDate.compareTo(aDate); // Descending order
          });

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll receive notifications when your products are reviewed',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification =
                  notifications[index].data() as Map<String, dynamic>;
              final notificationId = notifications[index].id;

              return _buildNotificationCard(notification, notificationId);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
      Map<String, dynamic> notification, String notificationId) {
    final isRead = notification['read'] ?? notification['isRead'] ?? false;
    final type = notification['type'] ?? 'general';
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final createdAt = notification['createdAt'] ?? notification['timestamp'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: isRead ? 1 : 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isRead
                ? Colors.grey.shade200
                : AppTheme.primaryGreen.withOpacity(0.3),
            width: isRead ? 0.5 : 1.5,
          ),
          color:
              isRead ? Colors.white : AppTheme.primaryGreen.withOpacity(0.05),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _getNotificationColor(type),
            child: Icon(
              _getNotificationIcon(type),
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDate(createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
            onSelected: (value) {
              switch (value) {
                case 'mark_read':
                  if (!isRead) _markAsRead(notificationId);
                  break;
                case 'mark_unread':
                  if (isRead) _markAsUnread(notificationId);
                  break;
                case 'delete':
                  _deleteNotification(notificationId);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (!isRead)
                const PopupMenuItem(
                  value: 'mark_read',
                  child: Row(
                    children: [
                      Icon(Icons.mark_email_read, size: 18),
                      SizedBox(width: 8),
                      Text('Mark as Read'),
                    ],
                  ),
                ),
              if (isRead)
                const PopupMenuItem(
                  value: 'mark_unread',
                  child: Row(
                    children: [
                      Icon(Icons.mark_email_unread, size: 18),
                      SizedBox(width: 8),
                      Text('Mark as Unread'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          onTap: () {
            if (!isRead) {
              _markAsRead(notificationId);
            }
            // If this is a product notification, you could navigate to the product details
            _handleNotificationTap(notification);
          },
        ),
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'product_approved':
        return Colors.green;
      case 'product_rejected':
        return Colors.red;
      case 'order_received':
        return Colors.blue;
      case 'order_cancelled':
        return Colors.orange;
      case 'seller_approved':
        return AppTheme.primaryGreen;
      case 'seller_rejected':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'product_approved':
        return Icons.check_circle;
      case 'product_rejected':
        return Icons.cancel;
      case 'order_received':
        return Icons.shopping_bag;
      case 'order_cancelled':
        return Icons.cancel_outlined;
      case 'seller_approved':
        return Icons.verified;
      case 'seller_rejected':
        return Icons.error;
      default:
        return Icons.notifications;
    }
  }

  String _formatDate(dynamic createdAt) {
    if (createdAt == null) return 'Unknown';

    DateTime date;
    if (createdAt is Timestamp) {
      date = createdAt.toDate();
    } else if (createdAt is String) {
      try {
        date = DateTime.parse(createdAt);
      } catch (e) {
        return 'Unknown';
      }
    } else {
      return 'Unknown';
    }

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAsUnread(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': false,
      });
    } catch (e) {
      print('Error marking notification as unread: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await RealtimeNotificationService.markAllAsRead();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error marking notifications as read'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification deleted'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } catch (e) {
      print('Error deleting notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error deleting notification'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final type = notification['type'] ?? '';
    final productId = notification['productId'];

    // Handle different notification types
    switch (type) {
      case 'product_approved':
      case 'product_rejected':
        if (productId != null) {
          // You could navigate to product details or seller products screen
          // For now, just show a message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product ID: $productId'),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
        }
        break;
      default:
        break;
    }
  }
}
