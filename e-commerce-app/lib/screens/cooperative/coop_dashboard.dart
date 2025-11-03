import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'coop_order_details.dart';
import 'coop_payment_management.dart';

/// Cooperative Dashboard for managing deliveries and payments
/// This dashboard allows cooperatives to:
/// - View all orders (Cooperative Delivery and Pickup at Coop)
/// - Manage delivery status
/// - Track payments
/// - Handle order fulfillment
class CoopDashboard extends StatefulWidget {
  const CoopDashboard({Key? key}) : super(key: key);

  @override
  State<CoopDashboard> createState() => _CoopDashboardState();
}

class _CoopDashboardState extends State<CoopDashboard>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TabController _tabController;
  bool _isLoading = true;
  bool _hasAccess = false;
  String _accessDeniedReason = '';
  Map<String, dynamic> _stats = {};

  String _selectedOrderStatus = 'All';

  final List<String> _orderStatuses = [
    'All',
    'pending',
    'processing',
    'shipped',
    'delivered'
  ];

  // Notification listener
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  int _unreadNotificationCount = 0;
  List<Map<String, dynamic>> _recentNotifications = [];
  Set<String> _shownNotificationIds =
      {}; // Track which notifications we've already shown popups for

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _checkAccess();
    _setupNotificationListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  /// Check if current user has cooperative or admin role
  Future<void> _checkAccess() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;

      if (user == null) {
        setState(() {
          _hasAccess = false;
          _accessDeniedReason = 'Not logged in';
          _isLoading = false;
        });
        return;
      }

      // Get user data from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        setState(() {
          _hasAccess = false;
          _accessDeniedReason = 'User data not found';
          _isLoading = false;
        });
        return;
      }

      final userData = userDoc.data()!;
      final userRole = userData['role'] ?? '';

      // Only allow admin or cooperative role
      if (userRole == 'admin' || userRole == 'cooperative') {
        setState(() {
          _hasAccess = true;
          _isLoading = false;
        });
        // Load dashboard data
        _loadDashboardStats();
      } else {
        setState(() {
          _hasAccess = false;
          _accessDeniedReason =
              'Only cooperative staff and administrators can access this dashboard.\n\nYour current role: ${userRole.isEmpty ? "buyer" : userRole}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasAccess = false;
        _accessDeniedReason = 'Error verifying access: $e';
        _isLoading = false;
      });
    }
  }

  /// Setup real-time notification listener
  void _setupNotificationListener() {
    final user = _auth.currentUser;
    if (user == null) {
      print('Cannot setup notification listener: No user logged in');
      return;
    }

    print('Setting up notification listener for user: ${user.uid}');

    // Try compound query first (requires index)
    _notificationSubscription = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      print(
          'Notification snapshot received: ${snapshot.docs.length} unread notifications');

      if (snapshot.docs.isEmpty) {
        setState(() {
          _unreadNotificationCount = 0;
          _recentNotifications = [];
        });
        return;
      }

      setState(() {
        _unreadNotificationCount = snapshot.docs.length;
        _recentNotifications = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });

      // Show popup only for NEW notifications (ones we haven't shown before)
      for (var doc in snapshot.docs) {
        final notificationId = doc.id;

        // Only show popup if we haven't shown this notification before
        if (!_shownNotificationIds.contains(notificationId)) {
          final notificationData = doc.data();
          print(
              'Showing popup for new notification: ${notificationData['title']}');

          _showNotificationPopup(
            title: notificationData['title'] ?? 'New Notification',
            body: notificationData['body'] ?? '',
            notificationId: notificationId,
            payload: notificationData['payload'],
          );

          // Mark this notification as shown
          _shownNotificationIds.add(notificationId);
        }
      }
    }, onError: (error) {
      print('Error in notification listener: $error');
      // If compound query fails (index not ready), try simple query
      if (error.toString().contains('index')) {
        print('Firestore index not ready, using fallback query');
        _setupFallbackNotificationListener();
      }
    });
  }

  /// Fallback notification listener without orderBy (doesn't need index)
  void _setupFallbackNotificationListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    print('Setting up FALLBACK notification listener (no index required)');

    _notificationSubscription = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      print(
          'Fallback notification snapshot: ${snapshot.docs.length} unread notifications');

      if (snapshot.docs.isEmpty) {
        setState(() {
          _unreadNotificationCount = 0;
          _recentNotifications = [];
        });
        return;
      }

      // Manually sort by createdAt since we can't use orderBy
      var sortedDocs = snapshot.docs.toList();
      sortedDocs.sort((a, b) {
        var aTime = a.data()['createdAt'] as Timestamp?;
        var bTime = b.data()['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // descending
      });

      setState(() {
        _unreadNotificationCount = sortedDocs.length;
        _recentNotifications = sortedDocs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });

      // Show popup only for NEW notifications
      for (var doc in sortedDocs) {
        final notificationId = doc.id;

        if (!_shownNotificationIds.contains(notificationId)) {
          final notificationData = doc.data();
          print(
              'Showing popup for new notification: ${notificationData['title']}');

          _showNotificationPopup(
            title: notificationData['title'] ?? 'New Notification',
            body: notificationData['body'] ?? '',
            notificationId: notificationId,
            payload: notificationData['payload'],
          );

          _shownNotificationIds.add(notificationId);
        }
      }
    }, onError: (error) {
      print('Error in fallback notification listener: $error');
    });
  }

  /// Show notification popup as enhanced SnackBar
  void _showNotificationPopup({
    required String title,
    required String body,
    required String notificationId,
    String? payload,
  }) {
    if (!mounted) return;

    // Parse notification type from title or payload
    String notificationType = 'general';
    if (title.contains('Product')) notificationType = 'product';
    if (title.contains('Order')) notificationType = 'order';
    if (title.contains('Payment')) notificationType = 'payment';

    // Get icon and color based on type
    IconData notificationIcon = Icons.notifications_active;
    Color notificationColor = Colors.green.shade700;

    switch (notificationType) {
      case 'product':
        notificationIcon = Icons.inventory_2_rounded;
        notificationColor = Colors.blue.shade700;
        break;
      case 'order':
        notificationIcon = Icons.shopping_cart_rounded;
        notificationColor = Colors.orange.shade700;
        break;
      case 'payment':
        notificationIcon = Icons.payment_rounded;
        notificationColor = Colors.purple.shade700;
        break;
      default:
        notificationIcon = Icons.notifications_active_rounded;
        notificationColor = Colors.green.shade700;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: InkWell(
          onTap: () async {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            await _markNotificationAsRead(notificationId);
            // Open notifications list
            _showNotificationsList();
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon with circular background
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    notificationIcon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with emphasis
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6),
                      // Body with better formatting - increased maxLines for product details
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.95),
                          height: 1.4,
                        ),
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      // Time indicator
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Just now',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                // Action button
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          await _markNotificationAsRead(notificationId);
                          // Open notifications list
                          _showNotificationsList();
                        },
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'VIEW',
                            style: TextStyle(
                              color: notificationColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    // Dismiss button
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      },
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withOpacity(0.7),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        backgroundColor: notificationColor,
        duration: Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.all(16),
        elevation: 8,
        padding: EdgeInsets.all(12),
      ),
    );
  }

  /// Mark notification as read
  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Show notifications list dialog with enhanced design
  void _showNotificationsList() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(maxHeight: 600),
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade700,
                              Colors.green.shade500
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.notifications_active_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Notifications',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (_recentNotifications.isNotEmpty)
                                        Text(
                                          '${_recentNotifications.length} unread',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.8),
                                            fontSize: 14,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, color: Colors.white),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            // Tabs
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TabBar(
                                labelColor: Colors.white,
                                unselectedLabelColor:
                                    Colors.white.withOpacity(0.6),
                                indicator: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                tabs: [
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.circle, size: 8),
                                        SizedBox(width: 8),
                                        Text('Unread Notifications'),
                                      ],
                                    ),
                                  ),
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.done_all, size: 16),
                                        SizedBox(width: 8),
                                        Text('Read Notifications'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Content with TabBarView
                      Flexible(
                        child: TabBarView(
                          children: [
                            // Unread notifications
                            _buildNotificationsTabContent(
                              unread: true,
                              setState: setState,
                            ),
                            // Read notifications
                            _buildNotificationsTabContent(
                              unread: false,
                              setState: setState,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Build content for notifications tab (unread or read)
  Widget _buildNotificationsTabContent({
    required bool unread,
    required StateSetter setState,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .where('read', isEqualTo: !unread)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            message: unread
                ? 'No unread notifications\nYou\'re all caught up!'
                : 'No read notifications yet',
          );
        }

        final notifications = snapshot.data!.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          };
        }).toList();

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.all(16),
                itemCount: notifications.length,
                separatorBuilder: (context, index) => SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _buildNotificationCard(
                    notification,
                    showReadStatus: !unread,
                  );
                },
              ),
            ),
            // Footer actions for unread tab
            if (unread && notifications.isNotEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          for (var notification in notifications) {
                            await _markNotificationAsRead(notification['id']);
                          }
                        },
                        icon: Icon(Icons.done_all_rounded, size: 18),
                        label: Text('Mark All Read'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          side: BorderSide(color: Colors.green.shade700),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// Build empty state for notifications
  Widget _buildEmptyState({String? message}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              message ??
                  'You\'re all caught up!\nNew notifications will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build individual notification card
  Widget _buildNotificationCard(
    Map<String, dynamic> notification, {
    bool showReadStatus = false,
  }) {
    // Determine notification type and styling
    String type = notification['type'] ?? 'general';
    IconData icon = Icons.notifications_rounded;
    Color iconColor = Colors.blue;

    switch (type) {
      case 'product_approval':
        icon = Icons.inventory_2_rounded;
        iconColor = Colors.blue.shade600;
        break;
      case 'order_update':
        icon = Icons.shopping_cart_rounded;
        iconColor = Colors.orange.shade600;
        break;
      case 'payment':
        icon = Icons.payment_rounded;
        iconColor = Colors.purple.shade600;
        break;
      default:
        icon = Icons.notifications_active_rounded;
        iconColor = Colors.green.shade600;
    }

    String priority = notification['priority'] ?? 'normal';
    bool isHighPriority = priority == 'high';
    bool isRead = notification['read'] == true;

    return InkWell(
      onTap: () async {
        if (!isRead) {
          await _markNotificationAsRead(notification['id']);
        }
        Navigator.pop(context);
        _tabController.animateTo(1);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighPriority
                ? iconColor.withOpacity(0.3)
                : Colors.grey.shade200,
            width: isHighPriority ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(isRead ? 0.05 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isRead ? iconColor.withOpacity(0.5) : iconColor,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification['title'] ?? 'Notification',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isRead
                                ? Colors.grey.shade600
                                : Colors.grey.shade900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isHighPriority)
                        Container(
                          margin: EdgeInsets.only(left: 8),
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'HIGH',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 6),
                  // Body - increased maxLines to show full product details
                  Text(
                    notification['body'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isRead ? Colors.grey.shade500 : Colors.grey.shade600,
                      height: 1.5,
                    ),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  // Footer
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(width: 4),
                      Text(
                        _formatTimestamp(notification['createdAt']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      Spacer(),
                      // Action button
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format timestamp for display
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else {
        return 'Just now';
      }

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
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return 'Just now';
    }
  }

  Future<void> _loadDashboardStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get all sellers (farmers) belonging to this cooperative
      final sellersSnapshot = await _firestore
          .collection('users')
          .where('cooperativeId', isEqualTo: currentUser.uid)
          .where('role', isEqualTo: 'seller')
          .get();

      // Extract seller IDs
      final farmerIds = sellersSnapshot.docs.map((doc) => doc.id).toList();

      if (farmerIds.isEmpty) {
        // No farmers assigned to this cooperative yet
        setState(() {
          _stats = {
            'totalOrders': 0,
            'pendingOrders': 0,
            'processingOrders': 0,
            'shippedOrders': 0,
            'deliveredOrders': 0,
            'unpaidCOD': 0,
            'totalRevenue': 0.0,
            'pendingPayments': 0.0,
          };
          _isLoading = false;
        });
        return;
      }

      // Get orders from these farmers only
      // Note: Firestore 'in' operator has a limit of 10 items, so we need to batch
      List<QuerySnapshot> ordersBatches = [];
      for (int i = 0; i < farmerIds.length; i += 10) {
        final batchIds = farmerIds.sublist(
          i,
          i + 10 > farmerIds.length ? farmerIds.length : i + 10,
        );
        final batchSnapshot = await _firestore
            .collection('orders')
            .where('sellerId', whereIn: batchIds)
            .get();
        ordersBatches.add(batchSnapshot);
      }

      int totalOrders = 0;
      int pendingOrders = 0;
      int processingOrders = 0;
      int shippedOrders = 0;
      int deliveredOrders = 0;
      int unpaidCOD = 0;
      double totalRevenue = 0.0;
      double pendingPayments = 0.0;

      for (var batch in ordersBatches) {
        totalOrders += batch.docs.length;

        for (var doc in batch.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'pending';
          final paymentMethod = data['paymentMethod'] ?? '';
          final totalAmount = (data['totalAmount'] ?? 0.0).toDouble();

          // Count by status (matching seller side)
          if (status == 'pending') {
            pendingOrders++;
          } else if (status == 'processing') {
            processingOrders++;
          } else if (status == 'shipped') {
            shippedOrders++;
          } else if (status == 'delivered') {
            deliveredOrders++;
            totalRevenue += totalAmount;
          }

          // Track Cash on Delivery payments
          if (paymentMethod == 'Cash on Delivery' && status != 'delivered') {
            unpaidCOD++;
            pendingPayments += totalAmount;
          }
        }
      }

      setState(() {
        _stats = {
          'totalOrders': totalOrders,
          'pendingOrders': pendingOrders,
          'processingOrders': processingOrders,
          'shippedOrders': shippedOrders,
          'deliveredOrders': deliveredOrders,
          'unpaidCOD': unpaidCOD,
          'totalRevenue': totalRevenue,
          'pendingPayments': pendingPayments,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard stats: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while checking access
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cooperative Dashboard'),
          backgroundColor: Colors.green.shade700,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show access denied screen if user doesn't have permission
    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cooperative Dashboard'),
          backgroundColor: Colors.red.shade700,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.block,
                  size: 80,
                  color: Colors.red.shade700,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _accessDeniedReason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            const Text(
                              'How to Get Access',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '1. Contact your administrator\n'
                          '2. Request cooperative staff access\n'
                          '3. Admin will assign the "cooperative" role to your account',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show dashboard if access granted
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooperative Dashboard'),
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          // Notification bell with badge
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications, color: Colors.white),
                  onPressed: _showNotificationsList,
                ),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadNotificationCount > 9
                            ? '9+'
                            : '$_unreadNotificationCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
          isScrollable: true,
          padding: EdgeInsets.zero,
          indicatorPadding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.only(left: 0, right: 16),
          tabs: const [
            Tab(icon: Icon(Icons.person_add_alt), text: 'Sellers'),
            Tab(icon: Icon(Icons.inventory_2), text: 'Products'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Orders'),
            Tab(icon: Icon(Icons.local_shipping), text: 'Delivery'),
            Tab(icon: Icon(Icons.payments), text: 'Payments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSellersTab(),
          _buildProductsTab(),
          _buildOrdersTab(),
          _buildDeliveryTab(),
          _buildPaymentsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadDashboardStats,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
    );
  }

  // ========== RESPONSIBILITY 1: SELLER ACCOUNT MANAGEMENT ==========
  Widget _buildSellersTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt,
                      size: 40, color: Colors.green),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Farmer/Seller Management',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Approve registrations & manage accounts',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Sellers List
          const Text(
            'All Sellers',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .where('role', isEqualTo: 'seller')
                .where('cooperativeId',
                    isEqualTo: _auth.currentUser?.uid) // Filter by cooperative
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Error: ${snapshot.error}'),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              var sellers = snapshot.data!.docs;

              if (sellers.isEmpty) {
                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text('No sellers found'),
                      ],
                    ),
                  ),
                );
              }

              // Count sellers by status
              int pending = sellers.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['status'] ?? 'pending') == 'pending';
              }).length;

              int active = sellers.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['status'] ?? '') == 'approved';
              }).length;

              int inactive = sellers.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['status'] ?? '') == 'rejected' ||
                    (data['status'] ?? '') == 'inactive';
              }).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatItem(
                              'Pending',
                              pending.toString(),
                              Icons.hourglass_empty,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatItem(
                              'Active',
                              active.toString(),
                              Icons.check_circle,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatItem(
                              'Inactive',
                              inactive.toString(),
                              Icons.cancel,
                              Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sellers List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sellers.length,
                    itemBuilder: (context, index) {
                      final sellerData =
                          sellers[index].data() as Map<String, dynamic>;
                      final sellerId = sellers[index].id;
                      return _buildSellerCard(sellerData, sellerId);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Build seller card
  Widget _buildSellerCard(Map<String, dynamic> seller, String sellerId) {
    final status = seller['status'] ?? 'pending';
    final name = seller['name'] ?? 'Unknown';
    final email = seller['email'] ?? '';
    final phone = seller['phone'] ?? 'N/A';

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(Icons.person, color: statusColor),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(email, style: const TextStyle(fontSize: 12)),
            Text('Phone: $phone', style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 4),
              Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        onTap: () => _showSellerDetails(seller, sellerId),
      ),
    );
  }

  // Show seller details dialog
  void _showSellerDetails(Map<String, dynamic> seller, String sellerId) {
    final status = seller['status'] ?? 'pending';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(seller['name'] ?? 'Seller Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', seller['email'] ?? 'N/A'),
              _buildDetailRow('Phone', seller['phone'] ?? 'N/A'),
              _buildDetailRow('Status', status.toUpperCase()),
              _buildDetailRow(
                  'Registered',
                  seller['createdAt']?.toDate().toString().split(' ')[0] ??
                      'N/A'),
            ],
          ),
        ),
        actions: [
          if (status == 'pending') ...[
            TextButton.icon(
              onPressed: () async {
                await _updateSellerStatus(sellerId, 'rejected');
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.cancel, color: Colors.red),
              label: const Text('Reject'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await _updateSellerStatus(sellerId, 'approved');
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ] else ...[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Update seller status
  Future<void> _updateSellerStatus(String sellerId, String newStatus) async {
    try {
      // Update status in users collection
      await _firestore.collection('users').doc(sellerId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also update status in sellers collection if exists
      try {
        final sellersQuery = await _firestore
            .collection('sellers')
            .where('userId', isEqualTo: sellerId)
            .limit(1)
            .get();

        if (sellersQuery.docs.isNotEmpty) {
          await _firestore
              .collection('sellers')
              .doc(sellersQuery.docs.first.id)
              .update({
            'status': newStatus,
            'verified': newStatus == 'approved',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        print('Error updating sellers collection: $e');
      }

      // Send notification to seller - using standard 'notifications' collection
      await _firestore.collection('notifications').add({
        'title': newStatus == 'approved'
            ? 'Application Approved ✅'
            : 'Application Not Approved',
        'message': newStatus == 'approved'
            ? 'Congratulations! Your seller application has been approved by the cooperative. You can now start listing products.'
            : 'Your seller application was not approved. Please contact the cooperative for more information.',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'seller_status',
        'read': false,
        'userId': sellerId,
        'priority': 'high',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Seller ${newStatus == 'approved' ? 'approved' : 'rejected'} successfully'),
            backgroundColor:
                newStatus == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating seller: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ========== RESPONSIBILITY 2: PRODUCT MANAGEMENT ==========
  Widget _buildProductsTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2, size: 40, color: Colors.green),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Management',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Review & approve product listings',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick Stats
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'Pending Review',
                          '0',
                          Icons.pending,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatItem(
                          'Approved',
                          '0',
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatItem(
                          'Rejected',
                          '0',
                          Icons.cancel,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Products List
          const Text(
            'All Products',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('products')
                .where('cooperativeId',
                    isEqualTo: _auth.currentUser?.uid) // Filter by cooperative
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Error: ${snapshot.error}'),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              var products = snapshot.data!.docs;

              if (products.isEmpty) {
                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('No products found for your cooperative'),
                        const SizedBox(height: 8),
                        Text(
                          'Products will appear here when sellers upload them',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Sort products: pending first, then by creation date
              products.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aStatus = aData['status'] ?? 'pending';
                final bStatus = bData['status'] ?? 'pending';

                // Pending items first
                if (aStatus == 'pending' && bStatus != 'pending') return -1;
                if (aStatus != 'pending' && bStatus == 'pending') return 1;

                // Then sort by creation date (newest first)
                final aTime = aData['createdAt'] as Timestamp?;
                final bTime = bData['createdAt'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

              // Count products by status
              int pending = products.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['status'] ?? 'pending') == 'pending';
              }).length;

              int approved = products.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['status'] ?? '') == 'approved';
              }).length;

              int rejected = products.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['status'] ?? '') == 'rejected';
              }).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Update Stats in the Card above
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Live Product Statistics',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  'Pending Review',
                                  pending.toString(),
                                  Icons.pending,
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatItem(
                                  'Approved',
                                  approved.toString(),
                                  Icons.check_circle,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatItem(
                                  'Rejected',
                                  rejected.toString(),
                                  Icons.cancel,
                                  Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Pending Products Alert
                  if (pending > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.notification_important,
                              color: Colors.orange.shade700, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You have $pending product${pending > 1 ? 's' : ''} waiting for approval. Tap to review and approve/reject.',
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Products List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final productData =
                          products[index].data() as Map<String, dynamic>;
                      final productId = products[index].id;
                      return _buildProductCard(productData, productId);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Build product card
  Widget _buildProductCard(Map<String, dynamic> product, String productId) {
    final status = product['status'] ?? 'pending';
    final name = product['name'] ?? 'Unknown Product';
    final price = product['price'] ?? 0;
    final unit = product['unit'] ?? 'kg';
    final sellerId = product['sellerId'] ?? '';
    final imageUrl = product['imageUrl']; // Use imageUrl field directly

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl != null
              ? Image.network(
                  imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported),
                  ),
                )
              : Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.inventory_2),
                ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '₱${price.toStringAsFixed(2)} per $unit',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Seller ID: ${sellerId.length > 8 ? sellerId.substring(0, 8) : sellerId}...',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 4),
              Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        onTap: () => _showProductDetails(product, productId),
      ),
    );
  }

  // Show product details dialog with redesigned modern UI
  void _showProductDetails(Map<String, dynamic> product, String productId) {
    final status = product['status'] ?? 'pending';

    // Get all images (multiple images support)
    final imageUrls = product['imageUrls'] as List<dynamic>?;
    final imageUrl = product['imageUrl']; // Fallback to single image

    // Create image list - prioritize imageUrls array, fallback to single imageUrl
    final List<String> images = [];
    if (imageUrls != null && imageUrls.isNotEmpty) {
      images.addAll(imageUrls.map((e) => e.toString()));
    } else if (imageUrl != null && imageUrl.toString().isNotEmpty) {
      images.add(imageUrl.toString());
    }

    // Get delivery options as list
    final deliveryOptions = product['deliveryOptions'] as List<dynamic>?;
    final deliveryText = deliveryOptions != null && deliveryOptions.isNotEmpty
        ? deliveryOptions.join(', ')
        : 'Not specified';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Product Name and Status Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: status == 'approved'
                        ? [Colors.green.shade600, Colors.green.shade400]
                        : status == 'rejected'
                            ? [Colors.red.shade600, Colors.red.shade400]
                            : [Colors.orange.shade600, Colors.orange.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        status == 'approved'
                            ? Icons.verified
                            : status == 'rejected'
                                ? Icons.block
                                : Icons.pending_actions,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'] ?? 'Product Details',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Images Gallery with enhanced styling
                      if (images.isNotEmpty) ...[
                        _buildImageGallery(
                            images, product['category'] ?? 'N/A'),
                        const SizedBox(height: 20),
                      ],

                      // Price and Quantity Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade50,
                              Colors.green.shade100
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.attach_money,
                                          color: Colors.green.shade700,
                                          size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Price',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₱${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                  Text(
                                    'per ${product['unit'] ?? 'unit'}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 50,
                              color: Colors.green.shade300,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.inventory_2,
                                          color: Colors.green.shade700,
                                          size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Available',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${product['quantity'] ?? 0}',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                  Text(
                                    product['unit'] ?? 'units',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Order Type Badge
                      Row(
                        children: [
                          Icon(Icons.shopping_cart,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'Order Type:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              product['orderType'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Description Card
                      _buildInfoCard(
                        title: 'Description',
                        icon: Icons.description,
                        color: Colors.blue,
                        child: Text(
                          product['description'] ?? 'No description provided',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                              height: 1.4),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Delivery & Location Card
                      _buildInfoCard(
                        title: 'Delivery & Location',
                        icon: Icons.local_shipping,
                        color: Colors.purple,
                        child: Column(
                          children: [
                            _buildIconDetailRow(
                              Icons.location_on,
                              'Pickup Location',
                              product['pickupLocation'] ?? 'N/A',
                              Colors.purple,
                            ),
                            const SizedBox(height: 8),
                            _buildIconDetailRow(
                              Icons.delivery_dining,
                              'Delivery Options',
                              deliveryText,
                              Colors.purple,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Seller Information Card
                      _buildInfoCard(
                        title: 'Seller Information',
                        icon: Icons.person,
                        color: Colors.orange,
                        child: Column(
                          children: [
                            _buildIconDetailRow(
                              Icons.person_outline,
                              'Name',
                              product['sellerName'] ?? 'Unknown',
                              Colors.orange,
                            ),
                            const SizedBox(height: 8),
                            _buildIconDetailRow(
                              Icons.email_outlined,
                              'Email',
                              product['sellerEmail'] ?? 'N/A',
                              Colors.orange,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Dates Information Card
                      _buildInfoCard(
                        title: 'Important Dates',
                        icon: Icons.event,
                        color: Colors.teal,
                        child: Column(
                          children: [
                            _buildIconDetailRow(
                              Icons.agriculture,
                              'Harvest Date',
                              product['harvestDate'] != null
                                  ? (product['harvestDate'] as Timestamp)
                                      .toDate()
                                      .toString()
                                      .split(' ')[0]
                                  : 'N/A',
                              Colors.teal,
                            ),
                            if (product['orderType'] == 'Pre Order' &&
                                product['estimatedAvailabilityDate'] !=
                                    null) ...[
                              const SizedBox(height: 8),
                              _buildIconDetailRow(
                                Icons.schedule,
                                'Est. Availability',
                                (product['estimatedAvailabilityDate']
                                        as Timestamp)
                                    .toDate()
                                    .toString()
                                    .split(' ')[0],
                                Colors.teal,
                              ),
                            ],
                            const SizedBox(height: 8),
                            _buildIconDetailRow(
                              Icons.calendar_today,
                              'Listed On',
                              product['createdAt']
                                      ?.toDate()
                                      .toString()
                                      .split(' ')[0] ??
                                  'N/A',
                              Colors.teal,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons with enhanced styling
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (status == 'pending') ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _updateProductStatus(productId, 'rejected');
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side:
                                const BorderSide(color: Colors.red, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _updateProductStatus(productId, 'approved');
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build info cards
  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required MaterialColor color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color.shade700),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // Helper method to build icon detail rows
  Widget _buildIconDetailRow(
      IconData icon, String label, String value, MaterialColor color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to build image gallery with multiple images support
  Widget _buildImageGallery(List<String> images, String category) {
    if (images.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported,
                size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No images available',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // If only one image, display it directly
    if (images.length == 1) {
      return GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => _CoopFullScreenImageViewer(
                images: images,
                initialIndex: 0,
              ),
            ),
          );
        },
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.network(
                  images[0],
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.green,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image,
                            size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'Image not available',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Category badge overlay
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category,
                        size: 14, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Multiple images - use PageView with indicators
    return _ImageGalleryWidget(images: images, category: category);
  }

  // Update product status
  Future<void> _updateProductStatus(String productId, String newStatus) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      print('Current User ID: ${currentUser.uid}');
      print('Updating product: $productId to status: $newStatus');

      // Get product data to find seller
      final productDoc =
          await _firestore.collection('products').doc(productId).get();

      if (!productDoc.exists) {
        throw Exception('Product not found');
      }

      final productData = productDoc.data();
      if (productData == null) {
        throw Exception('Product data is empty');
      }

      final sellerId = productData['sellerId'] as String?;
      final productName = productData['name'] as String? ?? 'Product';
      final productCoopId = productData['cooperativeId'] as String?;

      print('Product Seller ID: $sellerId');
      print('Product Cooperative ID: $productCoopId');
      print('Current User ID: ${currentUser.uid}');

      // Verify this cooperative owns this product
      if (productCoopId != currentUser.uid) {
        throw Exception(
            'You do not have permission to approve this product. It belongs to another cooperative.');
      }

      // Update product status
      await _firestore.collection('products').doc(productId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'approvedBy': currentUser.uid,
        'approvedAt':
            newStatus == 'approved' ? FieldValue.serverTimestamp() : null,
      });

      print('Product status updated successfully');

      // Send notification to seller
      if (sellerId != null && sellerId.isNotEmpty) {
        try {
          await _firestore.collection('notifications').add({
            'title': newStatus == 'approved'
                ? 'Product Approved ✅'
                : 'Product Not Approved',
            'message': newStatus == 'approved'
                ? 'Your product "$productName" has been approved by the cooperative and is now live!'
                : 'Your product "$productName" was not approved. Please review and resubmit or contact the cooperative.',
            'createdAt': FieldValue.serverTimestamp(),
            'type': 'product_status',
            'read': false,
            'userId': sellerId,
            'productId': productId,
            'priority': 'medium',
          });
          print('Notification sent to seller');
        } catch (notificationError) {
          print('Failed to send notification: $notificationError');
          // Don't fail the whole operation if notification fails
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Product ${newStatus == 'approved' ? 'approved' : 'rejected'} successfully'),
            backgroundColor:
                newStatus == 'approved' ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error updating product status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ========== RESPONSIBILITY 3: ORDER MANAGEMENT ==========
  Widget _buildOrdersTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardStats,
      child: ListView(
        padding: const EdgeInsets.only(right: 16, top: 16, bottom: 16),
        children: [
          // Header Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.shopping_cart,
                      size: 40, color: Colors.green),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Management',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'View & coordinate all orders from your farmers',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick Stats
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'Pending',
                          _stats['pendingOrders']?.toString() ?? '0',
                          Icons.hourglass_empty,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatItem(
                          'Processing',
                          _stats['processingOrders']?.toString() ?? '0',
                          Icons.autorenew,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatItem(
                          'Shipped',
                          _stats['shippedOrders']?.toString() ?? '0',
                          Icons.local_shipping,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatItem(
                          'Delivered',
                          _stats['deliveredOrders']?.toString() ?? '0',
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Orders List
          const Text(
            'Farmer Orders (Real-time)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // First, get the list of farmer IDs, then stream their orders
          FutureBuilder<List<String>>(
            future: _getFarmerIds(),
            builder: (context, farmerSnapshot) {
              if (farmerSnapshot.hasError) {
                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child:
                        Text('Error loading farmers: ${farmerSnapshot.error}'),
                  ),
                );
              }

              if (farmerSnapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              final farmerIds = farmerSnapshot.data ?? [];

              if (farmerIds.isEmpty) {
                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.group_off,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                            'No farmers assigned to your cooperative yet'),
                        const SizedBox(height: 8),
                        const Text(
                          'Farmers will appear here once they register with your cooperative',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Stream orders from these farmers in real-time
              return _buildFarmerOrdersStream(farmerIds);
            },
          ),
        ],
      ),
    );
  }

  // Get farmer IDs assigned to this cooperative
  Future<List<String>> _getFarmerIds() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final sellersSnapshot = await _firestore
          .collection('users')
          .where('cooperativeId', isEqualTo: currentUser.uid)
          .where('role', isEqualTo: 'seller')
          .get();

      return sellersSnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error getting farmer IDs: $e');
      return [];
    }
  }

  // Build real-time stream of orders from farmers
  Widget _buildFarmerOrdersStream(List<String> farmerIds) {
    // Firestore 'in' operator limit is 10, so we need to handle batching
    if (farmerIds.length <= 10) {
      return StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('orders')
            .where('sellerId', whereIn: farmerIds)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // Sort in memory after receiving the data
            var sortedDocs = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTimestamp = aData['timestamp'] as Timestamp?;
                final bTimestamp = bData['timestamp'] as Timestamp?;
                if (aTimestamp == null || bTimestamp == null) return 0;
                return bTimestamp.compareTo(aTimestamp); // Most recent first
              });

            // Create a new AsyncSnapshot with sorted data
            final sortedSnapshot = AsyncSnapshot<QuerySnapshot>.withData(
              ConnectionState.done,
              snapshot.data!,
            );

            return _buildOrdersListSorted(sortedSnapshot, sortedDocs);
          }
          return _buildOrdersList(snapshot);
        },
      );
    } else {
      // For more than 10 farmers, we need to combine multiple streams
      // For simplicity, we'll use the first 10 and show a note
      return Column(
        children: [
          if (farmerIds.length > 10)
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Showing orders from your first 10 farmers (${farmerIds.length} total). Pull to refresh to see updated data.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('orders')
                .where('sellerId', whereIn: farmerIds.take(10).toList())
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                // Sort in memory after receiving the data
                var sortedDocs = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTimestamp = aData['timestamp'] as Timestamp?;
                    final bTimestamp = bData['timestamp'] as Timestamp?;
                    if (aTimestamp == null || bTimestamp == null) return 0;
                    return bTimestamp
                        .compareTo(aTimestamp); // Most recent first
                  });

                // Create a new AsyncSnapshot with sorted data
                final sortedSnapshot = AsyncSnapshot<QuerySnapshot>.withData(
                  ConnectionState.done,
                  snapshot.data!,
                );

                return _buildOrdersListSorted(sortedSnapshot, sortedDocs);
              }
              return _buildOrdersList(snapshot);
            },
          ),
        ],
      );
    }
  }

  // Build the orders list from sorted documents
  Widget _buildOrdersListSorted(AsyncSnapshot<QuerySnapshot> snapshot,
      List<QueryDocumentSnapshot> sortedDocs) {
    if (snapshot.hasError) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 12),
              Text('Error: ${snapshot.error}'),
              const SizedBox(height: 8),
              const Text(
                'Please try refreshing the page',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (sortedDocs.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('No orders yet from your farmers'),
              const SizedBox(height: 8),
              const Text(
                'Orders will appear here when buyers purchase from your farmers',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedDocs.length,
      itemBuilder: (context, index) {
        final order = sortedDocs[index].data() as Map<String, dynamic>;
        order['id'] = sortedDocs[index].id;
        return _buildOrderCard(order);
      },
    );
  }

  // Build the orders list from snapshot
  Widget _buildOrdersList(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (snapshot.hasError) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 12),
              Text('Error: ${snapshot.error}'),
              const SizedBox(height: 8),
              const Text(
                'Please try refreshing the page',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    var orders = snapshot.data?.docs ?? [];

    if (orders.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('No orders yet from your farmers'),
              const SizedBox(height: 8),
              const Text(
                'Orders will appear here when buyers purchase from your farmers',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index].data() as Map<String, dynamic>;
        order['id'] = orders[index].id;
        return _buildOrderCard(order);
      },
    );
  }

  // ========== RESPONSIBILITY 4: DELIVERY COORDINATION ==========
  Widget _buildDeliveryTab() {
    return _buildDeliveriesTab(); // Reuse existing deliveries tab
  }

  // Helper method for stat items
  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper widgets for cards
  Widget _buildPriorityCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Simple action button (white card style)
  Widget _buildLargeActionButton(
    String title,
    IconData icon,
    Color color,
    String badge,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 28, color: color),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Full width action button (simple card style)
  Widget _buildFullWidthActionButton(
    String title,
    IconData icon,
    Color color,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Status row for order overview
  Widget _buildStatusRow(
    String label,
    String value,
    IconData icon,
    Color color,
    String description,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // Financial row with icon
  Widget _buildFinancialRow(
    String label,
    String amount,
    IconData icon,
    Color color,
    String description,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ========== DELIVERIES TAB ==========
  Widget _buildDeliveriesTab() {
    return Column(
      children: [
        // Filters
        Container(
          padding:
              const EdgeInsets.only(right: 16, top: 16, bottom: 16, left: 16),
          color: Colors.grey.shade100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Deliveries',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      value: _selectedOrderStatus,
                      items: _orderStatuses.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status == 'All'
                              ? 'All Status'
                              : status.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedOrderStatus = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Order List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('orders')
                .where('deliveryMethod', isEqualTo: 'Cooperative Delivery')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var orders = snapshot.data!.docs;

              // Apply status filter
              if (_selectedOrderStatus != 'All') {
                orders = orders.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['status'] == _selectedOrderStatus;
                }).toList();
              }

              if (orders.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No delivery orders found'),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index].data() as Map<String, dynamic>;
                  order['id'] = orders[index].id;
                  return _buildOrderCard(order);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ========== PICKUPS TAB ==========
  Widget _buildPickupsTab() {
    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Pickups',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      value: _selectedOrderStatus,
                      items: _orderStatuses.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status == 'All'
                              ? 'All Status'
                              : status.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedOrderStatus = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Order List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('orders')
                .where('deliveryMethod', isEqualTo: 'Pickup at Coop')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var orders = snapshot.data!.docs;

              // Apply status filter
              if (_selectedOrderStatus != 'All') {
                orders = orders.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['status'] == _selectedOrderStatus;
                }).toList();
              }

              if (orders.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No pickup orders found'),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index].data() as Map<String, dynamic>;
                  order['id'] = orders[index].id;
                  return _buildOrderCard(order);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ========== PAYMENTS TAB ==========
  Widget _buildPaymentsTab() {
    return CoopPaymentManagement();
  }

  // ========== ORDER CARD WIDGET ==========
  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final paymentMethod = order['paymentMethod'] ?? 'Cash on Delivery';
    final deliveryMethod = order['deliveryMethod'] ?? '';
    final totalAmount = (order['totalAmount'] ?? 0.0).toDouble();
    final orderId = order['id'] ?? '';

    Color statusColor = _getStatusColor(status);
    IconData statusIcon = _getStatusIcon(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CoopOrderDetails(orderId: orderId),
            ),
          ).then((_) => _loadDashboardStats());
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Header with status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Order #${orderId.substring(0, 8).toUpperCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey.shade400),
                ],
              ),
            ),

            // Order Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.shopping_basket,
                            color: Colors.green.shade700, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Product',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              order['productName'] ?? 'Unknown Product',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Customer & Amount
                  Row(
                    children: [
                      Expanded(
                        child: _buildOrderDetailItem(
                          Icons.person_outline,
                          'Customer',
                          order['customerName'] ?? 'Unknown',
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildOrderDetailItem(
                          Icons.payments_outlined,
                          'Amount',
                          '₱${totalAmount.toStringAsFixed(2)}',
                          Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Delivery & Payment Method
                  Row(
                    children: [
                      Expanded(
                        child: _buildOrderDetailItem(
                          deliveryMethod == 'Pickup at Coop'
                              ? Icons.store_outlined
                              : Icons.local_shipping_outlined,
                          'Delivery',
                          deliveryMethod,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildOrderDetailItem(
                          Icons.payment,
                          'Payment',
                          paymentMethod,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),

                  // Contact & Address (if available)
                  if (order['customerContact'] != null ||
                      order['customerAddress'] != null) ...[
                    const SizedBox(height: 12),
                    if (order['customerContact'] != null)
                      _buildOrderDetailItem(
                        Icons.phone_outlined,
                        'Contact',
                        order['customerContact'],
                        Colors.teal,
                      ),
                    if (order['customerAddress'] != null) ...[
                      const SizedBox(height: 12),
                      _buildOrderDetailItem(
                        Icons.location_on_outlined,
                        'Address',
                        order['customerAddress'],
                        Colors.red,
                      ),
                    ],
                  ],

                  // Action Buttons
                  const SizedBox(height: 16),
                  _buildOrderActionButtons(orderId, status, deliveryMethod),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetailItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderActionButtons(
    String orderId,
    String status,
    String deliveryMethod,
  ) {
    List<Widget> buttons = [];

    // Pending orders can be started (moved to processing)
    if (status == 'pending') {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateOrderStatus(orderId, 'processing'),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Start Processing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      );
    }

    // Processing orders can be marked as shipped
    if (status == 'processing') {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateOrderStatus(orderId, 'shipped'),
            icon: const Icon(Icons.local_shipping, size: 18),
            label: const Text('Mark Shipped'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      );
    }

    // Shipped orders can be marked as delivered
    if (status == 'shipped') {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateOrderStatus(orderId, 'delivered'),
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('Mark Delivered'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        for (int i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          buttons[i],
        ],
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'processing':
        return Icons.autorenew;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to ${newStatus.toUpperCase()}'),
          backgroundColor: Colors.green,
        ),
      );

      _loadDashboardStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Stateful widget for image gallery with multiple images
class _ImageGalleryWidget extends StatefulWidget {
  final List<String> images;
  final String category;

  const _ImageGalleryWidget({
    Key? key,
    required this.images,
    required this.category,
  }) : super(key: key);

  @override
  State<_ImageGalleryWidget> createState() => _ImageGalleryWidgetState();
}

class _ImageGalleryWidgetState extends State<_ImageGalleryWidget> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: widget.images.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        _showFullScreenImage(context, index);
                      },
                      child: Image.network(
                        widget.images[index],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey.shade100,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: Colors.green,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade100,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image,
                                  size: 60, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                'Image ${index + 1} not available',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Category badge overlay
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category,
                        size: 14, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      widget.category,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Image counter badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '${_currentPage + 1}/${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Navigation arrows
            if (widget.images.length > 1) ...[
              // Previous button
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.chevron_left, color: Colors.black87),
                      onPressed: _currentPage > 0
                          ? () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                      color: _currentPage > 0 ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ),
              ),
              // Next button
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right,
                          color: Colors.black87),
                      onPressed: _currentPage < widget.images.length - 1
                          ? () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                      color: _currentPage < widget.images.length - 1
                          ? Colors.black87
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        // Page indicators (dots)
        if (widget.images.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.images.length,
              (index) => GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.green
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _CoopFullScreenImageViewer(
          images: widget.images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

// Full screen image viewer for coop dashboard
class _CoopFullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _CoopFullScreenImageViewer({
    Key? key,
    required this.images,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<_CoopFullScreenImageViewer> createState() =>
      _CoopFullScreenImageViewerState();
}

class _CoopFullScreenImageViewerState
    extends State<_CoopFullScreenImageViewer> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full screen PageView
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              return Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    widget.images[index],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 80,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // Image counter
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentPage + 1} / ${widget.images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Page indicators
          if (widget.images.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 32 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
