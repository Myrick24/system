import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/cart_service.dart';
import 'buyer_home_content.dart';
import '../account_screen.dart';
import '../cart_screen.dart';
import '../unified_messages_screen.dart';
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
      const UnifiedMessagesScreen(), // Chat with sellers and cooperative
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
  String _sortBy = 'date_newest'; // Default sort option

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
          statuses = [
            'pending',
            'processing',
            'ready',
            'ready_for_pickup',
            'ready_for_shipping',
            'shipped'
          ];
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

      // Apply sorting based on selected option
      _sortOrders(orders, tabIndex);

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
      // Get order details to restore stock
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      final orderData = orderDoc.data();

      await _firestore.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Return stock to product inventory
      if (orderData != null) {
        final productId = orderData['productId'];
        final quantity = orderData['quantity'] ?? 0;

        if (productId != null && quantity > 0) {
          try {
            await _firestore.collection('products').doc(productId).update({
              'currentStock': FieldValue.increment(quantity),
            });
            print('Stock restored: +$quantity to product $productId');
          } catch (e) {
            print('Error restoring stock: $e');
            // Continue even if stock restoration fails
          }
        }
      }

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

  void _sortOrders(List<Map<String, dynamic>> orders, int tabIndex) {
    switch (_sortBy) {
      case 'date_newest':
        // Newest first (default)
        orders.sort((a, b) {
          // For cancelled orders (tab 2), sort by updatedAt (cancellation time)
          // For other tabs, sort by timestamp (order creation time)
          final aTime = (tabIndex == 2 && a['updatedAt'] != null)
              ? a['updatedAt'] as Timestamp?
              : a['timestamp'] as Timestamp?;
          final bTime = (tabIndex == 2 && b['updatedAt'] != null)
              ? b['updatedAt'] as Timestamp?
              : b['timestamp'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });
        break;
      case 'date_oldest':
        // Oldest first
        orders.sort((a, b) {
          // For cancelled orders (tab 2), sort by updatedAt (cancellation time)
          // For other tabs, sort by timestamp (order creation time)
          final aTime = (tabIndex == 2 && a['updatedAt'] != null)
              ? a['updatedAt'] as Timestamp?
              : a['timestamp'] as Timestamp?;
          final bTime = (tabIndex == 2 && b['updatedAt'] != null)
              ? b['updatedAt'] as Timestamp?
              : b['timestamp'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return aTime.compareTo(bTime);
        });
        break;
      case 'price_high':
        // Price: High to Low
        orders.sort((a, b) {
          final aPrice = (a['totalAmount'] ?? 0) as num;
          final bPrice = (b['totalAmount'] ?? 0) as num;
          return bPrice.compareTo(aPrice);
        });
        break;
      case 'price_low':
        // Price: Low to High
        orders.sort((a, b) {
          final aPrice = (a['totalAmount'] ?? 0) as num;
          final bPrice = (b['totalAmount'] ?? 0) as num;
          return aPrice.compareTo(bPrice);
        });
        break;
      case 'name_az':
        // Product Name: A-Z
        orders.sort((a, b) {
          final aName = (a['productName'] ?? '').toString().toLowerCase();
          final bName = (b['productName'] ?? '').toString().toLowerCase();
          return aName.compareTo(bName);
        });
        break;
      case 'name_za':
        // Product Name: Z-A
        orders.sort((a, b) {
          final aName = (a['productName'] ?? '').toString().toLowerCase();
          final bName = (b['productName'] ?? '').toString().toLowerCase();
          return bName.compareTo(aName);
        });
        break;
    }
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final bool isReservation = order['isReservation'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle Bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Status
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getStatusColor(order['status']),
                            _getStatusColor(order['status']).withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _getStatusColor(order['status'])
                                .withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _getStatusIcon(order['status']),
                                  color: _getStatusColor(order['status']),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Order #${_getOrderNumber(order['id'])}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isReservation) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.white.withOpacity(0.3),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'RESERVATION',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatStatusText(order['status']),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.95),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatTimestamp(order['timestamp']),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Product Details Section
                    _buildSectionTitle('Product Details', Icons.inventory_2),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.shopping_basket,
                                  color: Colors.green,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order['productName'] ?? 'Unknown Product',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                      'Quantity',
                                      '${order['quantity'] ?? 1} ${order['unit'] ?? ''}',
                                      Icons.analytics_outlined,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                      'Unit Price',
                                      '₱${(order['price'] ?? 0).toStringAsFixed(2)}',
                                      Icons.payments_outlined,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Subtotal',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '₱${(order['subtotal'] ?? (order['price'] ?? 0) * (order['quantity'] ?? 1)).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                if (order['deliveryFee'] != null &&
                                    order['deliveryFee'] > 0) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Delivery Fee',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        '₱${(order['deliveryFee'] ?? 0).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.account_balance_wallet,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Total Amount',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '₱${(order['totalAmount'] ?? 0).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
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

                    const SizedBox(height: 24),

                    // Order Information Section
                    _buildSectionTitle('Order Information', Icons.receipt_long),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          _buildDetailTile(
                            icon: Icons.payment,
                            title: 'Payment Method',
                            value: order['paymentMethod'] ?? 'Cash on Delivery',
                            color: Colors.blue,
                          ),
                          const Divider(height: 24),
                          _buildDetailTile(
                            icon: order['deliveryMethod'] == 'Delivery'
                                ? Icons.local_shipping
                                : Icons.store,
                            title: 'Delivery Method',
                            value: order['deliveryMethod'] ?? 'Pick-up',
                            color: Colors.purple,
                          ),
                          if (order['meetupLocation'] != null) ...[
                            const Divider(height: 24),
                            _buildDetailTile(
                              icon: Icons.location_on,
                              title: 'Meet-up Location',
                              value: order['meetupLocation'],
                              color: Colors.orange,
                            ),
                          ],
                          if (order['sellerName'] != null) ...[
                            const Divider(height: 24),
                            _buildDetailTile(
                              icon: Icons.storefront,
                              title: 'Seller',
                              value: order['sellerName'],
                              color: Colors.teal,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // Fixed Bottom Action Button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: order['status'] == 'pending'
                  ? SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showCancelDialog(order['id']);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cancel_outlined, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Cancel Order',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
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
    return Column(
      children: [
        // Sort dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.sort, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                'Sort by:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: _sortBy,
                  isExpanded: true,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.green),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'date_newest',
                      child: Text('Date (Newest First)'),
                    ),
                    DropdownMenuItem(
                      value: 'date_oldest',
                      child: Text('Date (Oldest First)'),
                    ),
                    DropdownMenuItem(
                      value: 'price_high',
                      child: Text('Price (High to Low)'),
                    ),
                    DropdownMenuItem(
                      value: 'price_low',
                      child: Text('Price (Low to High)'),
                    ),
                    DropdownMenuItem(
                      value: 'name_az',
                      child: Text('Product Name (A-Z)'),
                    ),
                    DropdownMenuItem(
                      value: 'name_za',
                      child: Text('Product Name (Z-A)'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _sortBy = value;
                      });
                      _loadOrdersByTab(_tabController.index);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // Orders list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadOrdersByTab(_tabController.index),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final bool isReservation = order['isReservation'] == true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _getStatusColor(order['status']).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _showOrderDetails(order),
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Section with Status
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order['status'])
                                .withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Status Icon
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(order['status']),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _getStatusIcon(order['status']),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Order Number and Status
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Order #${_getOrderNumber(order['id'])}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                  order['status']),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _formatStatusText(
                                                  order['status']),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                        if (isReservation) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.blue.withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.blue,
                                                width: 1,
                                              ),
                                            ),
                                            child: const Text(
                                              'RES',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Date
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatShortDate(order['timestamp']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Product Details Section
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Name with Icon
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order['productName'] ??
                                              'Unknown Product',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Qty: ${order['quantity'] ?? 1} ${order['unit'] ?? ''}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              // Order Details Row
                              Row(
                                children: [
                                  // Payment Method
                                  Expanded(
                                    child: _buildInfoChip(
                                      icon: Icons.payment,
                                      label: order['paymentMethod'] ?? 'COD',
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Delivery Method
                                  Expanded(
                                    child: _buildInfoChip(
                                      icon:
                                          order['deliveryMethod'] == 'Delivery'
                                              ? Icons.local_shipping
                                              : Icons.store,
                                      label:
                                          order['deliveryMethod'] ?? 'Pick-up',
                                      color: Colors.purple,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Price Section
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.withOpacity(0.1),
                                      Colors.green.withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Subtotal',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        Text(
                                          '₱${(order['subtotal'] ?? (order['price'] ?? 0) * (order['quantity'] ?? 1)).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Show delivery fee if it exists and is greater than 0 OR if delivery method is Cooperative Delivery
                                    if ((order['deliveryFee'] != null &&
                                            order['deliveryFee'] > 0) ||
                                        order['deliveryMethod'] ==
                                            'Cooperative Delivery') ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Delivery Fee',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          Text(
                                            '₱${((order['deliveryFee'] != null && order['deliveryFee'] > 0) ? order['deliveryFee'] : 50.0).toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Total Amount',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '₱${(order['totalAmount'] ?? 0).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
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

                        // Footer with action indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Tap to view full details',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'processing':
        return Icons.sync;
      case 'ready':
      case 'ready_for_pickup':
      case 'ready_for_shipping':
        return Icons.check_circle;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.shopping_bag;
    }
  }

  String _formatShortDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      final DateTime dateTime = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.parse(timestamp.toString());

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return 'N/A';
    }
  }
}
