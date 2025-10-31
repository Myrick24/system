import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'buyer_home_content.dart';
import '../account_screen.dart';
import '../cart_screen.dart';
import '../messages_screen.dart';

class BuyerMainDashboard extends StatefulWidget {
  const BuyerMainDashboard({Key? key}) : super(key: key);

  @override
  State<BuyerMainDashboard> createState() => _BuyerMainDashboardState();
}

class _BuyerMainDashboardState extends State<BuyerMainDashboard>
    with AutomaticKeepAliveClientMixin {
  int _selectedIndex = 0;
  final GlobalKey<_BuyerOrdersScreenState> _ordersKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const BuyerHomeContent(), // Home products
      BuyerOrdersScreen(key: _ordersKey), // Order history with key
      const CartScreen(), // Shopping cart
      const MessagesScreen(), // Chat with sellers
      const AccountScreen(
          key: PageStorageKey('AccountScreen')), // Account and seller registration
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
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
          print('=== BuyerMainDashboard: Tab tapped: $index ===');
          setState(() {
            _selectedIndex = index;
          });
          
          // When Orders tab (index 1) is selected, refresh the orders
          if (index == 1) {
            print('=== Orders tab selected, refreshing orders ===');
            _ordersKey.currentState?._loadOrdersByTab(_ordersKey.currentState!._tabController.index);
          }
          
          print('=== BuyerMainDashboard: _selectedIndex set to: $_selectedIndex ===');
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
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
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _completedOrders = [];
  List<Map<String, dynamic>> _cancelledOrders = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      _loadOrdersByTab(_tabController.index);
    });
    _loadOrdersByTab(0);
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
    _tabController.dispose();
    super.dispose();
  }

  // Public method to refresh orders from outside
  void refreshOrders() {
    print('🔄 BuyerOrdersScreen: Public refresh called');
    _loadOrdersByTab(_tabController.index);
  }

  Future<void> _loadOrdersByTab(int tabIndex) async {
    if (_auth.currentUser == null) {
      print('❌ BuyerOrdersScreen: No current user logged in');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _auth.currentUser!.uid;
      print('');
      print('=====================================');
      print('🔍 LOADING ORDERS FOR TAB $tabIndex');
      print('👤 User ID: $userId');
      print('=====================================');
      
      List<String> statuses;

      switch (tabIndex) {
        case 0: // Active
          statuses = ['pending', 'processing', 'shipped'];
          break;
        case 1: // Completed
          statuses = ['delivered'];
          break;
        case 2: // Cancelled
          statuses = ['cancelled', 'rejected'];
          break;
        default:
          statuses = ['pending'];
      }

      print('📋 Looking for statuses: $statuses');

      // FIRST: Check ALL orders in Firestore
      print('');
      print('--- CHECKING ALL ORDERS IN DATABASE ---');
      final allOrdersSnapshot = await _firestore.collection('orders').get();
      print('📦 Total orders in Firestore: ${allOrdersSnapshot.docs.length}');
      
      if (allOrdersSnapshot.docs.isNotEmpty) {
        print('');
        print('Sample of ALL orders:');
        for (var doc in allOrdersSnapshot.docs.take(5)) {
          final data = doc.data();
          print('  • Order ${doc.id.substring(0, 15)}...');
          print('    buyerId: ${data['buyerId']}');
          print('    status: ${data['status']}');
          print('    product: ${data['productName']}');
          print('    timestamp: ${data['timestamp']}');
        }
      }

      List<Map<String, dynamic>> orders = [];

      for (String status in statuses) {
        print('');
        print('--- Querying status: "$status" ---');
        
        // Query by buyerId (primary field)
        final buyerIdQuery = await _firestore
            .collection('orders')
            .where('buyerId', isEqualTo: userId)
            .where('status', isEqualTo: status)
            .get();

        print('✅ Found ${buyerIdQuery.docs.length} orders with buyerId="$userId" AND status="$status"');

        for (var doc in buyerIdQuery.docs) {
          final orderData = doc.data();
          orderData['id'] = doc.id;
          orders.add(orderData);
          print('  ➕ Added: ${doc.id.substring(0, 15)}... - ${orderData['productName']}');
        }

        // Also query by userId (fallback for old orders)
        try {
          final userIdQuery = await _firestore
              .collection('orders')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: status)
              .get();

          print('✅ Found ${userIdQuery.docs.length} orders with userId="$userId" AND status="$status"');

          for (var doc in userIdQuery.docs) {
            // Check if this order is not already in the list (avoid duplicates)
            if (!orders.any((order) => order['id'] == doc.id)) {
              final orderData = doc.data();
              orderData['id'] = doc.id;
              orders.add(orderData);
              print('  ➕ Added (via userId): ${doc.id.substring(0, 15)}... - ${orderData['productName']}');
            } else {
              print('  ⏭️ Skipped (duplicate): ${doc.id.substring(0, 15)}...');
            }
          }
        } catch (e) {
          print('⚠️ Error querying by userId: $e');
          // Continue even if this query fails
        }
      }

      print('');
      print('=====================================');
      print('📊 TOTAL ORDERS FOUND: ${orders.length}');
      print('=====================================');
      print('');

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
          break;
        case 1:
          _completedOrders = orders;
          break;
        case 2:
          _cancelledOrders = orders;
          break;
      }
    } catch (e) {
      print('Error loading orders: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                Text(
                  'Order #${order['id'].toString().substring(0, 8)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order['status']),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (order['status'] ?? 'PENDING').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: widget.showBackButton,
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
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
                        Text(
                          'Order #${order['id'].toString().substring(0, 8)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order['status']),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            (order['status'] ?? 'PENDING').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
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
