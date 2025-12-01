import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'coop_payment_management.dart';
import 'seller_review_screen.dart';
import 'cooperative_notification_screen.dart';
import '../notification_detail_screen.dart';
import '../../services/realtime_notification_service.dart';
import '../cooperative_messages_screen.dart';

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

  // Seller category filter
  String _selectedSellerCategory = 'All';

  // Track expanded orders
  Set<String> _expandedOrders = {};

  // Notification listener
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  StreamSubscription<QuerySnapshot>? _cooperativeNotificationSubscription;
  int _unreadNotificationCount = 0;
  List<Map<String, dynamic>> _recentNotifications = [];
  Set<String> _shownNotificationIds =
      {}; // Track which notifications we've already shown popups for
  Set<String> _shownCoopNotificationIds =
      {}; // Track cooperative notifications we've shown

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _checkAccess();
    _setupNotificationListener();
    _setupCooperativeNotificationListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notificationSubscription?.cancel();
    _cooperativeNotificationSubscription?.cancel();
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
    // Notification popups disabled - notifications only appear in the notification list
    return;
  }

  /// Setup real-time listener for cooperative notifications (seller applications)
  void _setupCooperativeNotificationListener() {
    final user = _auth.currentUser;
    if (user == null) {
      print(
          'Cannot setup cooperative notification listener: No user logged in');
      return;
    }

    print('Setting up cooperative notification listener for user: ${user.uid}');

    _cooperativeNotificationSubscription = _firestore
        .collection('cooperative_notifications')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      print(
          'Cooperative notification snapshot: ${snapshot.docs.length} notifications');

      for (var doc in snapshot.docs) {
        final notificationId = doc.id;
        final notificationData = doc.data();

        // Only show popup if we haven't shown this notification before
        if (!_shownCoopNotificationIds.contains(notificationId)) {
          print(
              '🔔 New seller application notification: ${notificationData['title']}');

          // Notification popups disabled - notifications only appear in the notification list
          // _showCooperativeNotificationPopup(
          //   title: notificationData['title'] ?? 'New Seller Application',
          //   message: notificationData['message'] ?? '',
          //   type: notificationData['type'] ?? 'seller_application',
          //   notificationId: notificationId,
          //   sellerId: notificationData['sellerId'] ?? '',
          //   applicantName: notificationData['applicantName'] ??
          //       (notificationData['message']?.contains('from') ?? false
          //           ? notificationData['message'].split('from').last.trim()
          //           : 'New Applicant'),
          // );

          // Mark this notification as shown
          _shownCoopNotificationIds.add(notificationId);
        }
      }
    }, onError: (error) {
      print('Error in cooperative notification listener: $error');
    });
  }

  /// Show floating notification popup for cooperative notifications
  void _showCooperativeNotificationPopup({
    required String title,
    required String message,
    required String type,
    required String notificationId,
    required String sellerId,
    required String applicantName,
  }) {
    if (!mounted) return;

    // Create an overlay entry for the floating notification
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 80,
        left: 16,
        right: 16,
        child: Material(
          child: GestureDetector(
            onTap: () {
              overlayEntry.remove();
              // Could navigate to seller details screen here
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border(
                  left: BorderSide(
                    color: Colors.green.shade700,
                    width: 5,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with icon and close button
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.person_add,
                          color: Colors.green.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              applicantName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          overlayEntry.remove();
                        },
                        child: Icon(
                          Icons.close,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Message
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            overlayEntry.remove();
                            // Navigate to seller details or applications tab
                            _tabController.animateTo(3); // Sellers tab
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text(
                            'Review',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            overlayEntry.remove();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text(
                            'Later',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-dismiss after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
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

  // Format timestamp with both date and time ago
  String _formatTimestampWithDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else {
        return 'N/A';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      // Format: DD/MM/YYYY HH:MM (time ago)
      String formattedDate =
          '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
      String formattedTime =
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

      String timeAgo;
      if (difference.inMinutes < 1) {
        timeAgo = 'Just now';
      } else if (difference.inHours < 1) {
        timeAgo = '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        timeAgo = '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        timeAgo = '${difference.inDays}d ago';
      } else if (difference.inDays < 30) {
        timeAgo = '${(difference.inDays / 7).floor()}w ago';
      } else {
        timeAgo = '${(difference.inDays / 30).floor()}mo ago';
      }

      return '$formattedDate $formattedTime ($timeAgo)';
    } catch (e) {
      return 'N/A';
    }
  }

  /// Generate a clean order number from the order ID
  String _getOrderNumber(String orderId) {
    // Handle timestamp-based order IDs: order_1234567890123_productId
    if (orderId.startsWith('order_') && orderId.contains('_')) {
      final parts = orderId.split('_');
      if (parts.length >= 3) {
        // Extract timestamp
        final timestamp = int.tryParse(parts[1]);
        if (timestamp != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final dateStr =
              '${date.day.toString().padLeft(2, '0')}${date.month.toString().padLeft(2, '0')}${date.year.toString().substring(2)}';
          // Format: DDMMYY-XXXX (last 4 of timestamp)
          return '$dateStr-${parts[1].substring(parts[1].length - 4)}';
        }
      }
    }

    // For Firebase auto-generated IDs, use first 4 + last 4
    if (orderId.length > 12) {
      return '${orderId.substring(0, 4)}-${orderId.substring(orderId.length - 4)}'
          .toUpperCase();
    }

    return orderId.toUpperCase();
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

  void _showSalesReportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.assessment,
                        color: Colors.green.shade700,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Generate Report',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Select report type',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildReportOptionCard(
                  context,
                  icon: Icons.today,
                  title: 'Today\'s Report',
                  description: 'Sales and earnings for today',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _generateSalesReport('today');
                  },
                ),
                const SizedBox(height: 12),
                _buildReportOptionCard(
                  context,
                  icon: Icons.date_range,
                  title: 'This Week',
                  description: 'Last 7 days sales report',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _generateSalesReport('week');
                  },
                ),
                const SizedBox(height: 12),
                _buildReportOptionCard(
                  context,
                  icon: Icons.calendar_month,
                  title: 'This Month',
                  description: 'Current month sales report',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _generateSalesReport('month');
                  },
                ),
                const SizedBox(height: 12),
                _buildReportOptionCard(
                  context,
                  icon: Icons.bar_chart,
                  title: 'All Time Report',
                  description: 'Complete sales history',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    _generateSalesReport('all');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
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
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _generateSalesReport(String period) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      DateTime now = DateTime.now();
      DateTime startDate;

      switch (period) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'all':
        default:
          startDate = DateTime(2020, 1, 1); // Get all orders
          break;
      }

      // Fetch all delivered orders first (no composite index needed)
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .get();

      // Enhanced statistics tracking
      double totalRevenue = 0;
      double totalDeliveryFees = 0;
      double totalProductRevenue = 0;
      int totalOrders = 0;
      int totalUnits = 0;

      Map<String, int> productSales = {};
      Map<String, double> productRevenue = {};
      Map<String, double> productUnitPrice = {};

      // Delivery method tracking
      int cooperativeDeliveryOrders = 0;
      int pickupOrders = 0;
      double cooperativeDeliveryRevenue = 0;
      double pickupRevenue = 0;

      // Daily tracking for trend analysis
      Map<String, int> dailyOrders = {};
      Map<String, double> dailyRevenue = {};

      // Payment method tracking
      Map<String, int> paymentMethods = {};
      Map<String, double> paymentMethodRevenue = {};

      // Filter by date in app and calculate comprehensive statistics
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();

        // Check if order is within date range
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final orderDate = timestamp.toDate();
          if (orderDate.isBefore(startDate)) {
            continue; // Skip orders before start date
          }

          // Track daily statistics
          final dateKey =
              '${orderDate.year}-${orderDate.month.toString().padLeft(2, '0')}-${orderDate.day.toString().padLeft(2, '0')}';
          dailyOrders[dateKey] = (dailyOrders[dateKey] ?? 0) + 1;
          dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0) +
              (data['totalAmount'] ?? 0).toDouble();
        }

        final totalAmount = (data['totalAmount'] ?? 0).toDouble();
        final deliveryFee = (data['deliveryFee'] ?? 0).toDouble();
        final subtotal =
            (data['subtotal'] ?? (totalAmount - deliveryFee)).toDouble();
        final productName = data['productName'] ?? 'Unknown';
        final quantity = (data['quantity'] ?? 0) as int;
        final unitPrice = (data['price'] ?? 0).toDouble();
        final deliveryMethod = data['deliveryMethod'] ?? '';
        final paymentMethod = data['paymentMethod'] ?? 'Not specified';

        totalOrders++;
        totalRevenue += totalAmount;
        totalDeliveryFees += deliveryFee;
        totalProductRevenue += subtotal;
        totalUnits += quantity;

        // Product statistics
        productSales[productName] = (productSales[productName] ?? 0) + quantity;
        productRevenue[productName] =
            (productRevenue[productName] ?? 0) + subtotal;
        productUnitPrice[productName] = unitPrice;

        // Delivery method statistics
        if (deliveryMethod == 'Cooperative Delivery') {
          cooperativeDeliveryOrders++;
          cooperativeDeliveryRevenue += totalAmount;
        } else if (deliveryMethod == 'Pickup at Coop') {
          pickupOrders++;
          pickupRevenue += totalAmount;
        }

        // Payment method statistics
        paymentMethods[paymentMethod] =
            (paymentMethods[paymentMethod] ?? 0) + 1;
        paymentMethodRevenue[paymentMethod] =
            (paymentMethodRevenue[paymentMethod] ?? 0) + totalAmount;
      }

      // Sort products by revenue
      final sortedProducts = productRevenue.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Calculate averages
      final averageOrderValue =
          totalOrders > 0 ? totalRevenue / totalOrders : 0;
      final averageUnitsPerOrder =
          totalOrders > 0 ? totalUnits / totalOrders : 0;

      // Calculate days in period
      final daysDifference = now.difference(startDate).inDays + 1;

      Navigator.pop(context); // Close loading dialog

      // Show enhanced report dialog
      _showReportDetailsDialog(
        period: period,
        startDate: startDate,
        endDate: now,
        totalOrders: totalOrders,
        totalRevenue: totalRevenue,
        totalDeliveryFees: totalDeliveryFees,
        totalProductRevenue: totalProductRevenue,
        totalUnits: totalUnits,
        sortedProducts: sortedProducts,
        productSales: productSales,
        productUnitPrice: productUnitPrice,
        cooperativeDeliveryOrders: cooperativeDeliveryOrders,
        pickupOrders: pickupOrders,
        cooperativeDeliveryRevenue: cooperativeDeliveryRevenue,
        pickupRevenue: pickupRevenue,
        paymentMethods: paymentMethods,
        paymentMethodRevenue: paymentMethodRevenue,
        averageOrderValue: averageOrderValue.toDouble(),
        averageUnitsPerOrder: averageUnitsPerOrder.toDouble(),
        daysDifference: daysDifference,
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showReportDetailsDialog({
    required String period,
    required DateTime startDate,
    required DateTime endDate,
    required int totalOrders,
    required double totalRevenue,
    required double totalDeliveryFees,
    required double totalProductRevenue,
    required int totalUnits,
    required List<MapEntry<String, double>> sortedProducts,
    required Map<String, int> productSales,
    required Map<String, double> productUnitPrice,
    required int cooperativeDeliveryOrders,
    required int pickupOrders,
    required double cooperativeDeliveryRevenue,
    required double pickupRevenue,
    required Map<String, int> paymentMethods,
    required Map<String, double> paymentMethodRevenue,
    required double averageOrderValue,
    required double averageUnitsPerOrder,
    required int daysDifference,
  }) {
    String periodTitle;
    switch (period) {
      case 'today':
        periodTitle = 'Today\'s Report';
        break;
      case 'week':
        periodTitle = 'Last 7 Days Report';
        break;
      case 'month':
        periodTitle = 'This Month\'s Report';
        break;
      case 'all':
      default:
        periodTitle = 'All Time Report';
        break;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade600, Colors.green.shade800],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.assessment,
                          color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              periodTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_formatDate(startDate)} - ${_formatDate(endDate)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf,
                            color: Colors.white),
                        tooltip: 'Download PDF',
                        onPressed: () => _generatePdfReport(
                          periodTitle: periodTitle,
                          startDate: startDate,
                          endDate: endDate,
                          totalOrders: totalOrders,
                          totalRevenue: totalRevenue,
                          totalDeliveryFees: totalDeliveryFees,
                          totalProductRevenue: totalProductRevenue,
                          totalUnits: totalUnits,
                          averageOrderValue: averageOrderValue,
                          averageUnitsPerOrder: averageUnitsPerOrder,
                          cooperativeDeliveryOrders: cooperativeDeliveryOrders,
                          pickupOrders: pickupOrders,
                          cooperativeDeliveryRevenue:
                              cooperativeDeliveryRevenue,
                          pickupRevenue: pickupRevenue,
                          paymentMethods: paymentMethods,
                          paymentMethodRevenue: paymentMethodRevenue,
                          sortedProducts: sortedProducts,
                          productSales: productSales,
                          productUnitPrice: productUnitPrice,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Executive Summary Section
                        _buildSectionHeader(
                            'Executive Summary', Icons.assessment),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                icon: Icons.shopping_cart,
                                title: 'Total Orders',
                                value: '$totalOrders',
                                subtitle:
                                    '${(totalOrders / daysDifference).toStringAsFixed(1)}/day',
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryCard(
                                icon: Icons.inventory_2,
                                title: 'Total Units',
                                value: '$totalUnits',
                                subtitle:
                                    '${averageUnitsPerOrder.toStringAsFixed(1)}/order',
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                icon: Icons.attach_money,
                                title: 'Gross Revenue',
                                value: '₱${totalRevenue.toStringAsFixed(2)}',
                                subtitle:
                                    '₱${(totalRevenue / daysDifference).toStringAsFixed(2)}/day',
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryCard(
                                icon: Icons.trending_up,
                                title: 'Avg Order Value',
                                value:
                                    '₱${averageOrderValue.toStringAsFixed(2)}',
                                subtitle: 'Per transaction',
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                icon: Icons.shopping_bag,
                                title: 'Product Revenue',
                                value:
                                    '₱${totalProductRevenue.toStringAsFixed(2)}',
                                subtitle:
                                    '${((totalProductRevenue / totalRevenue) * 100).toStringAsFixed(1)}% of total',
                                color: Colors.indigo,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryCard(
                                icon: Icons.local_shipping,
                                title: 'Delivery Fees',
                                value:
                                    '₱${totalDeliveryFees.toStringAsFixed(2)}',
                                subtitle:
                                    '${((totalDeliveryFees / totalRevenue) * 100).toStringAsFixed(1)}% of total',
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Delivery Method Analysis
                        _buildSectionHeader(
                            'Delivery Method Analysis', Icons.local_shipping),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailCard(
                                title: 'Cooperative Delivery',
                                orders: cooperativeDeliveryOrders,
                                revenue: cooperativeDeliveryRevenue,
                                color: Colors.purple,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDetailCard(
                                title: 'Pickup at Coop',
                                orders: pickupOrders,
                                revenue: pickupRevenue,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Payment Method Analysis
                        if (paymentMethods.isNotEmpty) ...[
                          _buildSectionHeader(
                              'Payment Method Analysis', Icons.payment),
                          const SizedBox(height: 12),
                          ...paymentMethods.entries.map((entry) {
                            final method = entry.key;
                            final count = entry.value;
                            final revenue = paymentMethodRevenue[method] ?? 0;
                            final percentage =
                                (count / totalOrders * 100).toStringAsFixed(1);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.payment,
                                      color: Colors.blue.shade700, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          method,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          '$count orders ($percentage%)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₱${revenue.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 24),
                        ],
                        // Top Products Section
                        _buildSectionHeader('Top Selling Products', Icons.star),
                        const SizedBox(height: 12),
                        if (sortedProducts.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No sales data available',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...sortedProducts.take(10).map((entry) {
                            final productName = entry.key;
                            final revenue = entry.value;
                            final quantity = productSales[productName] ?? 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.shopping_bag,
                                      color: Colors.green.shade700,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          productName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$quantity units sold',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₱${revenue.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.green.shade700, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade900,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required int orders,
    required double revenue,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Orders',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '$orders',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Revenue',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '₱${revenue.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdfReport({
    required String periodTitle,
    required DateTime startDate,
    required DateTime endDate,
    required int totalOrders,
    required double totalRevenue,
    required double totalDeliveryFees,
    required double totalProductRevenue,
    required int totalUnits,
    required double averageOrderValue,
    required double averageUnitsPerOrder,
    required int cooperativeDeliveryOrders,
    required int pickupOrders,
    required double cooperativeDeliveryRevenue,
    required double pickupRevenue,
    required Map<String, int> paymentMethods,
    required Map<String, double> paymentMethodRevenue,
    required List<MapEntry<String, double>> sortedProducts,
    required Map<String, int> productSales,
    required Map<String, double> productUnitPrice,
  }) async {
    final pdf = pw.Document();

    // Add page to PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.green700,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Cooperative Sales Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    periodTitle,
                    style: pw.TextStyle(
                      fontSize: 18,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Period: ${_formatDate(startDate)} - ${_formatDate(endDate)}',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Executive Summary Section
            pw.Text(
              'Executive Summary',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green900,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  _buildPdfRow('Total Orders:', '$totalOrders'),
                  pw.Divider(),
                  _buildPdfRow('Total Units Sold:', '$totalUnits'),
                  pw.Divider(),
                  _buildPdfRow(
                      'Total Revenue:', '₱${totalRevenue.toStringAsFixed(2)}'),
                  pw.Divider(),
                  _buildPdfRow('Average Order Value:',
                      '₱${averageOrderValue.toStringAsFixed(2)}'),
                  pw.Divider(),
                  _buildPdfRow('Product Revenue:',
                      '₱${totalProductRevenue.toStringAsFixed(2)}'),
                  pw.Divider(),
                  _buildPdfRow('Delivery Fees:',
                      '₱${totalDeliveryFees.toStringAsFixed(2)}'),
                  pw.Divider(),
                  _buildPdfRow('Average Units per Order:',
                      '${averageUnitsPerOrder.toStringAsFixed(1)}'),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Delivery Method Analysis
            pw.Text(
              'Delivery Method Analysis',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green900,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blue300),
                      borderRadius: pw.BorderRadius.circular(8),
                      color: PdfColors.blue50,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Cooperative Delivery',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        _buildPdfRow('Orders:', '$cooperativeDeliveryOrders',
                            fontSize: 12),
                        pw.SizedBox(height: 4),
                        _buildPdfRow('Revenue:',
                            '₱${cooperativeDeliveryRevenue.toStringAsFixed(2)}',
                            fontSize: 12),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.orange300),
                      borderRadius: pw.BorderRadius.circular(8),
                      color: PdfColors.orange50,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Pickup',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange900,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        _buildPdfRow('Orders:', '$pickupOrders', fontSize: 12),
                        pw.SizedBox(height: 4),
                        _buildPdfRow(
                            'Revenue:', '₱${pickupRevenue.toStringAsFixed(2)}',
                            fontSize: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Payment Method Analysis
            pw.Text(
              'Payment Method Analysis',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green900,
              ),
            ),
            pw.SizedBox(height: 12),
            if (paymentMethods.isEmpty)
              pw.Text('No payment data available',
                  style: const pw.TextStyle(
                      fontSize: 12, color: PdfColors.grey600))
            else
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: paymentMethods.entries.map((entry) {
                    final method = entry.key;
                    final count = entry.value;
                    final revenue = paymentMethodRevenue[method] ?? 0.0;
                    return pw.Column(
                      children: [
                        _buildPdfRow(
                          method,
                          '$count orders • ₱${revenue.toStringAsFixed(2)}',
                        ),
                        if (entry != paymentMethods.entries.last) pw.Divider(),
                      ],
                    );
                  }).toList(),
                ),
              ),
            pw.SizedBox(height: 24),

            // Top Products Section
            pw.Text(
              'Top Products',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green900,
              ),
            ),
            pw.SizedBox(height: 12),

            if (sortedProducts.isEmpty)
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(32),
                  child: pw.Text(
                    'No sales data available for this period',
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.green100,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Product Name',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Units Sold',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Revenue',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Data rows
                  ...sortedProducts.take(20).map((entry) {
                    final productName = entry.key;
                    final revenue = entry.value;
                    final quantity = productSales[productName] ?? 0;

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(productName),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '$quantity',
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '₱${revenue.toStringAsFixed(2)}',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),

            pw.SizedBox(height: 24),

            // Footer
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'This report was automatically generated by the Cooperative Management System',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ];
        },
      ),
    );

    // Show PDF preview and allow saving/printing
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Cooperative_Sales_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _buildPdfRow(String label, String value,
      {bool isBold = false, double fontSize = 14}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isBold ? PdfColors.green900 : PdfColors.black,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
            Tab(icon: Icon(Icons.chat), text: 'Messages'),
            Tab(icon: Icon(Icons.assessment), text: 'Reports'),
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
          const CooperativeMessagesScreen(),
          _buildReportsTab(),
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

          const SizedBox(height: 16),

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

              // Count sellers by category
              final pendingCount = sellers.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['status'] ?? 'pending') == 'pending';
              }).length;

              final approvedCount = sellers.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['status'] ?? '') == 'approved';
              }).length;

              final rejectedCount = sellers.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['status'] ?? '') == 'rejected';
              }).length;

              final cancelledCount = sellers.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['status'] ?? '') == 'cancelled';
              }).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Filter Buttons with counts
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilterChip(
                          label: Text('All (${sellers.length})'),
                          selected: _selectedSellerCategory == 'All',
                          onSelected: (selected) {
                            setState(() {
                              _selectedSellerCategory = 'All';
                            });
                          },
                          backgroundColor: Colors.grey.shade200,
                          selectedColor: Colors.green.shade300,
                          labelStyle: TextStyle(
                            color: _selectedSellerCategory == 'All'
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text('Pending ($pendingCount)'),
                          selected: _selectedSellerCategory == 'Pending',
                          onSelected: (selected) {
                            setState(() {
                              _selectedSellerCategory = 'Pending';
                            });
                          },
                          backgroundColor: Colors.grey.shade200,
                          selectedColor: Colors.orange.shade300,
                          labelStyle: TextStyle(
                            color: _selectedSellerCategory == 'Pending'
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text('Approved ($approvedCount)'),
                          selected: _selectedSellerCategory == 'Approved',
                          onSelected: (selected) {
                            setState(() {
                              _selectedSellerCategory = 'Approved';
                            });
                          },
                          backgroundColor: Colors.grey.shade200,
                          selectedColor: Colors.green.shade600,
                          labelStyle: TextStyle(
                            color: _selectedSellerCategory == 'Approved'
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text('Rejected ($rejectedCount)'),
                          selected: _selectedSellerCategory == 'Rejected',
                          onSelected: (selected) {
                            setState(() {
                              _selectedSellerCategory = 'Rejected';
                            });
                          },
                          backgroundColor: Colors.grey.shade200,
                          selectedColor: Colors.red.shade300,
                          labelStyle: TextStyle(
                            color: _selectedSellerCategory == 'Rejected'
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text('Cancelled ($cancelledCount)'),
                          selected: _selectedSellerCategory == 'Cancelled',
                          onSelected: (selected) {
                            setState(() {
                              _selectedSellerCategory = 'Cancelled';
                            });
                          },
                          backgroundColor: Colors.grey.shade200,
                          selectedColor: Colors.grey.shade600,
                          labelStyle: TextStyle(
                            color: _selectedSellerCategory == 'Cancelled'
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sellers List - Filtered by category
                  Builder(
                    builder: (context) {
                      // Filter sellers based on selected category

                      List<QueryDocumentSnapshot> filteredSellers = sellers;

                      if (_selectedSellerCategory != 'All') {
                        filteredSellers = sellers.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final status = data['status'] ?? 'pending';

                          switch (_selectedSellerCategory) {
                            case 'Pending':
                              return status == 'pending';
                            case 'Approved':
                              return status == 'approved';
                            case 'Rejected':
                              return status == 'rejected';
                            case 'Cancelled':
                              return status == 'cancelled';
                            default:
                              return true;
                          }
                        }).toList();
                      }

                      // Sort by application date (latest to oldest)
                      filteredSellers.sort((a, b) {
                        final dataA = a.data() as Map<String, dynamic>?;
                        final dataB = b.data() as Map<String, dynamic>?;

                        final dateA =
                            dataA?['sellerApplicationDate'] as Timestamp?;
                        final dateB =
                            dataB?['sellerApplicationDate'] as Timestamp?;

                        if (dateA == null || dateB == null) {
                          return 0;
                        }

                        return dateB.compareTo(
                            dateA); // Latest first (descending order)
                      });

                      if (filteredSellers.isEmpty) {
                        return Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.person_off,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'No ${_selectedSellerCategory.toLowerCase()} sellers found',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredSellers.length,
                        itemBuilder: (context, index) {
                          final sellerData = filteredSellers[index].data()
                              as Map<String, dynamic>;
                          final sellerId = filteredSellers[index].id;
                          return _buildSellerCard(sellerData, sellerId);
                        },
                      );
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
    final createdAt = seller['sellerApplicationDate'] as Timestamp?;

    // Try to get location from users collection first, then fallback to default
    String location = 'Not specified';

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

    // Format date
    String dateApplied = 'N/A';
    if (createdAt != null) {
      final date = createdAt.toDate();
      dateApplied = '${date.month}/${date.day}/${date.year}';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showSellerDetails(seller, sellerId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar with status indicator
              Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.2),
                    radius: 30,
                    child: Icon(Icons.person, color: statusColor, size: 32),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(statusIcon, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full Name
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Date Applied
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Applied: $dateApplied',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Location - Fetch from sellers collection
                    FutureBuilder<DocumentSnapshot>(
                      future: _firestore
                          .collection('sellers')
                          .where('userId', isEqualTo: sellerId)
                          .limit(1)
                          .get()
                          .then((snapshot) {
                        if (snapshot.docs.isNotEmpty) {
                          return Future.value(snapshot.docs.first);
                        }
                        throw Exception('Seller not found');
                      }),
                      builder: (context, snapshot) {
                        String displayLocation = location;
                        if (snapshot.hasData) {
                          final sellerDoc =
                              snapshot.data?.data() as Map<String, dynamic>?;
                          if (sellerDoc != null) {
                            final address =
                                sellerDoc['address'] as Map<String, dynamic>? ??
                                    {};
                            displayLocation =
                                address['city'] ?? 'Not specified';
                          }
                        }
                        return Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                displayLocation,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Status Badge and Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor, width: 1.5),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Delete Button
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      // Stop propagation to card's onTap
                      _showDeleteSellerDialog(sellerId, name);
                    },
                    tooltip: 'Delete Seller',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show seller details dialog
  void _showSellerDetails(Map<String, dynamic> seller, String sellerId) {
    final userId = sellerId; // This is the user ID (Firebase Auth ID)
    final actualSellerId =
        seller['sellerId'] ?? sellerId; // Get the actual seller doc ID

    print('📋 Opening seller review:');
    print('   userId (from users collection): $userId');
    print('   sellerId (from seller doc): $actualSellerId');

    // Navigate to the new seller review screen instead of showing a dialog
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SellerReviewScreen(
          sellerId: actualSellerId,
          userId: userId,
        ),
      ),
    ).then((result) {
      // Refresh the sellers list if status was changed
      if (result != null) {
        _loadDashboardStats();
      }
    });
  }

  // Show delete seller confirmation dialog
  void _showDeleteSellerDialog(String sellerId, String sellerName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Seller'),
        content: Text(
          'Are you sure you want to delete "$sellerName"?\n\nThis will:\n• Remove the seller from your cooperative\n• Delete all their products\n• Cancel their pending orders\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSeller(sellerId, sellerName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Delete seller and their data
  Future<void> _deleteSeller(String sellerId, String sellerName) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      print('🗑️ Deleting seller: $sellerId');

      // 1. Delete all products by this seller
      final productsSnapshot = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .get();

      for (var productDoc in productsSnapshot.docs) {
        await productDoc.reference.delete();
      }
      print('   Deleted ${productsSnapshot.docs.length} products');

      // 2. Update user role from seller to regular user
      await _firestore.collection('users').doc(sellerId).update({
        'role': 'buyer',
        'status': 'active',
        'sellerApplicationDate': FieldValue.delete(),
        'cooperativeId': FieldValue.delete(),
      });
      print('   Updated user role');

      // 3. Delete seller document
      final sellerSnapshot = await _firestore
          .collection('sellers')
          .where('userId', isEqualTo: sellerId)
          .get();

      for (var sellerDoc in sellerSnapshot.docs) {
        await sellerDoc.reference.delete();
      }
      print('   Deleted seller document');

      // 4. Send notification to the seller
      await _firestore.collection('notifications').add({
        'title': 'Removed from Cooperative',
        'message':
            'You have been removed from the cooperative. Your seller account has been deactivated.',
        'body':
            'You have been removed from the cooperative. Your seller account has been deactivated.',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'seller_removed',
        'read': false,
        'userId': sellerId,
        'priority': 'high',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$sellerName has been deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Refresh the dashboard
      _loadDashboardStats();
    } catch (e) {
      print('❌ Error deleting seller: $e');
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

              // Count pending products
              int pending = products.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['status'] ?? 'pending') == 'pending';
              }).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
        onTap: () {
          // Navigate to product approval screen for pending products
          if (status == 'pending') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NotificationDetailScreen(
                  notification: {
                    'type': 'product_approval',
                    'title': 'Product Approval Request',
                    'message': 'Review product details and approve or reject',
                    'productId': productId,
                    'productName': name,
                    'price': price,
                    'status': status,
                    'timestamp': product['createdAt'] ?? Timestamp.now(),
                    'priority': 'high',
                  },
                ),
              ),
            );
          } else {
            // For approved/rejected products, show the details dialog
            _showProductDetails(product, productId);
          }
        },
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
        padding: const EdgeInsets.all(16),
        children: [
          // Compact Header with Stats
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Row(
                    children: [
                      Icon(Icons.shopping_cart,
                          size: 28, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Order Management',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Stats Row
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatItem(
                          'Processing',
                          _stats['processingOrders']?.toString() ?? '0',
                          Icons.autorenew,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatItem(
                          'Shipped',
                          _stats['shippedOrders']?.toString() ?? '0',
                          Icons.local_shipping,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 8),
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

          const SizedBox(height: 12),

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

  // ========== PAYOUTS TAB ==========
  Widget _buildPayoutsTab() {
    return _CooperativePayoutsView(firestore: _firestore);
  }

  // ========== REPORTS TAB ==========
  Widget _buildReportsTab() {
    return _CooperativeReportsView(firestore: _firestore);
  }

  // ========== ORDER CARD WIDGET ==========
  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final deliveryMethod = order['deliveryMethod'] ?? '';
    final orderId = order['id'] ?? '';
    final quantity = order['quantity'] ?? 1;
    final buyerName = order['customerName'] ?? 'Unknown Buyer';
    final productName = order['productName'] ?? 'Unknown Product';
    final productImageUrl = order['productImage'] ?? '';
    final unitPrice = (order['price'] ?? 0.0).toDouble();
    final deliveryFee = (order['deliveryFee'] ?? 0.0).toDouble();
    final totalAmount = (order['totalAmount'] ?? 0.0).toDouble();
    final coopStatus = order['coopStatus'];

    // Handle customerAddress - it might be a String or Map
    String buyerAddress = 'N/A';
    final customerAddr = order['customerAddress'];
    if (customerAddr is String) {
      buyerAddress = customerAddr;
    } else if (customerAddr is Map) {
      buyerAddress = customerAddr['fullAddress']?.toString() ??
          customerAddr['address']?.toString() ??
          'N/A';
    }

    // Handle customerContact - it might be a String or Map
    String buyerContact = 'N/A';
    final customerCont = order['customerContact'];
    if (customerCont is String) {
      buyerContact = customerCont;
    } else if (customerCont is Map) {
      buyerContact = customerCont['phone']?.toString() ??
          customerCont['contact']?.toString() ??
          'N/A';
    }

    final String? buyerId =
        order['buyerId'] ?? order['userId'] ?? order['customerId'];
    final sellerId = order['sellerId'] ?? '';

    Color statusColor = _getStatusColor(status);
    IconData statusIcon = _getStatusIcon(status);

    bool isExpanded = _expandedOrders.contains(orderId);
    bool isCoopDelivery = deliveryMethod == 'Cooperative Delivery';

    // Simplified status text - different for Pickup vs Delivery
    String statusText;
    if (status == 'shipped') {
      statusText = isCoopDelivery ? 'OUT FOR DELIVERY' : 'READY FOR PICKUP';
    } else if (status == 'ready_for_pickup') {
      statusText = isCoopDelivery ? 'READY FOR DELIVERY' : 'READY FOR PICKUP';
    } else {
      statusText = status.toUpperCase();
    }

    // Fetch seller information from users collection
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(sellerId).get(),
      builder: (context, sellerSnapshot) {
        String sellerName = 'Unknown Seller';
        String sellerContact = 'N/A';
        String sellerLocation = 'N/A';

        if (sellerSnapshot.hasData && sellerSnapshot.data!.exists) {
          final sellerData =
              sellerSnapshot.data!.data() as Map<String, dynamic>?;
          if (sellerData != null) {
            sellerName = sellerData['name'] ??
                sellerData['fullName'] ??
                'Unknown Seller';
            // Try multiple possible field names for contact
            sellerContact = sellerData['phone'] ??
                sellerData['phoneNumber'] ??
                sellerData['mobile'] ??
                sellerData['contact'] ??
                sellerData['mobileNumber'] ??
                sellerData['contactNumber'] ??
                'N/A';
            sellerLocation =
                sellerData['location'] ?? sellerData['address'] ?? 'N/A';
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Buyer Name
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.person,
                          color: Colors.blue.shade700, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buyer Name',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            buyerName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 2. Product Name with Image
                Row(
                  children: [
                    // Product Image (clickable)
                    if (productImageUrl.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          // Show full image dialog
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppBar(
                                    title: const Text('Product Image'),
                                    automaticallyImplyLeading: false,
                                    actions: [
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                  InteractiveViewer(
                                    child: Image.network(
                                      productImageUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          padding: const EdgeInsets.all(40),
                                          child: const Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.broken_image,
                                                  size: 48, color: Colors.grey),
                                              SizedBox(height: 8),
                                              Text('Image not available'),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.orange.shade200, width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              productImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.shopping_bag,
                                    color: Colors.orange.shade700, size: 24);
                              },
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.shopping_bag,
                            color: Colors.orange.shade700, size: 18),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Product Name',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            productName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 3. Quantity
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.inventory_2,
                          color: Colors.green.shade700, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quantity',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$quantity items',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 4. Delivery Option
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        deliveryMethod == 'Pickup at Coop'
                            ? Icons.store
                            : Icons.local_shipping,
                        color: Colors.purple.shade700,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery Option',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                deliveryMethod.isEmpty
                                    ? 'Standard Delivery'
                                    : deliveryMethod,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isCoopDelivery) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade700,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'COOP',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Show delivery address for Cooperative Delivery
                if (isCoopDelivery &&
                    order['deliveryAddress'] != null &&
                    order['deliveryAddress'].toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on,
                            color: Colors.blue.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delivery Address',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                order['deliveryAddress'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // 5. Current Status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Status',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: statusColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // View Details Button (toggles expansion)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedOrders.remove(orderId);
                        } else {
                          _expandedOrders.add(orderId);
                        }
                      });
                    },
                    icon: Icon(
                        isExpanded ? Icons.expand_less : Icons.visibility,
                        size: 18),
                    label: Text(
                      isExpanded ? 'Hide Details' : 'View Details',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),

                // EXPANDED VIEW - Full Details
                if (isExpanded) ...[
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order ID Section
                        _buildDetailSection(
                          title: 'Order ID',
                          icon: Icons.receipt_long,
                          color: Colors.indigo,
                          children: [
                            _buildExpandedDetailRow(
                                'Transaction ID', _getOrderNumber(orderId)),
                            _buildExpandedDetailRow(
                                'Order Date',
                                order['timestamp'] != null
                                    ? _formatTimestampWithDate(
                                        order['timestamp'])
                                    : order['createdAt'] != null
                                        ? _formatTimestampWithDate(
                                            order['createdAt'])
                                        : 'N/A'),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Product Details Section
                        _buildDetailSection(
                          title: 'Product Details',
                          icon: Icons.shopping_bag,
                          color: Colors.orange,
                          children: [
                            _buildExpandedDetailRow(
                                'Product Name', productName),
                            _buildExpandedDetailRow(
                                'Quantity', '$quantity items'),
                            _buildExpandedDetailRow('Unit Price',
                                '₱${unitPrice.toStringAsFixed(2)}'),
                            _buildExpandedDetailRow('Subtotal',
                                '₱${(order['subtotal'] ?? (unitPrice * quantity)).toStringAsFixed(2)}',
                                isBold: true),
                            _buildExpandedDetailRow('Delivery Fee',
                                '₱${(order['deliveryFee'] ?? deliveryFee).toStringAsFixed(2)}'),
                            _buildExpandedDetailRow('Total Amount',
                                '₱${totalAmount.toStringAsFixed(2)}',
                                isBold: true, isHighlight: true),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Buyer Information Section
                        FutureBuilder<DocumentSnapshot?>(
                          future: buyerId != null && buyerId.isNotEmpty
                              ? _firestore
                                  .collection('users')
                                  .doc(buyerId)
                                  .get()
                              : Future.value(null),
                          builder: (context, buyerSnapshot) {
                            String addressToShow = buyerAddress;
                            String contactToShow = buyerContact;

                            // Try to get address from user profile if missing or is placeholder
                            bool addressIsMissing = addressToShow == 'N/A' ||
                                addressToShow.isEmpty ||
                                addressToShow
                                    .toLowerCase()
                                    .contains('no address');

                            if (addressIsMissing &&
                                buyerSnapshot.hasData &&
                                buyerSnapshot.data != null &&
                                buyerSnapshot.data!.exists) {
                              final buyerData = buyerSnapshot.data!.data()
                                  as Map<String, dynamic>?;
                              if (buyerData != null) {
                                // Try multiple address fields and handle both String and Map types
                                final addressFields = [
                                  'address',
                                  'location',
                                  'city',
                                  'fullAddress'
                                ];
                                for (final field in addressFields) {
                                  final value = buyerData[field];
                                  if (value != null) {
                                    if (value is String && value.isNotEmpty) {
                                      addressToShow = value;
                                      break;
                                    } else if (value is Map) {
                                      final extracted =
                                          value['fullAddress']?.toString() ??
                                              value['address']?.toString();
                                      if (extracted != null &&
                                          extracted.isNotEmpty) {
                                        addressToShow = extracted;
                                        break;
                                      }
                                    }
                                  }
                                }
                              }
                            }

                            // Try to get contact from user profile if missing or is placeholder
                            bool contactIsMissing = contactToShow == 'N/A' ||
                                contactToShow.isEmpty ||
                                contactToShow
                                    .toLowerCase()
                                    .contains('no contact');

                            if (contactIsMissing &&
                                buyerSnapshot.hasData &&
                                buyerSnapshot.data != null &&
                                buyerSnapshot.data!.exists) {
                              final buyerData = buyerSnapshot.data!.data()
                                  as Map<String, dynamic>?;
                              if (buyerData != null) {
                                // Try multiple possible field names for contact and handle types
                                final contactFields = [
                                  'phone',
                                  'phoneNumber',
                                  'mobile',
                                  'contact',
                                  'mobileNumber'
                                ];
                                for (final field in contactFields) {
                                  final value = buyerData[field];
                                  if (value != null) {
                                    if (value is String && value.isNotEmpty) {
                                      contactToShow = value;
                                      break;
                                    } else if (value is Map) {
                                      final extracted =
                                          value['phone']?.toString() ??
                                              value['number']?.toString() ??
                                              value['contact']?.toString();
                                      if (extracted != null &&
                                          extracted.isNotEmpty) {
                                        contactToShow = extracted;
                                        break;
                                      }
                                    } else {
                                      // Handle other types by converting to string
                                      final strValue = value.toString();
                                      if (strValue.isNotEmpty &&
                                          strValue != 'null') {
                                        contactToShow = strValue;
                                        break;
                                      }
                                    }
                                  }
                                }
                              }
                            }

                            // Final fallback for address: use deliveryAddress from order
                            if ((addressToShow == 'N/A' ||
                                    addressToShow.isEmpty) &&
                                order['deliveryAddress'] != null) {
                              // Handle both String and Map types for deliveryAddress
                              final deliveryAddr = order['deliveryAddress'];
                              if (deliveryAddr is String &&
                                  deliveryAddr.isNotEmpty) {
                                addressToShow = deliveryAddr;
                              } else if (deliveryAddr is Map) {
                                // If it's a Map, try to extract fullAddress or combine parts
                                addressToShow =
                                    deliveryAddr['fullAddress']?.toString() ??
                                        deliveryAddr['address']?.toString() ??
                                        addressToShow;
                              }
                            }

                            return _buildDetailSection(
                              title: 'Buyer Information',
                              icon: Icons.person,
                              color: Colors.blue,
                              children: [
                                _buildExpandedDetailRow('Name', buyerName),
                                _buildExpandedDetailRow(
                                    'Address', addressToShow),
                                _buildExpandedDetailRow(
                                    'Contact', contactToShow),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // Seller Information Section
                        FutureBuilder<QuerySnapshot?>(
                          future: (sellerContact == 'N/A' ||
                                      sellerContact.isEmpty) &&
                                  sellerId != null &&
                                  sellerId.isNotEmpty
                              ? _firestore
                                  .collection('sellers')
                                  .where('userId', isEqualTo: sellerId)
                                  .limit(1)
                                  .get()
                              : Future.value(null),
                          builder: (context, sellerProfileSnapshot) {
                            String contactToShow = sellerContact;

                            // Try to get contact from sellers collection if missing
                            if ((contactToShow == 'N/A' ||
                                    contactToShow.isEmpty) &&
                                sellerProfileSnapshot.hasData &&
                                sellerProfileSnapshot.data != null &&
                                sellerProfileSnapshot.data!.docs.isNotEmpty) {
                              final sellerProfile =
                                  sellerProfileSnapshot.data!.docs.first.data()
                                      as Map<String, dynamic>;

                              // Try multiple possible field names for contact
                              contactToShow = sellerProfile['phone'] ??
                                  sellerProfile['phoneNumber'] ??
                                  sellerProfile['mobile'] ??
                                  sellerProfile['contact'] ??
                                  sellerProfile['mobileNumber'] ??
                                  sellerProfile['contactNumber'] ??
                                  contactToShow;
                            }

                            return _buildDetailSection(
                              title: 'Seller Information',
                              icon: Icons.store,
                              color: Colors.green,
                              children: [
                                _buildExpandedDetailRow('Name', sellerName),
                                _buildExpandedDetailRow(
                                    'Contact', contactToShow),
                                if (sellerLocation != 'N/A')
                                  _buildExpandedDetailRow(
                                      'Location', sellerLocation),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // Delivery Option Section
                        _buildDetailSection(
                          title: 'Delivery Option',
                          icon: Icons.local_shipping,
                          color: Colors.purple,
                          children: [
                            _buildDetailRow(
                                'Method',
                                deliveryMethod.isEmpty
                                    ? 'Standard Delivery'
                                    : deliveryMethod),
                            // Show delivery address if it's Cooperative Delivery
                            if (isCoopDelivery &&
                                order['deliveryAddress'] != null &&
                                order['deliveryAddress']
                                    .toString()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                  'Delivery Address', order['deliveryAddress']),
                            ],
                            if (isCoopDelivery) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.purple.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.purple.shade700,
                                        size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Cooperative handles this delivery',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.purple.shade900,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Status Tracker Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                statusColor.withOpacity(0.1),
                                statusColor.withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.timeline,
                                      color: statusColor, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Status Tracker',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildStatusProgressBar(status),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(statusIcon,
                                        color: statusColor, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Current: $statusText',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Action Buttons Section
                        const Text(
                          'Actions',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildActionButtons(orderId, status, deliveryMethod,
                            isCoopDelivery, coopStatus),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to build detail sections with colored borders
  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // Helper method to build detail rows for expanded view
  Widget _buildExpandedDetailRow(String label, String value,
      {bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isHighlight ? Colors.green.shade700 : Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build status progress bar
  Widget _buildStatusProgressBar(String status) {
    final steps = ['pending', 'processing', 'shipped', 'delivered'];
    final currentIndex = steps.indexOf(status.toLowerCase());
    final progress =
        currentIndex >= 0 ? (currentIndex + 1) / steps.length : 0.0;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(status)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildProgressLabel('Pending', currentIndex >= 0, Colors.orange),
            _buildProgressLabel('Processing', currentIndex >= 1, Colors.blue),
            _buildProgressLabel('Shipped', currentIndex >= 2, Colors.purple),
            _buildProgressLabel('Delivered', currentIndex >= 3, Colors.green),
          ],
        ),
      ],
    );
  }

  // Helper method to build progress labels
  Widget _buildProgressLabel(String label, bool isActive, Color color) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        color: isActive ? color : Colors.grey.shade500,
      ),
    );
  }

  // Helper method to build action buttons based on status and delivery method
  Widget _buildActionButtons(String orderId, String status,
      String deliveryMethod, bool isCoopDelivery, String? coopStatus) {
    List<Widget> buttons = [];

    // FOR PICKUP AT COOP: Show "Picked Up" button first, then "Mark Delivered"
    if (deliveryMethod == 'Pickup at Coop') {
      if (coopStatus == 'ready_for_pickup' && status == 'processing') {
        // Show "Picked Up" button when seller marked it ready (coopStatus)
        buttons.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _markAsPickedUp(orderId),
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Picked Up'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        );
      } else if (status == 'ready_for_pickup') {
        // Show "Mark as Delivered" after picked up
        buttons.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateOrderStatus(orderId, 'delivered'),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark as Delivered'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        );
      }
    } else if (isCoopDelivery) {
      // FOR COOPERATIVE DELIVERY: Use normal flow

      // For pending orders - show Approve button
      if (status == 'pending') {
        buttons.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateOrderStatus(orderId, 'processing'),
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Approve Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        );
      }

      // For ready_for_shipping, ready_for_pickup, or processing orders - mark as out for delivery
      else if (status == 'ready_for_shipping' ||
          status == 'ready_for_pickup' ||
          status == 'processing') {
        buttons.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateOrderStatus(orderId, 'shipped'),
              icon: const Icon(Icons.local_shipping, size: 18),
              label: const Text('Out for Delivery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        );
      }

      // For shipped orders - mark as delivered
      else if (status == 'shipped') {
        buttons.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateOrderStatus(orderId, 'delivered'),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark as Delivered'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        );
      }
    }

    // For delivered orders
    if (status == 'delivered') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
            const SizedBox(width: 8),
            Text(
              'Order Completed',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      );
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: buttons,
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

  Future<void> _markAsPickedUp(String orderId) async {
    try {
      // Get order details first
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderDoc.data()!;
      final buyerId = orderData['buyerId'] ?? orderData['userId'];
      final productName = orderData['productName'] ?? 'Product';

      // Update both status and coopStatus to indicate item has been picked up by cooperative
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'ready_for_pickup',
        'coopStatus': 'picked_up',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to buyer that order is now ready for pickup
      if (buyerId != null) {
        await _firestore.collection('notifications').add({
          'userId': buyerId,
          'orderId': orderId,
          'type': 'order_status',
          'status': 'ready_for_pickup',
          'title': '✅ Order Ready for Pickup!',
          'body':
              'Your order for $productName is ready for pickup at the cooperative!',
          'message': 'Your order for $productName is ready for pickup!',
          'productName': productName,
          'productId': orderData['productId'],
          'productImage': orderData['productImage'] ?? '',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'isRead': false,
        });

        // Send PUSH NOTIFICATION
        try {
          await RealtimeNotificationService.sendTestNotification(
            title: '✅ Order Ready for Pickup!',
            body:
                'Your order for $productName is ready for pickup at the cooperative!',
            payload:
                'order_status|$orderId|${orderData['productId']}|$productName',
          );
          print('✅ Push notification sent to buyer about ready for pickup');
        } catch (e) {
          print('⚠️ Error sending push notification: $e');
        }
      }

      // Refresh the dashboard stats
      _loadDashboardStats();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order marked as picked up and buyer notified!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error marking as picked up: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      // Get order details first to retrieve buyer and seller IDs
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderDoc.data()!;
      final buyerId = orderData['buyerId'] ?? orderData['userId'];
      final sellerId = orderData['sellerId'];
      final productName = orderData['productName'] ?? 'Product';
      final quantity = orderData['quantity'] ?? 1;
      final unit = orderData['unit'] ?? '';

      // Update order status
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If status is 'processing' (approved), send notifications to both buyer and seller
      if (newStatus == 'processing') {
        final batch = _firestore.batch();

        // Notification for BUYER
        if (buyerId != null) {
          final buyerNotificationRef =
              _firestore.collection('notifications').doc();
          batch.set(buyerNotificationRef, {
            'userId': buyerId,
            'title': '✅ Order Approved',
            'body':
                'Your order for $quantity $unit of $productName has been approved!',
            'message':
                'Your order for $quantity $unit of $productName is now being prepared.',
            'type': 'order_status',
            'status': 'processing',
            'orderId': orderId,
            'productId': orderData['productId'],
            'productName': productName,
            'productImage': orderData['productImage'] ?? '',
            'quantity': quantity,
            'unit': unit,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });

          // Send PUSH NOTIFICATION to buyer
          try {
            await RealtimeNotificationService.sendTestNotification(
              title: '✅ Order Approved',
              body:
                  'Your order for $quantity $unit of $productName has been approved!',
              payload:
                  'order_status|$orderId|${orderData['productId']}|$productName',
            );
            print('✅ Push notification sent to buyer about order approval');
          } catch (e) {
            print('⚠️ Error sending push notification to buyer: $e');
          }
        }

        // Notification for SELLER
        if (sellerId != null) {
          final sellerNotificationRef =
              _firestore.collection('notifications').doc();
          batch.set(sellerNotificationRef, {
            'userId': sellerId,
            'title': '✅ Order Approved by Cooperative',
            'body':
                'Order for $quantity $unit of $productName has been approved for delivery',
            'message':
                'The cooperative has approved the order for $quantity $unit of $productName.',
            'type': 'order_status',
            'status': 'processing',
            'orderId': orderId,
            'productId': orderData['productId'],
            'productName': productName,
            'productImage': orderData['productImage'] ?? '',
            'quantity': quantity,
            'unit': unit,
            'customerName': orderData['customerName'] ?? 'Customer',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });

          // Send PUSH NOTIFICATION to seller
          try {
            await RealtimeNotificationService.sendTestNotification(
              title: '✅ Order Approved by Cooperative',
              body:
                  'Order for $quantity $unit of $productName has been approved for delivery',
              payload:
                  'order_status|$orderId|${orderData['productId']}|$productName',
            );
            print('✅ Push notification sent to seller about order approval');
          } catch (e) {
            print('⚠️ Error sending push notification to seller: $e');
          }
        }

        // Commit all notifications
        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Order APPROVED. Buyer and seller have been notified.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
      // If status is 'shipped' (out for delivery), send notifications to both buyer and seller
      else if (newStatus == 'shipped') {
        final batch = _firestore.batch();

        // Notification for BUYER
        if (buyerId != null) {
          final buyerNotificationRef =
              _firestore.collection('notifications').doc();
          batch.set(buyerNotificationRef, {
            'userId': buyerId,
            'title': '🚚 Order Out for Delivery',
            'body':
                'Your order for $quantity $unit of $productName is out for delivery!',
            'message':
                'Your order for $quantity $unit of $productName is on the way to you.',
            'type': 'order_status',
            'status': 'shipped',
            'orderId': orderId,
            'productId': orderData['productId'],
            'productName': productName,
            'productImage': orderData['productImage'] ?? '',
            'quantity': quantity,
            'unit': unit,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });

          // Send PUSH NOTIFICATION to buyer
          try {
            await RealtimeNotificationService.sendTestNotification(
              title: '🚚 Order Out for Delivery',
              body:
                  'Your order for $quantity $unit of $productName is out for delivery!',
              payload:
                  'order_status|$orderId|${orderData['productId']}|$productName',
            );
            print('✅ Push notification sent to buyer about out for delivery');
          } catch (e) {
            print('⚠️ Error sending push notification to buyer: $e');
          }
        }

        // Notification for SELLER
        if (sellerId != null) {
          final sellerNotificationRef =
              _firestore.collection('notifications').doc();
          batch.set(sellerNotificationRef, {
            'userId': sellerId,
            'title': '🚚 Order Out for Delivery',
            'body':
                'Your order for $quantity $unit of $productName is being delivered',
            'message':
                'The cooperative is delivering $quantity $unit of $productName to the customer.',
            'type': 'order_status',
            'status': 'shipped',
            'orderId': orderId,
            'productId': orderData['productId'],
            'productName': productName,
            'productImage': orderData['productImage'] ?? '',
            'quantity': quantity,
            'unit': unit,
            'customerName': orderData['customerName'] ?? 'Customer',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });

          // Send PUSH NOTIFICATION to seller
          try {
            await RealtimeNotificationService.sendTestNotification(
              title: '🚚 Order Out for Delivery',
              body:
                  'Your order for $quantity $unit of $productName is being delivered',
              payload:
                  'order_status|$orderId|${orderData['productId']}|$productName',
            );
            print('✅ Push notification sent to seller about out for delivery');
          } catch (e) {
            print('⚠️ Error sending push notification to seller: $e');
          }
        }

        // Commit all notifications
        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Order marked as OUT FOR DELIVERY. Buyer and seller have been notified.'),
            backgroundColor: Colors.purple,
            duration: Duration(seconds: 4),
          ),
        );
      }
      // If status is 'delivered', send notifications to both buyer and seller
      else if (newStatus == 'delivered') {
        final batch = _firestore.batch();

        // Notification for BUYER
        if (buyerId != null) {
          final buyerNotificationRef =
              _firestore.collection('notifications').doc();
          batch.set(buyerNotificationRef, {
            'userId': buyerId,
            'title': '✅ Order Delivered',
            'body':
                'Your order for $quantity $unit of $productName has been delivered!',
            'message':
                'Your order for $quantity $unit of $productName has been delivered successfully.',
            'type': 'order_status',
            'status': 'delivered',
            'orderId': orderId,
            'productId': orderData['productId'],
            'productName': productName,
            'productImage': orderData['productImage'] ?? '',
            'quantity': quantity,
            'unit': unit,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });

          // Send PUSH NOTIFICATION to buyer
          try {
            await RealtimeNotificationService.sendTestNotification(
              title: '✅ Order Delivered',
              body:
                  'Your order for $quantity $unit of $productName has been delivered!',
              payload:
                  'order_status|$orderId|${orderData['productId']}|$productName',
            );
            print('✅ Push notification sent to buyer');
          } catch (e) {
            print('⚠️ Error sending push notification to buyer: $e');
          }
        }

        // Notification for SELLER
        if (sellerId != null) {
          final sellerNotificationRef =
              _firestore.collection('notifications').doc();
          batch.set(sellerNotificationRef, {
            'userId': sellerId,
            'title': '✅ Order Completed',
            'body':
                'Order for $quantity $unit of $productName has been delivered to customer',
            'message':
                'The cooperative has confirmed delivery of $quantity $unit of $productName to the customer.',
            'type': 'order_status',
            'status': 'delivered',
            'orderId': orderId,
            'productId': orderData['productId'],
            'productName': productName,
            'productImage': orderData['productImage'] ?? '',
            'quantity': quantity,
            'unit': unit,
            'customerName': orderData['customerName'] ?? 'Customer',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });

          // Send PUSH NOTIFICATION to seller
          try {
            await RealtimeNotificationService.sendTestNotification(
              title: '✅ Order Completed',
              body:
                  'Order for $quantity $unit of $productName has been delivered to customer',
              payload:
                  'order_status|$orderId|${orderData['productId']}|$productName',
            );
            print('✅ Push notification sent to seller');
          } catch (e) {
            print('⚠️ Error sending push notification to seller: $e');
          }
        }

        // Commit all notifications
        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Order marked as DELIVERED. Buyer and seller have been notified with push notifications.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to ${newStatus.toUpperCase()}'),
            backgroundColor: Colors.green,
          ),
        );
      }

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

// ========== COOPERATIVE REPORTS VIEW WIDGET ==========
class _CooperativeReportsView extends StatefulWidget {
  final FirebaseFirestore firestore;

  const _CooperativeReportsView({required this.firestore});

  @override
  _CooperativeReportsViewState createState() => _CooperativeReportsViewState();
}

class _CooperativeReportsViewState extends State<_CooperativeReportsView> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedSellerId;
  String? _selectedStatus;
  bool _isLoading = false;

  // Report data
  List<Map<String, dynamic>> _transactions = [];
  double _totalSales = 0;
  double _totalDeliveryFees = 0;
  double _totalPayoutToSellers = 0;
  int _totalOrders = 0;
  double _cooperativeEarnings = 0;

  List<Map<String, dynamic>> _sellers = [];

  @override
  void initState() {
    super.initState();
    // Set default date range to current month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _loadSellers();
    _generateReport();
  }

  /// Generate a clean order number from the order ID
  String _getOrderNumber(String orderId) {
    // Handle timestamp-based order IDs: order_1234567890123_productId
    if (orderId.startsWith('order_') && orderId.contains('_')) {
      final parts = orderId.split('_');
      if (parts.length >= 3) {
        // Extract timestamp
        final timestamp = int.tryParse(parts[1]);
        if (timestamp != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final dateStr =
              '${date.day.toString().padLeft(2, '0')}${date.month.toString().padLeft(2, '0')}${date.year.toString().substring(2)}';
          // Format: DDMMYY-XXXX (last 4 of timestamp)
          return '$dateStr-${parts[1].substring(parts[1].length - 4)}';
        }
      }
    }

    // For Firebase auto-generated IDs, use first 4 + last 4
    if (orderId.length > 12) {
      return '${orderId.substring(0, 4)}-${orderId.substring(orderId.length - 4)}'
          .toUpperCase();
    }

    return orderId.toUpperCase();
  }

  Future<void> _loadSellers() async {
    try {
      final sellersSnapshot = await widget.firestore
          .collection('users')
          .where('role', isEqualTo: 'seller')
          .get();

      setState(() {
        _sellers = sellersSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? data['fullName'] ?? 'Unknown Seller',
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading sellers: $e');
    }
  }

  Future<void> _generateReport() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date range')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Query query = widget.firestore.collection('orders');

      // Apply status filter
      if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
        query = query.where('status', isEqualTo: _selectedStatus);
      } else {
        // Default to delivered orders
        query = query.where('status', isEqualTo: 'delivered');
      }

      // Apply seller filter
      if (_selectedSellerId != null && _selectedSellerId!.isNotEmpty) {
        query = query.where('sellerId', isEqualTo: _selectedSellerId);
      }

      final ordersSnapshot = await query.get();

      // Filter by date range and calculate totals
      List<Map<String, dynamic>> transactions = [];
      double totalSales = 0;
      double totalDeliveryFees = 0;
      double totalPayoutToSellers = 0;
      int totalOrders = 0;

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;

        if (timestamp != null) {
          final orderDate = timestamp.toDate();
          // Normalize dates for comparison (ignore time component)
          final orderDateOnly =
              DateTime(orderDate.year, orderDate.month, orderDate.day);
          final startDateOnly =
              DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
          final endDateOnly =
              DateTime(_endDate!.year, _endDate!.month, _endDate!.day);

          if ((orderDateOnly.isAfter(startDateOnly) ||
                  orderDateOnly.isAtSameMomentAs(startDateOnly)) &&
              (orderDateOnly.isBefore(endDateOnly) ||
                  orderDateOnly.isAtSameMomentAs(endDateOnly))) {
            final totalAmount = (data['totalAmount'] ?? 0).toDouble();
            final deliveryFee = (data['deliveryFee'] ?? 0).toDouble();
            final subtotal =
                (data['subtotal'] ?? (totalAmount - deliveryFee)).toDouble();

            // Fetch seller name
            final sellerId = data['sellerId'];

            String buyerName = data['customerName'] ?? 'Unknown';
            String sellerName = 'Unknown';

            // Fetch seller name
            if (sellerId != null) {
              try {
                final sellerDoc = await widget.firestore
                    .collection('users')
                    .doc(sellerId)
                    .get();
                if (sellerDoc.exists) {
                  final sellerData = sellerDoc.data();
                  sellerName = sellerData?['name'] ??
                      sellerData?['fullName'] ??
                      'Unknown';
                }
              } catch (e) {
                print('Error fetching seller: $e');
              }
            }

            transactions.add({
              'orderId': doc.id,
              'buyerName': buyerName,
              'sellerName': sellerName,
              'productName': data['productName'] ?? 'Unknown',
              'quantity': data['quantity'] ?? 1,
              'totalPrice': totalAmount,
              'deliveryFee': deliveryFee,
              'amountToSeller': subtotal,
              'dateCompleted': timestamp.toDate(),
              'status': data['status'] ?? 'unknown',
            });

            totalSales += totalAmount;
            totalDeliveryFees += deliveryFee;
            totalPayoutToSellers += subtotal;
            totalOrders++;
          }
        }
      }

      // Sort transactions by date (newest first)
      transactions
          .sort((a, b) => b['dateCompleted'].compareTo(a['dateCompleted']));

      setState(() {
        _transactions = transactions;
        _totalSales = totalSales;
        _totalDeliveryFees = totalDeliveryFees;
        _totalPayoutToSellers = totalPayoutToSellers;
        _totalOrders = totalOrders;
        _cooperativeEarnings =
            totalDeliveryFees; // Cooperative earns from delivery fees
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
        // If end date is before start date, adjust it
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate =
              DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      });
      _generateReport();
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
      _generateReport();
    }
  }

  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();

      // Load a font that supports peso symbol
      final font = await PdfGoogleFonts.notoSansRegular();
      final fontBold = await PdfGoogleFonts.notoSansBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a3.landscape,
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(
            base: font,
            bold: fontBold,
          ),
          build: (pw.Context context) {
            return [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green700,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Cooperative Transaction Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Period: ${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generated: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())}',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Summary Cards
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildPdfSummaryCard(
                        'Total Sales', '₱${_totalSales.toStringAsFixed(2)}'),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: _buildPdfSummaryCard('Delivery Fees',
                        '₱${_totalDeliveryFees.toStringAsFixed(2)}'),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: _buildPdfSummaryCard('Payout to Sellers',
                        '₱${_totalPayoutToSellers.toStringAsFixed(2)}'),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child:
                        _buildPdfSummaryCard('Total Orders', '$_totalOrders'),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Transactions Table
              pw.Text(
                'Transaction Details',
                style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900),
              ),
              pw.SizedBox(height: 12),

              if (_transactions.isEmpty)
                pw.Center(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(20),
                    child: pw.Text('No transactions found for this period.',
                        style: const pw.TextStyle(
                            fontSize: 12, color: PdfColors.grey600)),
                  ),
                )
              else
                pw.Table(
                  border:
                      pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2.5),
                    4: const pw.FlexColumnWidth(1),
                    5: const pw.FlexColumnWidth(1.8),
                    6: const pw.FlexColumnWidth(1.5),
                    7: const pw.FlexColumnWidth(1.8),
                    8: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    // Header
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.green100),
                      children: [
                        _buildPdfTableCell('Order ID', isHeader: true),
                        _buildPdfTableCell('Buyer', isHeader: true),
                        _buildPdfTableCell('Seller', isHeader: true),
                        _buildPdfTableCell('Product', isHeader: true),
                        _buildPdfTableCell('Qty', isHeader: true),
                        _buildPdfTableCell('Total', isHeader: true),
                        _buildPdfTableCell('Delivery', isHeader: true),
                        _buildPdfTableCell('To Seller', isHeader: true),
                        _buildPdfTableCell('Date', isHeader: true),
                      ],
                    ),
                    // Data rows
                    ..._transactions.map((tx) {
                      return pw.TableRow(
                        children: [
                          _buildPdfTableCell(
                              _getOrderNumber(tx['orderId'].toString())),
                          _buildPdfTableCell(tx['buyerName']),
                          _buildPdfTableCell(tx['sellerName']),
                          _buildPdfTableCell(tx['productName']),
                          _buildPdfTableCell('${tx['quantity']}'),
                          _buildPdfTableCell(
                              '₱${tx['totalPrice'].toStringAsFixed(2)}'),
                          _buildPdfTableCell(
                              '₱${tx['deliveryFee'].toStringAsFixed(2)}'),
                          _buildPdfTableCell(
                              '₱${tx['amountToSeller'].toStringAsFixed(2)}'),
                          _buildPdfTableCell(DateFormat('MM/dd/yy')
                              .format(tx['dateCompleted'])),
                        ],
                      );
                    }).toList(),
                  ],
                ),

              pw.SizedBox(height: 20),

              // Totals
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.green700, width: 2),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    _buildPdfRow(
                        'Total Sales:', '₱${_totalSales.toStringAsFixed(2)}'),
                    pw.Divider(),
                    _buildPdfRow('Total Delivery Fees:',
                        '₱${_totalDeliveryFees.toStringAsFixed(2)}'),
                    pw.Divider(),
                    _buildPdfRow('Total Payout to Sellers:',
                        '₱${_totalPayoutToSellers.toStringAsFixed(2)}'),
                    pw.Divider(),
                    _buildPdfRow('Cooperative Earnings:',
                        '₱${_cooperativeEarnings.toStringAsFixed(2)}',
                        isBold: true),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      // Save PDF directly to Downloads
      final pdfBytes = await pdf.save();
      final fileName =
          'Cooperative_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

      // Save to Downloads directory
      if (Platform.isAndroid) {
        final directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(pdfBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved to Downloads/$fileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'OPEN',
                textColor: Colors.white,
                onPressed: () async {
                  await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
                },
              ),
            ),
          );
        }
      } else {
        // For iOS or other platforms, use share
        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  pw.Widget _buildPdfSummaryCard(String title, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green900),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.green900 : PdfColors.black,
        ),
        overflow: pw.TextOverflow.clip,
        maxLines: 2,
      ),
    );
  }

  pw.Widget _buildPdfRow(String label, String value,
      {bool isBold = false, double fontSize = 14}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isBold ? PdfColors.green900 : PdfColors.black,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.green.shade50, Colors.white],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade600, Colors.green.shade800],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.assessment, color: Colors.white, size: 40),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaction Reports',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Track sales, delivery fees, and seller payouts',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Sales',
                  '₱${_totalSales.toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Delivery Fees',
                  '₱${_totalDeliveryFees.toStringAsFixed(2)}',
                  Icons.local_shipping,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Payout to Sellers',
                  '₱${_totalPayoutToSellers.toStringAsFixed(2)}',
                  Icons.account_balance_wallet,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Orders',
                  '$_totalOrders',
                  Icons.shopping_bag,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters Card
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.filter_list,
                          color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Filters',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date Range Picker
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border:
                          Border.all(color: Colors.green.shade300, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                color: Colors.green.shade700, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Report Period',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // From Date
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _selectStartDate,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Ink(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.green.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'From',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const Spacer(),
                                            Icon(Icons.edit_calendar,
                                                color: Colors.green.shade600,
                                                size: 14),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _startDate != null
                                              ? DateFormat('MMM dd, yyyy')
                                                  .format(_startDate!)
                                              : 'Select date',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: _startDate != null
                                                ? Colors.green.shade900
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward,
                                  color: Colors.green.shade400, size: 20),
                            ),
                            // To Date
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _selectEndDate,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Ink(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.green.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'To',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const Spacer(),
                                            Icon(Icons.edit_calendar,
                                                color: Colors.green.shade600,
                                                size: 14),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _endDate != null
                                              ? DateFormat('MMM dd, yyyy')
                                                  .format(_endDate!)
                                              : 'Select date',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: _endDate != null
                                                ? Colors.green.shade900
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_startDate != null && _endDate != null) ...[
                          const SizedBox(height: 10),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_endDate!.difference(_startDate!).inDays + 1} days selected',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Date Presets
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDatePresetChip('Today', () {
                        final now = DateTime.now();
                        setState(() {
                          _startDate = DateTime(now.year, now.month, now.day);
                          _endDate = DateTime(
                              now.year, now.month, now.day, 23, 59, 59);
                        });
                        _generateReport();
                      }),
                      _buildDatePresetChip('Last 7 Days', () {
                        final now = DateTime.now();
                        setState(() {
                          _startDate = DateTime(now.year, now.month, now.day)
                              .subtract(const Duration(days: 6));
                          _endDate = DateTime(
                              now.year, now.month, now.day, 23, 59, 59);
                        });
                        _generateReport();
                      }),
                      _buildDatePresetChip('This Month', () {
                        final now = DateTime.now();
                        setState(() {
                          _startDate = DateTime(now.year, now.month, 1);
                          _endDate = DateTime(
                              now.year, now.month, now.day, 23, 59, 59);
                        });
                        _generateReport();
                      }),
                      _buildDatePresetChip('Last 30 Days', () {
                        final now = DateTime.now();
                        setState(() {
                          _startDate = DateTime(now.year, now.month, now.day)
                              .subtract(const Duration(days: 29));
                          _endDate = DateTime(
                              now.year, now.month, now.day, 23, 59, 59);
                        });
                        _generateReport();
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Seller Filter
                  DropdownButtonFormField<String>(
                    value: _selectedSellerId,
                    decoration: InputDecoration(
                      labelText: 'Filter by Seller (Optional)',
                      prefixIcon:
                          Icon(Icons.person, color: Colors.green.shade700),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('All Sellers')),
                      ..._sellers.map((seller) {
                        return DropdownMenuItem<String>(
                          value: seller['id'] as String?,
                          child: Text(seller['name'] as String),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSellerId = value;
                      });
                      _generateReport();
                    },
                  ),
                  const SizedBox(height: 12),

                  // Status Filter
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Filter by Status (Optional)',
                      prefixIcon: Icon(Icons.check_circle,
                          color: Colors.green.shade700),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: null, child: Text('Delivered Only')),
                      DropdownMenuItem(
                          value: 'delivered', child: Text('Delivered')),
                      DropdownMenuItem(
                          value: 'shipped', child: Text('Shipped')),
                      DropdownMenuItem(
                          value: 'processing', child: Text('Processing')),
                      DropdownMenuItem(
                          value: 'cancelled', child: Text('Cancelled')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                      _generateReport();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Generate Report Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _generateReport,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh),
                      label:
                          Text(_isLoading ? 'Generating...' : 'Refresh Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Transactions Table
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.list_alt,
                              color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Transaction Details',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _transactions.isEmpty ? null : _exportToPDF,
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('Export PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_transactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'No transactions found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try adjusting your filters',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          MaterialStateProperty.all(Colors.green.shade50),
                      columns: const [
                        DataColumn(
                            label: Text('Order ID',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        DataColumn(
                            label: Text('Buyer',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        DataColumn(
                            label: Text('Seller',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        DataColumn(
                            label: Text('Product',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        DataColumn(
                            label: Text('Qty',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        DataColumn(
                            label: Text('Total Price',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        DataColumn(
                            label: Text('Delivery Fee',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        DataColumn(
                            label: Text('To Seller',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        DataColumn(
                            label: Text('Date',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                      ],
                      rows: _transactions.map((tx) {
                        return DataRow(
                          cells: [
                            DataCell(Text(
                                tx['orderId'].toString().length > 12
                                    ? tx['orderId']
                                            .toString()
                                            .substring(0, 12) +
                                        '...'
                                    : tx['orderId'].toString(),
                                style: const TextStyle(fontSize: 11))),
                            DataCell(Text(tx['buyerName'],
                                style: const TextStyle(fontSize: 11))),
                            DataCell(Text(tx['sellerName'],
                                style: const TextStyle(fontSize: 11))),
                            DataCell(
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 150),
                                child: Text(
                                  tx['productName'],
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text('${tx['quantity']}',
                                style: const TextStyle(fontSize: 11))),
                            DataCell(Text(
                                '₱${tx['totalPrice'].toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11))),
                            DataCell(Text(
                                '₱${tx['deliveryFee'].toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11))),
                            DataCell(Text(
                                '₱${tx['amountToSeller'].toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11))),
                            DataCell(Text(
                                DateFormat('MMM dd, yyyy')
                                    .format(tx['dateCompleted']),
                                style: const TextStyle(fontSize: 11))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                if (_transactions.isNotEmpty) ...[
                  const Divider(height: 1),
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.green.shade50,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Sales:',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                            Text('₱${_totalSales.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Delivery Fees:',
                                style: TextStyle(fontSize: 14)),
                            Text('₱${_totalDeliveryFees.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Payout to Sellers:',
                                style: TextStyle(fontSize: 14)),
                            Text('₱${_totalPayoutToSellers.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Cooperative Earnings:',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade900)),
                            Text('₱${_cooperativeEarnings.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade900)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.green.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 14, color: Colors.green.shade700),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.green.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== COOPERATIVE PAYOUTS VIEW ==========
class _CooperativePayoutsView extends StatefulWidget {
  final FirebaseFirestore firestore;

  const _CooperativePayoutsView({required this.firestore});

  @override
  _CooperativePayoutsViewState createState() => _CooperativePayoutsViewState();
}

class _CooperativePayoutsViewState extends State<_CooperativePayoutsView> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _sellers = [];
  Map<String, Map<String, dynamic>> _sellerEarnings = {};
  List<Map<String, dynamic>> _payoutHistory = [];
  String? _selectedSellerId;

  @override
  void initState() {
    super.initState();
    _loadSellers();
    _loadPayoutHistory();
  }

  Future<void> _loadSellers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all sellers (approved or with status 'approved')
      final sellersSnapshot = await widget.firestore
          .collection('users')
          .where('role', isEqualTo: 'seller')
          .get();

      final sellers = <Map<String, dynamic>>[];
      final earnings = <String, Map<String, dynamic>>{};

      for (var doc in sellersSnapshot.docs) {
        final sellerData = doc.data();
        final sellerId = doc.id;

        // Check if seller is approved (either isApproved field or status field)
        final isApproved = sellerData['isApproved'] == true ||
            sellerData['status'] == 'approved';

        // Only include approved sellers
        if (!isApproved) continue;

        final sellerName =
            sellerData['name'] ?? sellerData['fullName'] ?? 'Unknown';

        sellers.add({
          'id': sellerId,
          'name': sellerName,
          'email': sellerData['email'] ?? '',
          'phone': sellerData['phone'] ?? '',
        });

        // Calculate earnings for each seller
        final earningsData = await _calculateSellerEarnings(sellerId);
        earnings[sellerId] = earningsData;
      }

      setState(() {
        _sellers = sellers;
        _sellerEarnings = earnings;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading sellers: $e');
      setState(() {
        _isLoading = false;
      });

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sellers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _calculateSellerEarnings(String sellerId) async {
    try {
      // Get all delivered/completed orders for this seller
      final ordersSnapshot = await widget.firestore
          .collection('orders')
          .where('sellerId', isEqualTo: sellerId)
          .where('status', whereIn: ['delivered', 'completed']).get();

      double totalEarnings = 0;
      double paidAmount = 0;
      double pendingAmount = 0;
      int totalOrders = 0;
      int paidOrders = 0;
      int pendingOrders = 0;
      List<Map<String, dynamic>> pendingPayouts = [];

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        final orderId = doc.id;
        final totalAmount = (data['totalAmount'] ?? 0).toDouble();
        final deliveryFee = (data['deliveryFee'] ?? 0).toDouble();
        final subtotal =
            (data['subtotal'] ?? (totalAmount - deliveryFee)).toDouble();
        final payoutStatus = data['payoutStatus'] ?? 'pending';

        totalEarnings += subtotal;
        totalOrders++;

        if (payoutStatus == 'paid') {
          paidAmount += subtotal;
          paidOrders++;
        } else {
          pendingAmount += subtotal;
          pendingOrders++;

          // Add to pending payouts list
          pendingPayouts.add({
            'orderId': orderId,
            'productName': data['productName'] ?? 'Unknown',
            'buyerName': data['customerName'] ?? 'Unknown',
            'amount': subtotal,
            'orderDate': data['createdAt'],
            'quantity': data['quantity'] ?? 1,
          });
        }
      }

      return {
        'totalEarnings': totalEarnings,
        'paidAmount': paidAmount,
        'pendingAmount': pendingAmount,
        'totalOrders': totalOrders,
        'paidOrders': paidOrders,
        'pendingOrders': pendingOrders,
        'pendingPayouts': pendingPayouts,
      };
    } catch (e) {
      print('Error calculating earnings for $sellerId: $e');
      return {
        'totalEarnings': 0.0,
        'paidAmount': 0.0,
        'pendingAmount': 0.0,
        'totalOrders': 0,
        'paidOrders': 0,
        'pendingOrders': 0,
        'pendingPayouts': [],
      };
    }
  }

  String _getOrderNumber(String orderId) {
    if (orderId.startsWith('order_') && orderId.contains('_')) {
      final parts = orderId.split('_');
      if (parts.length >= 3) {
        final timestamp = int.tryParse(parts[1]);
        if (timestamp != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final dateStr =
              '${date.day.toString().padLeft(2, '0')}${date.month.toString().padLeft(2, '0')}${date.year.toString().substring(2)}';
          return '$dateStr-${parts[1].substring(parts[1].length - 4)}';
        }
      }
    }
    if (orderId.length > 12) {
      return '${orderId.substring(0, 4)}-${orderId.substring(orderId.length - 4)}'
          .toUpperCase();
    }
    return orderId.toUpperCase();
  }

  Future<void> _loadPayoutHistory() async {
    try {
      print('========================================');
      print('COOP: Loading payout history...');

      final payoutsSnapshot = await widget.firestore
          .collection('seller_payouts')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      print(
          'COOP: Found ${payoutsSnapshot.docs.length} payout records in database');

      List<Map<String, dynamic>> validPayouts = [];
      List<String> invalidPayoutIds = [];
      Set<String> seenReferences =
          {}; // Track reference numbers to detect duplicates

      for (var doc in payoutsSnapshot.docs) {
        final data = doc.data();

        print('COOP: Processing payout ${doc.id}');
        print('  Seller: ${data['sellerName']}');
        print('  Amount: ${data['totalAmount']}');
        print('  Orders: ${data['orderCount']}');
        print('  Reference: ${data['referenceNumber']}');

        // Check for duplicate reference numbers
        final refNumber = data['referenceNumber']?.toString() ?? '';
        if (refNumber.isNotEmpty && seenReferences.contains(refNumber)) {
          print('  -> DUPLICATE detected! Will delete.');
          invalidPayoutIds.add(doc.id);
          continue;
        }
        if (refNumber.isNotEmpty) {
          seenReferences.add(refNumber);
        }

        // Keep all payout records - they are historical records of payments made
        print('  -> Valid payout, adding to list');
        validPayouts.add({
          'id': doc.id,
          ...data,
        });
      }

      // Delete invalid payout records
      if (invalidPayoutIds.isNotEmpty) {
        print(
            'COOP: Deleting ${invalidPayoutIds.length} duplicate payout records...');
        for (var payoutId in invalidPayoutIds) {
          await widget.firestore
              .collection('seller_payouts')
              .doc(payoutId)
              .delete();
          print('COOP: Deleted payout record: $payoutId');
        }
      }

      setState(() {
        _payoutHistory = validPayouts;
      });

      print('COOP: Final payout history count: ${validPayouts.length}');
      print('========================================');
    } catch (e) {
      print('COOP: Error loading payout history: $e');
      print('COOP: Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _processPayouts(
      String sellerId,
      List<Map<String, dynamic>> payouts,
      String paymentMethod,
      String reference,
      String notes) async {
    try {
      final batch = widget.firestore.batch();
      final sellerData = _sellers.firstWhere((s) => s['id'] == sellerId);
      final sellerName = sellerData['name'];

      // Calculate total amount and collect order IDs
      double totalAmount = 0.0;
      List<String> orderIds = [];

      for (var payout in payouts) {
        final orderId = payout['orderId'];
        orderIds.add(orderId);
        totalAmount += payout['amount'];

        final orderRef = widget.firestore.collection('orders').doc(orderId);

        // Update order with payout info
        batch.update(orderRef, {
          'payoutStatus': 'paid',
          'payoutDate': FieldValue.serverTimestamp(),
          'payoutMethod': paymentMethod,
          'payoutReference': reference,
          'payoutNotes': notes,
          'payoutBy': 'cooperative',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Check for existing payout with same reference number to prevent duplicates
      final existingPayout = await widget.firestore
          .collection('seller_payouts')
          .where('referenceNumber', isEqualTo: reference)
          .where('sellerId', isEqualTo: sellerId)
          .limit(1)
          .get();

      if (existingPayout.docs.isNotEmpty) {
        print('Payout with reference $reference already exists. Skipping.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This payment has already been processed'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Create a single combined payout record
      final payoutRef = widget.firestore.collection('seller_payouts').doc();

      print('Creating payout record for seller: $sellerId');
      print('Total amount: $totalAmount');
      print('Order count: ${orderIds.length}');

      batch.set(payoutRef, {
        'orderIds': orderIds,
        'orderCount': orderIds.length,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'referenceNumber': reference,
        'notes': notes,
        'payoutDate': FieldValue.serverTimestamp(),
        'processedBy': 'cooperative',
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Committing batch write...');
      await batch.commit();
      print('Batch committed successfully');
      await _loadSellers();
      await _loadPayoutHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully paid ${payouts.length} orders to $sellerName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error processing payouts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing payouts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.green.shade50, Colors.white],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadSellers,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade800],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet,
                        color: Colors.white, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Seller Payouts',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage and process seller earnings',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _loadSellers();
                        _loadPayoutHistory();
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_sellers.isEmpty)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Icon(Icons.people_outline,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'No sellers found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ...(_sellers.map((seller) {
                final sellerId = seller['id'];
                final earnings = _sellerEarnings[sellerId];

                // Add null check and default values
                if (earnings == null) return const SizedBox.shrink();

                final hasPending = (earnings['pendingAmount'] ?? 0.0) > 0;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: hasPending
                          ? Colors.orange.shade200
                          : Colors.grey.shade200,
                      width: hasPending ? 2 : 1,
                    ),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: Icon(Icons.person, color: Colors.green.shade700),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            seller['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (hasPending)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Pending',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${earnings['totalOrders']} orders • ₱${earnings['totalEarnings'].toStringAsFixed(2)} total',
                      style: const TextStyle(fontSize: 12),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildEarningsCard(
                                    'Total Earnings',
                                    '₱${earnings['totalEarnings'].toStringAsFixed(2)}',
                                    Icons.attach_money,
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildEarningsCard(
                                    'Paid',
                                    '₱${earnings['paidAmount'].toStringAsFixed(2)}',
                                    Icons.check_circle,
                                    Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildEarningsCard(
                                    'Pending',
                                    '₱${earnings['pendingAmount'].toStringAsFixed(2)}',
                                    Icons.pending_actions,
                                    Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildEarningsCard(
                                    'Orders',
                                    '${earnings['pendingOrders']}/${earnings['totalOrders']}',
                                    Icons.shopping_bag,
                                    Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: hasPending
                                    ? () async {
                                        // Pay immediately without confirmation
                                        final pendingPayouts =
                                            List<Map<String, dynamic>>.from(
                                                earnings['pendingPayouts'] ??
                                                    []);

                                        if (pendingPayouts.isEmpty) return;

                                        // Show processing indicator
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Row(
                                              children: [
                                                SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Text('Processing payout...'),
                                              ],
                                            ),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );

                                        await _processPayouts(
                                          sellerId,
                                          pendingPayouts,
                                          'GCash', // Default payment method
                                          'AUTO-${DateTime.now().millisecondsSinceEpoch}', // Auto-generated reference
                                          'Automatic payout by cooperative',
                                        );
                                      }
                                    : null,
                                icon: const Icon(Icons.payments, size: 18),
                                label: Text(
                                  hasPending
                                      ? 'Pay ₱${(earnings['pendingAmount'] ?? 0.0).toStringAsFixed(2)}'
                                      : 'No Pending Payouts',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  disabledForegroundColor: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList()),

            // Payout History Section
            const SizedBox(height: 24),
            const Divider(thickness: 2),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.history, color: Colors.green.shade700, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Payout History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_payoutHistory.isEmpty)
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No payout history yet',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...(_payoutHistory.map((payout) {
                final payoutDate = payout['createdAt'] != null
                    ? (payout['createdAt'] as Timestamp).toDate()
                    : DateTime.now();
                final formattedDate =
                    '${payoutDate.day}/${payoutDate.month}/${payoutDate.year} ${payoutDate.hour}:${payoutDate.minute.toString().padLeft(2, '0')}';

                // Get order count and total amount (new combined format)
                final orderCount = payout['orderCount'] ?? 1;
                final totalAmount =
                    payout['totalAmount'] ?? payout['amount'] ?? 0.0;

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: Icon(Icons.check_circle,
                          color: Colors.green.shade700, size: 20),
                    ),
                    title: Text(
                      payout['sellerName'] ?? 'Unknown Seller',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '$orderCount ${orderCount == 1 ? 'order' : 'orders'} paid',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          formattedDate,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                        if (payout['paymentMethod'] != null)
                          Text(
                            'Method: ${payout['paymentMethod']}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                        if (payout['referenceNumber'] != null)
                          Text(
                            'Ref: ${payout['referenceNumber']}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₱${totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green.shade700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'PAID',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}
