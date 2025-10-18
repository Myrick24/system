import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/realtime_notification_service.dart';
import '../../widgets/realtime_notification_widgets.dart';

class AccountNotifications extends StatefulWidget {
  const AccountNotifications({Key? key}) : super(key: key);

  @override
  State<AccountNotifications> createState() => _AccountNotificationsState();
}

class _AccountNotificationsState extends State<AccountNotifications> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSeller = false;
  String? _userRole;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserRole();
    _listenToRealtimeNotifications();
  }

  void _listenToRealtimeNotifications() {
    // Listen to real-time notification updates
    RealtimeNotificationService.notificationStream.listen((notification) {
      if (mounted && notification['source'] == 'firestore') {
        // Optionally show snackbar for new notifications
        final data = notification['data'] as Map<String, dynamic>?;
        if (data != null) {
          RealtimeNotificationSnackbar.show(
            context,
            title: data['title'] ?? 'New Notification',
            message: data['message'] ?? '',
            onTap: () {
              setState(() {}); // Refresh the list
            },
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          setState(() {
            _userRole = userData?['role'];
            _isSeller = _userRole == 'seller';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user role: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.green,
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
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: const Icon(Icons.notifications),
              text: _isSeller ? 'Seller Notifications' : 'Buyer Notifications',
            ),
            Tab(
              icon: const Icon(Icons.history),
              text: 'All Notifications',
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _markAllAsRead,
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
          ),
          IconButton(
            onPressed: _clearAllNotifications,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear all',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Role-specific notifications
          _isSeller ? _buildSellerNotifications(user.uid) : _buildBuyerNotifications(user.uid),
          // All notifications
          _buildAllNotifications(user.uid),
        ],
      ),
    );
  }

  // Build seller-specific notifications
  Widget _buildSellerNotifications(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        return _buildNotificationsList(snapshot, 'seller');
      },
    );
  }

  // Build buyer-specific notifications
  Widget _buildBuyerNotifications(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        return _buildNotificationsList(snapshot, 'buyer');
      },
    );
  }

  // Build all notifications
  Widget _buildAllNotifications(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        return _buildNotificationsList(snapshot, 'all');
      },
    );
  }

  Widget _buildNotificationsList(AsyncSnapshot<QuerySnapshot> snapshot, String type) {
    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: ${snapshot.error}'),
            const SizedBox(height: 8),
            Text(
              'Try refreshing the screen',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    var notifications = snapshot.data?.docs ?? [];
    
    // Filter by type if needed
    if (type == 'seller') {
      final sellerTypes = [
        'checkout_seller',
        'seller_approved',
        'seller_rejected',
        'product_approval',
        'product_approved',
        'product_rejected',
        'product_rejection',
        'new_product_seller',
        'low_stock',
        'order_status',
      ];
      notifications = notifications.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return sellerTypes.contains(data['type'] ?? '');
      }).toList();
    } else if (type == 'buyer') {
      final buyerTypes = [
        'checkout_buyer',
        'order_update',
        'order_status',
        'new_product_buyer',
        'product_update',
        'payment',
      ];
      notifications = notifications.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return buyerTypes.contains(data['type'] ?? '');
      }).toList();
    }
    
    // Sort notifications by timestamp/createdAt (handle both field names)
    notifications.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      
      final aTime = aData['timestamp'] ?? aData['createdAt'];
      final bTime = bData['timestamp'] ?? bData['createdAt'];
      
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      
      if (aTime is Timestamp && bTime is Timestamp) {
        return bTime.compareTo(aTime); // Descending order
      }
      
      return 0;
    });
    
    // Limit results
    if (type != 'all' && notifications.length > 50) {
      notifications = notifications.sublist(0, 50);
    } else if (notifications.length > 100) {
      notifications = notifications.sublist(0, 100);
    }

    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              type == 'seller'
                  ? 'No seller notifications yet'
                  : type == 'buyer'
                      ? 'No buyer notifications yet'
                      : 'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              type == 'seller'
                  ? 'You\'ll see order updates, product approvals, and more here'
                  : type == 'buyer'
                      ? 'You\'ll see order confirmations, new products, and updates here'
                      : 'All your notifications will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // Calculate unread count
    final unreadCount = notifications.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['read'] == false;
    }).length;

    if (unreadCount != _unreadCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _unreadCount = unreadCount;
          });
        }
      });
    }

    return ListView.builder(
      itemCount: notifications.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        final data = notification.data() as Map<String, dynamic>;

        return _buildNotificationTile(notification.id, data);
      },
    );
  }

  Widget _buildNotificationTile(String notificationId, Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final title = data['title'] ?? 'Notification';
    final message = data['message'] ?? '';
    final isRead = data['read'] ?? data['isRead'] ?? false;
    final timestamp = (data['timestamp'] ?? data['createdAt']) as Timestamp?;
    final priority = data['priority'] ?? 'normal';

    // Get icon and color based on notification type
    IconData icon = Icons.notifications;
    Color iconColor = Colors.blue;

    if (type.contains('checkout') || type.contains('order')) {
      icon = Icons.shopping_cart;
      iconColor = Colors.green;
    } else if (type.contains('product')) {
      icon = Icons.inventory_2;
      iconColor = Colors.orange;
    } else if (type.contains('seller')) {
      icon = Icons.store;
      iconColor = Colors.purple;
    } else if (type.contains('payment')) {
      icon = Icons.payment;
      iconColor = Colors.teal;
    } else if (type.contains('low_stock')) {
      icon = Icons.warning;
      iconColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: isRead ? 0 : 2,
      color: isRead ? Colors.white : Colors.green.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(icon, color: iconColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (priority == 'high')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'HIGH',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
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
                color: Colors.grey[700],
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: isRead
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () => _handleNotificationTap(notificationId, data),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';

    final DateTime dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  Future<void> _handleNotificationTap(String notificationId, Map<String, dynamic> data) async {
    // Mark as read
    await _markAsRead(notificationId);

    final type = data['type'];

    // Handle navigation based on notification type
    switch (type) {
      case 'checkout_seller':
      case 'checkout_buyer':
        final orderId = data['orderId'];
        if (orderId != null) {
          // Navigate to order details
          // You can implement this based on your app's navigation
          _showNotificationDetails(data);
        }
        break;
      case 'product_approval':
      case 'product_rejection':
        // Navigate to product management or show details
        _showNotificationDetails(data);
        break;
      case 'seller_approved':
      case 'seller_rejected':
        _showNotificationDetails(data);
        break;
      default:
        _showNotificationDetails(data);
        break;
    }
  }

  void _showNotificationDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['title'] ?? 'Notification'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(data['message'] ?? ''),
              const SizedBox(height: 16),
              if (data['orderId'] != null) ...[
                Text('Order ID: ${data['orderId']}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
              ],
              if (data['productName'] != null) ...[
                Text('Product: ${data['productName']}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
              ],
              if (data['quantity'] != null) ...[
                Text('Quantity: ${data['quantity']} ${data['unit'] ?? ''}'),
                const SizedBox(height: 8),
              ],
              if (data['totalAmount'] != null) ...[
                Text('Amount: \$${data['totalAmount'].toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                const SizedBox(height: 8),
              ],
              if (data['buyerName'] != null) ...[
                Text('Buyer: ${data['buyerName']}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await RealtimeNotificationService.markAllAsRead();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to delete all notifications? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final user = _auth.currentUser;
        if (user != null) {
          final notifications = await _firestore
              .collection('notifications')
              .where('userId', isEqualTo: user.uid)
              .get();

          final batch = _firestore.batch();
          for (var doc in notifications.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('All notifications cleared')),
            );
          }
        }
      } catch (e) {
        print('Error clearing notifications: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
