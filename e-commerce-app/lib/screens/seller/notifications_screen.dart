import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../services/realtime_notification_service.dart';
import '../../widgets/realtime_notification_widgets.dart';
import '../notification_detail_screen.dart';
import '../order_detail_screen.dart';

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
        // Just refresh the list when new notification arrives
        setState(() {}); // Refresh the list
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
      body: _buildNotificationsList(),
    );
  }

  Widget _buildNotificationsList() {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return const Center(
        child: Text('Please log in to view notifications'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
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
                  'No notifications',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'re all caught up!\nNew notifications will appear here.',
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
    );
  }

  Widget _buildNotificationCard(
      Map<String, dynamic> notification, String notificationId) {
    // Check both 'read' and 'isRead' fields
    final isRead =
        (notification['read'] == true) || (notification['isRead'] == true);
    final type = notification['type'] ?? 'general';
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? notification['body'] ?? '';
    final createdAt = notification['createdAt'] ?? notification['timestamp'];

    // Special card for new_order type
    if (type == 'new_order') {
      return _buildOrderNotificationCard(
          notification, notificationId, isRead, title, message, createdAt);
    }

    // Build additional info line for product/order notifications
    List<String> additionalInfo = [];

    if (type.contains('product') || type.contains('order')) {
      final productName = notification['productName'];
      final price = notification['price'];
      final quantity = notification['quantity'];
      final unit = notification['unit'] ?? 'kg';
      final status = notification['status'];

      if (productName != null && productName.toString().isNotEmpty) {
        if (price != null) additionalInfo.add('₱${price.toStringAsFixed(2)}');
        if (quantity != null)
          additionalInfo.add('${quantity.toString()} $unit');
        if (status != null && status.toString().isNotEmpty) {
          additionalInfo.add(status.toString().toUpperCase());
        }
      }
    }

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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: _getNotificationColor(type),
            child: Icon(
              _getNotificationIcon(type),
              color: Colors.white,
              size: 22,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
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
                  color: Colors.grey.shade800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (additionalInfo.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  additionalInfo.join(' • '),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
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
          onTap: () async {
            // Mark as read first and wait for completion
            if (!isRead) {
              await _markAsRead(notificationId);
              // Give a small delay to ensure Firestore updates
              await Future.delayed(const Duration(milliseconds: 200));
            }
            // Navigate based on notification type
            if (mounted) {
              _handleNotificationTap(notification);
            }
          },
        ),
      ),
    );
  }

  Widget _buildOrderNotificationCard(
    Map<String, dynamic> notification,
    String notificationId,
    bool isRead,
    String title,
    String message,
    dynamic createdAt,
  ) {
    final productName = notification['productName'] ?? 'Product';
    final productImage = notification['productImage'] ?? '';
    final quantity = notification['quantity'];
    final unit = notification['unit'] ?? 'kg';
    final totalAmount = notification['totalAmount'];
    final customerName = notification['customerName'] ?? 'Customer';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      elevation: isRead ? 2 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (!isRead) {
            await _markAsRead(notificationId);
            await Future.delayed(const Duration(milliseconds: 200));
          }
          if (mounted) {
            _handleNotificationTap(notification);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isRead
                ? null
                : LinearGradient(
                    colors: [
                      AppTheme.primaryGreen.withOpacity(0.03),
                      Colors.blue.withOpacity(0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: Border.all(
              color: isRead
                  ? Colors.grey.shade200
                  : AppTheme.primaryGreen.withOpacity(0.3),
              width: isRead ? 1 : 2,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title and Unread Indicator
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.shopping_bag,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'NEW',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
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
                ],
              ),
              const SizedBox(height: 12),
              // Divider
              Container(
                height: 1,
                color: Colors.grey.shade200,
              ),
              const SizedBox(height: 12),
              // Product Details Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  if (productImage.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        productImage,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey.shade400,
                              size: 30,
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.grey.shade400,
                        size: 30,
                      ),
                    ),
                  const SizedBox(width: 12),
                  // Product Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Quantity Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade600
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inventory_2,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '$quantity $unit',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Total Amount Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade400,
                                Colors.green.shade600
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.payments,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '₱${totalAmount?.toStringAsFixed(2) ?? '0.00'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Customer Info
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.grey.shade600, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'From: $customerName',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        color: Colors.grey.shade400, size: 14),
                  ],
                ),
              ),
            ],
          ),
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
      // Update both 'read' and 'isRead' fields for compatibility
      await _firestore.collection('notifications').doc(notificationId).set({
        'read': true,
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✓ Notification $notificationId marked as read');
    } catch (e) {
      print('Error marking notification as read: $e');
      // Retry with update method
      try {
        await _firestore
            .collection('notifications')
            .doc(notificationId)
            .update({
          'read': true,
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      } catch (retryError) {
        print('Retry failed: $retryError');
      }
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

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    final type = notification['type'] ?? '';

    // For new_order notifications, fetch the actual order and use OrderDetailScreen
    if (type == 'new_order') {
      final orderId = notification['orderId'];

      if (orderId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Order ID not found'), backgroundColor: Colors.red),
        );
        return;
      }

      try {
        // Fetch the full order document from the orders collection
        final orderDoc =
            await _firestore.collection('orders').doc(orderId).get();

        if (!orderDoc.exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Order not found'),
                  backgroundColor: Colors.red),
            );
          }
          return;
        }

        // Use the actual order data from the orders collection
        final orderData = orderDoc.data() as Map<String, dynamic>;
        orderData['id'] = orderDoc.id;
        orderData['orderId'] = orderDoc.id;

        // If order doesn't have sellerId, get it from the notification
        if (!orderData.containsKey('sellerId') ||
            orderData['sellerId'] == null) {
          orderData['sellerId'] = notification['sellerId'];
          print(
              'DEBUG: Added sellerId from notification: ${notification['sellerId']}');
        }

        // Get customer info like order management does
        if (orderData.containsKey('userId')) {
          try {
            final userDoc = await _firestore
                .collection('users')
                .doc(orderData['userId'])
                .get();
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              orderData['customerName'] = userData['name'] ??
                  userData['fullName'] ??
                  'Unknown Customer';
              orderData['customerContact'] = userData['phone'] ??
                  userData['phoneNumber'] ??
                  userData['contact'];
              orderData['customerEmail'] = userData['email'];
            }
          } catch (e) {
            print('Error fetching customer info: $e');
          }
        }

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailScreen(
                order: orderData,
              ),
            ),
          );
        }
      } catch (e) {
        print('Error fetching order: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error loading order: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    } else {
      // For other notifications, use NotificationDetailScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NotificationDetailScreen(
            notification: notification,
          ),
        ),
      );
    }
  }

  void _showNotificationPopup(Map<String, dynamic> notification) {
    final type = notification['type'] ?? '';
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final productId = notification['productId'];
    final productName = notification['productName'];
    final createdAt = notification['createdAt'] ?? notification['timestamp'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getNotificationColor(type),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getNotificationIcon(type),
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                if (productName != null) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Product: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          productName,
                          style: const TextStyle(
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (productId != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.tag,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Product ID: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          productId,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (productId != null &&
                (type == 'product_approved' || type == 'product_rejected'))
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to product details or seller products screen
                  Navigator.pushNamed(context, '/seller-products');
                },
                icon: const Icon(Icons.visibility),
                label: const Text('View Products'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
            ),
          ],
        );
      },
    );
  }
}
