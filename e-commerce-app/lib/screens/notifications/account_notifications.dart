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
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
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
    // Check both 'read' and 'isRead' fields
    final isRead = (data['read'] == true) || (data['isRead'] == true);
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
        onTap: () async {
          // Mark as read first and wait for completion
          if (!isRead) {
            await _markAsRead(notificationId);
            // Give a small delay to ensure Firestore updates
            await Future.delayed(const Duration(milliseconds: 200));
          }
          // Show popup with notification details
          if (mounted) {
            _showNotificationPopup(data);
          }
        },
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

  Future<void> _markAsRead(String notificationId) async {
    try {
      // Update both 'read' and 'isRead' fields for compatibility
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .set({
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

  void _showNotificationPopup(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final title = data['title'] ?? 'Notification';
    final message = data['message'] ?? '';
    final timestamp = (data['timestamp'] ?? data['createdAt']) as Timestamp?;
    final priority = data['priority'] ?? 'normal';
    
    // Extract additional details
    final orderId = data['orderId'];
    final productName = data['productName'];
    final quantity = data['quantity'];
    final totalAmount = data['totalAmount'];
    final buyerName = data['buyerName'];
    final sellerName = data['sellerName'];

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

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: const EdgeInsets.all(20),
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
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
                if (priority == 'high')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
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
                const SizedBox(width: 8),
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
                // Message
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
                
                // Only show details section if there are any details
                if (orderId != null || productName != null || quantity != null || 
                    totalAmount != null || buyerName != null || sellerName != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order details
                        if (orderId != null) ...[
                          _buildDetailRow(Icons.receipt_long, 'Order ID', orderId),
                          const SizedBox(height: 12),
                        ],
                        
                        // Product details
                        if (productName != null) ...[
                          _buildDetailRow(Icons.inventory_2, 'Product', productName),
                          const SizedBox(height: 12),
                        ],
                        
                        if (quantity != null) ...[
                          _buildDetailRow(Icons.shopping_basket, 'Quantity', quantity.toString()),
                          const SizedBox(height: 12),
                        ],
                        
                        if (totalAmount != null) ...[
                          _buildDetailRow(
                            Icons.payments, 
                            'Total Amount', 
                            '₱${totalAmount.toStringAsFixed(2)}',
                            valueColor: Colors.green.shade700,
                            valueFontWeight: FontWeight.bold,
                          ),
                          const SizedBox(height: 12),
                        ],
                        
                        // Buyer/Seller details
                        if (buyerName != null) ...[
                          _buildDetailRow(Icons.person, 'Buyer', buyerName),
                          const SizedBox(height: 12),
                        ],
                        
                        if (sellerName != null) ...[
                          _buildDetailRow(Icons.store, 'Seller', sellerName),
                          const SizedBox(height: 12),
                        ],
                        
                        // Remove the last SizedBox
                        const SizedBox(height: 0),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Timestamp
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimestamp(timestamp),
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
              style: TextButton.styleFrom(
                foregroundColor: iconColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor, FontWeight? valueFontWeight}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: valueColor ?? Colors.black87,
                    fontWeight: valueFontWeight ?? FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
