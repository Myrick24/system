import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'approval_screen.dart';
import 'order_status_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  bool _isSeller = false;
  bool _isCooperative = false;
  String? _sellerId;
  String _errorMessage = '';
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  StreamSubscription<QuerySnapshot>? _cooperativeNotificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _cooperativeNotificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Check if user is a seller
        final sellerQuery = await _firestore
            .collection('sellers')
            .where('email', isEqualTo: currentUser.email)
            .limit(1)
            .get();

        if (sellerQuery.docs.isNotEmpty) {
          final sellerData = sellerQuery.docs.first.data();
          setState(() {
            _isSeller = true;
            _sellerId = sellerData['id'];
          });
        }

        // Check if user is a cooperative
        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final userRole = userData['role'] ?? '';
          if (userRole == 'cooperative') {
            setState(() {
              _isCooperative = true;
            });
          }
        }

        if (_isSeller) {
          await _setupSellerNotificationsListener(_sellerId!);
        } else {
          await _setupBuyerNotificationsListener(currentUser.uid);
        }

        // If cooperative, also setup cooperative notifications listener
        if (_isCooperative) {
          await _setupCooperativeNotificationsListener(currentUser.uid);
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load user info: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _setupSellerNotificationsListener(String sellerId) async {
    try {
      _notificationSubscription?.cancel();

      // Modified query to work without the compound index
      final notificationsQuery = _firestore
          .collection('seller_notifications')
          .where('sellerId', isEqualTo: sellerId)
          // Removed the orderBy clause that requires the composite index
          .limit(50);

      // Wrap in try-catch for better error handling during listening
      _notificationSubscription = notificationsQuery.snapshots().listen(
        (snapshot) {
          List<Map<String, dynamic>> notifications = [];
          List<String> unreadNotificationIds = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            notifications.add(data);

            // Track unread notifications for marking as read
            if (data['status'] == 'unread') {
              unreadNotificationIds.add(doc.id);
            }
          }

          // Sort notifications by timestamp locally instead of in the query
          notifications.sort((a, b) {
            var aTime = a['timestamp'] as Timestamp?;
            var bTime = b['timestamp'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); // descending order (newest first)
          });

          if (mounted) {
            setState(() {
              _notifications = notifications;
              _isLoading = false;
              _errorMessage = ''; // Clear any previous errors
            });
          }

          if (unreadNotificationIds.isNotEmpty) {
            _markNotificationsAsRead(unreadNotificationIds);
          }
        },
        onError: (error) {
          print('Error in seller notifications listener: $error');
          if (mounted) {
            setState(() {
              _errorMessage = 'Failed to load notifications: $error';
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      print('Exception in _setupSellerNotificationsListener: $e');
      setState(() {
        _errorMessage = 'Failed to load notifications: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _setupBuyerNotificationsListener(String userId) async {
    try {
      _notificationSubscription?.cancel();

      // Listen to the notifications collection for buyer notifications
      final notificationsQuery = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .limit(50);

      _notificationSubscription = notificationsQuery.snapshots().listen(
        (snapshot) {
          List<Map<String, dynamic>> notifications = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            notifications.add(data);
          }

          // Sort notifications by timestamp locally (newest first)
          notifications.sort((a, b) {
            var aTime = a['timestamp'] as Timestamp?;
            var bTime = b['timestamp'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          if (mounted) {
            setState(() {
              _notifications = notifications;
              _isLoading = false;
              _errorMessage = '';
            });
          }
        },
        onError: (error) {
          print('Error in buyer notifications listener: $error');
          if (mounted) {
            setState(() {
              _errorMessage = 'Failed to load notifications: $error';
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      print('Exception in _setupBuyerNotificationsListener: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load notifications: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setupCooperativeNotificationsListener(String userId) async {
    try {
      _cooperativeNotificationSubscription?.cancel();

      // Listen to the cooperative_notifications collection
      final cooperativeNotificationsQuery = _firestore
          .collection('cooperative_notifications')
          .where('userId', isEqualTo: userId)
          .limit(50);

      _cooperativeNotificationSubscription =
          cooperativeNotificationsQuery.snapshots().listen(
        (snapshot) {
          List<Map<String, dynamic>> cooperativeNotifications = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            data['isCooperativeNotification'] =
                true; // Flag to distinguish notification type
            cooperativeNotifications.add(data);
          }

          // Merge with existing notifications (if any)
          List<Map<String, dynamic>> allNotifications = [
            ...cooperativeNotifications
          ];

          // Sort notifications by timestamp (newest first)
          allNotifications.sort((a, b) {
            var aTime = a['timestamp'] as Timestamp?;
            var bTime = b['timestamp'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          if (mounted) {
            setState(() {
              _notifications = allNotifications;
              _isLoading = false;
              _errorMessage = '';
            });
          }

          // Mark unread notifications as read after viewing
          List<String> unreadNotificationIds = cooperativeNotifications
              .where((notification) => notification['status'] == 'unread')
              .map((notification) => notification['id'] as String)
              .toList();

          if (unreadNotificationIds.isNotEmpty) {
            _markCooperativeNotificationsAsRead(unreadNotificationIds);
          }
        },
        onError: (error) {
          print('Error in cooperative notifications listener: $error');
          if (mounted) {
            setState(() {
              _errorMessage = 'Failed to load notifications: $error';
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      print('Exception in _setupCooperativeNotificationsListener: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load notifications: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markNotificationsAsRead(List<String> notificationIds) async {
    try {
      if (notificationIds.isEmpty) return;

      final batch = _firestore.batch();

      for (String notificationId in notificationIds) {
        // For sellers, use seller_notifications collection
        if (_isSeller) {
          final notificationRef =
              _firestore.collection('seller_notifications').doc(notificationId);
          batch.update(notificationRef, {'status': 'read'});
        } else {
          // For buyers, use notifications collection
          final notificationRef =
              _firestore.collection('notifications').doc(notificationId);
          batch.update(notificationRef, {'read': true});
        }
      }

      await batch.commit();
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  Future<void> _markCooperativeNotificationsAsRead(
      List<String> notificationIds) async {
    try {
      if (notificationIds.isEmpty) return;

      final batch = _firestore.batch();

      for (String notificationId in notificationIds) {
        final notificationRef = _firestore
            .collection('cooperative_notifications')
            .doc(notificationId);
        batch.update(notificationRef, {'status': 'read'});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking cooperative notifications as read: $e');
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      final DateTime dateTime = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.fromMillisecondsSinceEpoch(timestamp);

      final difference = DateTime.now().difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        final minutes = difference.inMinutes;
        return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
      } else if (difference.inDays < 1) {
        final hours = difference.inHours;
        return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inDays < 7) {
        final days = difference.inDays;
        return '$days ${days == 1 ? 'day' : 'days'} ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _getNotificationIcon(String type, String status,
      [Map<String, dynamic>? notificationData]) {
    IconData iconData;
    Color iconColor;

    // Special handling for announcements
    if (type == 'announcement') {
      iconData = Icons.campaign;
      iconColor = const Color(0xFF1890FF);
    } else if (type == 'new_order') {
      iconData = Icons.shopping_bag;
      iconColor = Colors.green;
    } else if (type == 'cooperative_order') {
      iconData = Icons.shopping_cart;
      iconColor = Colors.blue;
    } else if (type == 'new_message') {
      iconData = Icons.message;
      iconColor = Colors.purple;
    } else if (type == 'new_reservation') {
      iconData = Icons.event;
      iconColor = Colors.blue;
    } else if (type == 'seller_application') {
      iconData = Icons.person_add;
      iconColor = Colors.orange;
    } else if (type == 'seller_status') {
      // Seller application approval/rejection
      final notifStatus = notificationData?['status'] as String?;
      if (notifStatus == 'approved') {
        iconData = Icons.check_circle;
        iconColor = Colors.green;
      } else {
        iconData = Icons.cancel;
        iconColor = Colors.red;
      }
    } else {
      switch (status.toLowerCase()) {
        case 'pending':
          iconData = Icons.hourglass_empty;
          iconColor = Colors.orange;
          break;
        case 'processing':
          iconData = Icons.sync;
          iconColor = Colors.blue;
          break;
        case 'shipped':
          iconData = Icons.local_shipping;
          iconColor = Colors.indigo;
          break;
        case 'delivered':
          iconData = Icons.check_circle;
          iconColor = Colors.green;
          break;
        case 'cancelled':
          iconData = Icons.cancel;
          iconColor = Colors.red;
          break;
        default:
          iconData = Icons.notifications;
          iconColor = Colors.grey;
      }
    }

    return CircleAvatar(
      backgroundColor: iconColor.withOpacity(0.1),
      radius: 24,
      child: Icon(iconData, color: iconColor, size: 28),
    );
  }

  void _showNotificationDetails(Map<String, dynamic> data) {
    final isAnnouncement = data['type'] == 'announcement';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              if (isAnnouncement)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1890FF), Color(0xFF40A9FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.campaign,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              if (isAnnouncement) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAnnouncement)
                      const Text(
                        'ADMIN ANNOUNCEMENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1890FF),
                          letterSpacing: 0.5,
                        ),
                      ),
                    Text(
                      data['title'] ?? 'Notification',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isAnnouncement
                            ? const Color(0xFF1890FF)
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAnnouncement)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1890FF).withOpacity(0.1),
                          const Color(0xFF1890FF).withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF1890FF).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      data['body'] ?? data['message'] ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                  )
                else
                  Text(
                    data['body'] ?? data['message'] ?? '',
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                const SizedBox(height: 16),
                if (!isAnnouncement) ...[
                  if (data['sellerName'] != null) ...[
                    _buildDetailRow('Seller', data['sellerName']),
                  ],
                  if (data['customerName'] != null) ...[
                    _buildDetailRow('Customer', data['customerName']),
                  ],
                  if (data['productName'] != null) ...[
                    _buildDetailRow('Product', data['productName']),
                  ],
                  if (data['quantity'] != null) ...[
                    _buildDetailRow('Quantity', '${data['quantity']}'),
                  ],
                  if (data['totalAmount'] != null) ...[
                    _buildDetailRow(
                        'Amount', '₱${data['totalAmount'].toStringAsFixed(2)}'),
                  ],
                  if (data['paymentMethod'] != null) ...[
                    _buildDetailRow('Payment', data['paymentMethod']),
                  ],
                  if (data['deliveryMethod'] != null) ...[
                    _buildDetailRow('Delivery', data['deliveryMethod']),
                  ],
                ],
                if (data['timestamp'] != null) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTimestamp(data['timestamp']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Close',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color:
                      isAnnouncement ? const Color(0xFF1890FF) : Colors.green,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
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
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      );
    }

    if (_auth.currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.notifications_off,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please log in to view your notifications',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Log In'),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isSeller ? ' Notifications' : 'Notifications'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadUserInfo,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadUserInfo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCooperative
            ? 'Cooperative Notifications'
            : _isSeller
                ? 'Seller Notifications'
                : 'Notifications'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserInfo,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSeller
                        ? 'When customers order your products, you\'ll see notifications here'
                        : 'When you place orders, you\'ll see updates here',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadUserInfo(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final notificationType =
                      notification['type'] ?? 'order_status';
                  final isAnnouncement = notificationType == 'announcement';
                  final isUnread =
                      _isSeller && notification['status'] == 'unread';
                  final isNewOrder =
                      _isSeller && notificationType == 'new_order';
                  final needsApproval =
                      _isSeller && notification['needsApproval'] == true;
                  final isApproved =
                      !_isSeller && notification['status'] == 'approved';
                  final isSellerApproved =
                      _isSeller && notificationType == 'order_approved';
                  final isSellerDeclined =
                      _isSeller && notificationType == 'order_declined';
                  final isSellerStatusApproved =
                      notificationType == 'seller_status' &&
                          notification['status'] == 'approved';
                  final isSellerStatusRejected =
                      notificationType == 'seller_status' &&
                          notification['status'] == 'rejected';

                  // Determine card styling based on notification type
                  Color? cardColor;
                  Color? borderColor;
                  double elevation;

                  if (isAnnouncement) {
                    cardColor = const Color(0xFF1890FF).withOpacity(0.08);
                    borderColor = const Color(0xFF1890FF);
                    elevation = 4;
                  } else if (isSellerStatusApproved) {
                    cardColor = Colors.green.shade50;
                    borderColor = Colors.green.shade400;
                    elevation = 4;
                  } else if (isSellerStatusRejected) {
                    cardColor = Colors.red.shade50;
                    borderColor = Colors.red.shade400;
                    elevation = 4;
                  } else if (needsApproval) {
                    cardColor = Colors.amber.shade50;
                    borderColor = Colors.amber;
                    elevation = 3;
                  } else if (isApproved || isSellerApproved) {
                    cardColor = Colors.green.shade50;
                    borderColor = Colors.green.shade300;
                    elevation = 3;
                  } else if (isSellerDeclined) {
                    cardColor = Colors.red.shade50;
                    borderColor = Colors.red.shade300;
                    elevation = 3;
                  } else if (isNewOrder) {
                    cardColor = Colors.orange.shade50;
                    borderColor = Colors.orange;
                    elevation = 3;
                  } else {
                    cardColor = null;
                    borderColor = null;
                    elevation = 1;
                  }

                  return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      elevation: elevation,
                      color: cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: borderColor != null
                            ? BorderSide(
                                color: borderColor,
                                width: isAnnouncement ? 2 : 1.5)
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        onTap: () {
                          // Handle different notification types
                          if (isAnnouncement) {
                            _showNotificationDetails(notification);
                          } else if (_isCooperative ||
                              notification['isCooperativeNotification'] ==
                                  true) {
                            _showNotificationDetails(notification);
                          } else if (notification.containsKey('orderId')) {
                            print(
                                'Notification tapped: $notificationType - ${notification['status']}');
                            try {
                              if (_isSeller &&
                                  (notificationType == 'new_order' ||
                                      notification['status'] == 'unread' ||
                                      notification['status'] == 'pending')) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ApprovalScreen(
                                      orderId: notification['orderId'],
                                      notificationData: notification,
                                    ),
                                  ),
                                ).then((result) {
                                  if (result == 'approved' ||
                                      result == 'declined') {
                                    _loadUserInfo();
                                  }
                                });
                              } else if (_isSeller &&
                                  (notificationType == 'order_approved' ||
                                      notificationType == 'order_declined')) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OrderStatusScreen(
                                      orderId: notification['orderId'],
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OrderStatusScreen(
                                      orderId: notification['orderId'],
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              print(
                                  'Error navigating to order details screen: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Error viewing order details: $e'),
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          } else {
                            print(
                                'No orderId found in notification: $notification');
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _getNotificationIcon(
                                notification['type'] ?? 'order_status',
                                notification['status'] ?? 'pending',
                                notification,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Badge row
                                    Row(
                                      children: [
                                        if (isAnnouncement)
                                          _buildBadge('📢 ANNOUNCEMENT',
                                              const Color(0xFF1890FF)),
                                        if (isUnread && !isAnnouncement)
                                          _buildBadge('NEW', Colors.green),
                                        if (isApproved)
                                          _buildBadge('APPROVED', Colors.green),
                                        if (isSellerApproved)
                                          _buildBadge(
                                              'YOU APPROVED', Colors.green),
                                        if (isSellerDeclined)
                                          _buildBadge(
                                              'YOU DECLINED', Colors.red),
                                        if (isSellerStatusApproved)
                                          _buildBadge('✅ APPLICATION APPROVED',
                                              Colors.green),
                                        if (isSellerStatusRejected)
                                          _buildBadge('❌ APPLICATION REJECTED',
                                              Colors.red),
                                        if (isNewOrder && !isAnnouncement)
                                          _buildBadge(
                                              'NEW ORDER', Colors.orange),
                                        if (needsApproval)
                                          _buildBadge(
                                              'NEEDS APPROVAL', Colors.amber),
                                      ],
                                    ),
                                    if (isAnnouncement ||
                                        isUnread ||
                                        isNewOrder ||
                                        needsApproval ||
                                        isApproved ||
                                        isSellerApproved ||
                                        isSellerDeclined ||
                                        isSellerStatusApproved ||
                                        isSellerStatusRejected)
                                      const SizedBox(height: 8),

                                    // Title
                                    Text(
                                      notification['title'] ??
                                          notification['message'] ??
                                          notification['body'] ??
                                          'Notification',
                                      style: TextStyle(
                                        fontWeight: isAnnouncement || isUnread
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontSize: isAnnouncement ? 16 : 15,
                                        color: isAnnouncement
                                            ? const Color(0xFF1890FF)
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),

                                    // Message/Body
                                    if (notification.containsKey('body') &&
                                        notification['title'] != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          notification['body'],
                                          style: TextStyle(
                                            color: isAnnouncement
                                                ? Colors.black87
                                                : Colors.grey[700],
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                          maxLines: isAnnouncement ? 3 : 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),

                                    // Product details (for non-announcement notifications)
                                    if (!isAnnouncement) ...[
                                      if (notification
                                          .containsKey('productName'))
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                  Icons.inventory_2_outlined,
                                                  size: 14,
                                                  color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  notification['productName'],
                                                  style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 13),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (notification
                                              .containsKey('quantity') &&
                                          notification
                                              .containsKey('totalAmount'))
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                  Icons.shopping_cart_outlined,
                                                  size: 14,
                                                  color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Qty: ${notification['quantity']} • ₱${notification['totalAmount'].toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],

                                    // Timestamp
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time,
                                            size: 12, color: Colors.grey[400]),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatTimestamp(
                                              notification['timestamp']),
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Arrow icon for actionable notifications
                              if (!isAnnouncement &&
                                  notification.containsKey('orderId'))
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey[400],
                                  size: 16,
                                ),
                              if (isAnnouncement)
                                Icon(
                                  Icons.info_outline,
                                  color:
                                      const Color(0xFF1890FF).withOpacity(0.5),
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ));
                },
              ),
            ),
    );
  }
}
