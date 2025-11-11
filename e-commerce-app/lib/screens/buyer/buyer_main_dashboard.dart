import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/cart_service.dart';
import 'buyer_home_content.dart';
import '../account_screen.dart';
import '../cart_screen.dart';
import '../messages_screen.dart';
import '../notification_screen.dart';

class BuyerMainDashboard extends StatefulWidget {
  const BuyerMainDashboard({Key? key}) : super(key: key);

  @override
  State<BuyerMainDashboard> createState() => _BuyerMainDashboardState();
}

class _BuyerMainDashboardState extends State<BuyerMainDashboard>
    with AutomaticKeepAliveClientMixin {
  int _selectedIndex = 0;
  final GlobalKey<_BuyerOrdersScreenState> _ordersKey =
      GlobalKey<_BuyerOrdersScreenState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _unreadNotificationCount = 0;

  @override
  bool get wantKeepAlive => true;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const BuyerHomeContent(), // Home products
      BuyerOrdersScreen(key: _ordersKey), // Order history
      const CartScreen(), // Shopping cart
      const MessagesScreen(), // Chat with sellers
      const AccountScreen(
          key: PageStorageKey(
              'AccountScreen')), // Account and seller registration
    ];
    _listenToNotifications();
  }

  void _listenToNotifications() {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _unreadNotificationCount = snapshot.docs.length;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        title: const Text('AgriConnect'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Notification Bell Icon with Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
                },
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _unreadNotificationCount > 99
                          ? '99+'
                          : '$_unreadNotificationCount',
                      style: const TextStyle(
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
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          // Reload orders when Orders tab is selected
          if (index == 1) {
            print('=== Orders tab tapped, calling reloadOrders ===');
            print(
                '_ordersKey.currentState is null: ${_ordersKey.currentState == null}');
            _ordersKey.currentState?.reloadOrders();
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Orders',
          ),
          // Cart with badge
          BottomNavigationBarItem(
            icon: _buildCartBadge(),
            label: 'Cart',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }

  // Build cart icon with badge
  Widget _buildCartBadge() {
    return Selector<CartService, int>(
      selector: (context, cartService) => cartService.itemCount,
      builder: (context, itemCount, child) {
        print('🛒 Cart badge builder called - itemCount: $itemCount');
        return Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.shopping_cart),
            // Show badge if cart has items
            if (itemCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    itemCount > 99 ? '99+' : '$itemCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class BuyerOrdersScreen extends StatefulWidget {
  final bool showBackButton;

  const BuyerOrdersScreen({super.key, this.showBackButton = false});

  @override
  State<BuyerOrdersScreen> createState() => _BuyerOrdersScreenState();
}

class _BuyerOrdersScreenState extends State<BuyerOrdersScreen>
    with
        SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin,
        WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _completedOrders = [];
  List<Map<String, dynamic>> _cancelledOrders = [];
  bool _hasLoadedOnce = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _loadOrdersByTab(_tabController.index);
      }
    });
    _loadOrdersByTab(0);
    _hasLoadedOnce = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasLoadedOnce) {
      // Reload orders when app returns to foreground
      _loadOrdersByTab(_tabController.index);
    }
  }

  // This method is called every time the widget rebuilds
  @override
  void didUpdateWidget(BuyerOrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload orders when widget updates
    print('BuyerOrdersScreen: Widget updated, refreshing orders');
    _loadOrdersByTab(_tabController.index);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  // Public method to reload orders when tab is tapped
  void reloadOrders() {
    print('=== BuyerOrdersScreen.reloadOrders() called ===');
    _loadOrdersByTab(_tabController.index);
  }

  Future<void> _loadOrdersByTab(int tabIndex) async {
    if (_auth.currentUser == null) {
      print('ERROR: No user logged in');
      return;
    }

    print('=== Loading orders for tab $tabIndex ===');
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _auth.currentUser!.uid;
      print('User ID: $userId');
      List<String> statuses;

      switch (tabIndex) {
        case 0: // Active
          statuses = ['pending', 'processing', 'ready', 'ready_for_pickup', 'ready_for_shipping', 'shipped'];
          break;
        case 1: // Completed
          statuses = ['delivered', 'completed'];
          break;
        case 2: // Cancelled
          statuses = ['cancelled', 'rejected'];
          break;
        default:
          statuses = ['pending'];
      }

      print('Looking for orders with statuses: $statuses');

      // Query ALL orders for this user (no status filter to avoid index requirement)
      final buyerIdQuery = await _firestore
          .collection('orders')
          .where('buyerId', isEqualTo: userId)
          .get();

      print('Found ${buyerIdQuery.docs.length} orders with buyerId');

      List<Map<String, dynamic>> orders = [];

      // Filter by status in memory
      for (var doc in buyerIdQuery.docs) {
        final orderData = doc.data();
        final orderStatus = orderData['status'] as String?;

        if (orderStatus != null && statuses.contains(orderStatus)) {
          orderData['id'] = doc.id;
          orders.add(orderData);
          print(
              '  ➕ Added: ${doc.id.substring(0, 15)}... - ${orderData['productName']}');
        }
      }

      // Also query by userId (fallback for old orders)
      try {
        final userIdQuery = await _firestore
            .collection('orders')
            .where('userId', isEqualTo: userId)
            .get();

        print('Found ${userIdQuery.docs.length} orders with userId');

        for (var doc in userIdQuery.docs) {
          final orderData = doc.data();
          final orderStatus = orderData['status'] as String?;

          // Check if this order is not already in the list (avoid duplicates)
          // and has the correct status
          if (orderStatus != null &&
              statuses.contains(orderStatus) &&
              !orders.any((order) => order['id'] == doc.id)) {
            orderData['id'] = doc.id;
            orders.add(orderData);
          }
        }
      } catch (e) {
        print('Error querying by userId: $e');
        // Continue even if this query fails
      }

      print('=== TOTAL orders found: ${orders.length} ===');

      // Sort by timestamp
      orders.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      switch (tabIndex) {
        case 0:
          _activeOrders = orders;
          print('Set _activeOrders to ${_activeOrders.length} items');
          break;
        case 1:
          _completedOrders = orders;
          print('Set _completedOrders to ${_completedOrders.length} items');
          break;
        case 2:
          _cancelledOrders = orders;
          print('Set _cancelledOrders to ${_cancelledOrders.length} items');
          break;
      }
    } catch (e) {
      print('Error loading orders: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('=== Finished loading, _isLoading = false ===');
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _loadOrdersByTab(_tabController.index);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cancelled successfully'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel order: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Order #${_getOrderNumber(order['id'])}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  flex: 2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order['status']),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatStatusText(order['status']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Product Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Product Details',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                        'Product', order['productName'] ?? 'Unknown'),
                    _buildDetailRow('Quantity',
                        '${order['quantity'] ?? 1} ${order['unit'] ?? ''}'),
                    _buildDetailRow('Price',
                        '₱${(order['price'] ?? 0).toStringAsFixed(2)}'),
                    _buildDetailRow('Total',
                        '₱${(order['totalAmount'] ?? 0).toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),

            // Order Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Information',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Payment Method',
                        order['paymentMethod'] ?? 'Cash on Delivery'),
                    _buildDetailRow('Delivery Method',
                        order['deliveryMethod'] ?? 'Pick-up'),
                    if (order['meetupLocation'] != null)
                      _buildDetailRow(
                          'Meet-up Location', order['meetupLocation']),
                    _buildDetailRow(
                        'Order Date', _formatTimestamp(order['timestamp'])),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Action Buttons
            if (order['status'] == 'pending') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showCancelDialog(order['id']);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Cancel Order'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(String orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelOrder(orderId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  // Generate a clean order number from the order ID
  String _getOrderNumber(String orderId) {
    // If the ID is already in a nice format (like "order_17"), extract the number
    if (orderId.startsWith('order_')) {
      return orderId.replaceFirst('order_', '').toUpperCase();
    }
    
    // For long Firebase IDs, take first 6 characters for readability
    if (orderId.length > 12) {
      return orderId.substring(0, 12).toUpperCase();
    }
    
    // Otherwise use first 8 characters
    if (orderId.length > 8) {
      return orderId.substring(0, 8).toUpperCase();
    }
    
    return orderId.toUpperCase();
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      final DateTime dateTime = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.parse(timestamp.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'ready':
      case 'ready_for_pickup':
      case 'ready_for_shipping':
        return Colors.purple;
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'completed':
        return Colors.teal;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatStatusText(String? status) {
    if (status == null) return 'PENDING';
    
    // Replace underscores with spaces and convert to uppercase
    return status.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    print('=== BuyerOrdersScreen.build() called ===');
    print(
        '_activeOrders: ${_activeOrders.length}, _completedOrders: ${_completedOrders.length}, _cancelledOrders: ${_cancelledOrders.length}');
    print('_isLoading: $_isLoading');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Remove back button for bottom nav
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(_activeOrders),
          _buildOrderList(_completedOrders),
          _buildOrderList(_cancelledOrders),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<Map<String, dynamic>> orders) {
    print('=== _buildOrderList called with ${orders.length} orders ===');
    print('_isLoading: $_isLoading');

    if (_isLoading) {
      print('Showing loading indicator');
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      print('Orders list is empty, showing empty message');
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No orders found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    print('Building ListView with ${orders.length} orders');
    return RefreshIndicator(
      onRefresh: () => _loadOrdersByTab(_tabController.index),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () => _showOrderDetails(order),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Order #${_getOrderNumber(order['id'])}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(order['status']),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatStatusText(order['status']),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      order['productName'] ?? 'Unknown Product',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Qty: ${order['quantity'] ?? 1} ${order['unit'] ?? ''}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const Spacer(),
                        Text(
                          '₱${(order['totalAmount'] ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(order['timestamp']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
