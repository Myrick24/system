import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'buyer/buyer_home_content.dart';
import 'account_screen.dart';
import 'cart_screen.dart';
import 'messages_screen.dart';
import 'seller/comprehensive_seller_dashboard.dart';

class UnifiedMainDashboard extends StatefulWidget {
  const UnifiedMainDashboard({Key? key}) : super(key: key);

  @override
  State<UnifiedMainDashboard> createState() => _UnifiedMainDashboardState();
}

class _UnifiedMainDashboardState extends State<UnifiedMainDashboard> {
  int _selectedIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSellerApproved = false;
  bool _isLoading = true;

  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _checkSellerStatus();
  }

  Future<void> _checkSellerStatus() async {
    setState(() {
      _isLoading = true;
    });

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        // Check if user is registered as a seller
        final sellerQuery = await _firestore
            .collection('sellers')
            .where('email', isEqualTo: currentUser.email)
            .limit(1)
            .get();

        if (sellerQuery.docs.isNotEmpty) {
          final sellerData = sellerQuery.docs.first.data();
          String status = sellerData['status'] ?? 'approved';

          setState(() {
            _isSellerApproved = status == 'active' || status == 'approved';
          });
        }
      } catch (e) {
        print('Error checking seller status: $e');
      }
    }

    _setupPages();
    setState(() {
      _isLoading = false;
    });
  }

  void _setupPages() {
    _pages = [
      const BuyerHomeContent(), // Home for everyone
      const BuyerOrdersScreen(), // Orders for everyone
      const CartScreen(), // Cart for everyone
      const MessagesScreen(), // Messages for everyone
      const AccountScreen(), // Account for everyone (with seller registration)
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      );
    }

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
        onTap: _onItemTapped,
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
      // Show seller floating action button if user is an approved seller
      floatingActionButton: _isSellerApproved
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ComprehensiveSellerDashboard(),
                  ),
                );
              },
              backgroundColor: Colors.green,
              child: const Icon(Icons.store, color: Colors.white),
              tooltip: 'Seller Dashboard',
            )
          : null,
    );
  }
}

// Keep the existing BuyerOrdersScreen class here or import it
class BuyerOrdersScreen extends StatefulWidget {
  const BuyerOrdersScreen({Key? key}) : super(key: key);

  @override
  State<BuyerOrdersScreen> createState() => _BuyerOrdersScreenState();
}

class _BuyerOrdersScreenState extends State<BuyerOrdersScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _completedOrders = [];
  List<Map<String, dynamic>> _cancelledOrders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      _loadOrdersByTab(_tabController.index);
    });
    _loadOrdersByTab(0); // Load active orders initially
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrdersByTab(int tabIndex) async {
    if (_auth.currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String status;
      switch (tabIndex) {
        case 0:
          status = 'active';
          break;
        case 1:
          status = 'completed';
          break;
        case 2:
          status = 'cancelled';
          break;
        default:
          status = 'active';
      }

      final ordersQuery = await _firestore
          .collection('orders')
          .where('buyerId', isEqualTo: _auth.currentUser!.uid)
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> orders = [];
      for (var doc in ordersQuery.docs) {
        Map<String, dynamic> orderData = doc.data();
        orderData['id'] = doc.id;
        orders.add(orderData);
      }

      setState(() {
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
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading orders: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
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
          _buildOrdersList(_activeOrders),
          _buildOrdersList(_completedOrders),
          _buildOrdersList(_cancelledOrders),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> orders) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No orders found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.1),
              child: const Icon(Icons.shopping_bag, color: Colors.green),
            ),
            title: Text(
              order['productName'] ?? 'Unknown Product',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seller: ${order['sellerName'] ?? 'Unknown'}'),
                Text('Quantity: ${order['quantity'] ?? 0}'),
                Text('Total: ₱${(order['total'] ?? 0.0).toStringAsFixed(2)}'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(order['status']),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                order['status']?.toUpperCase() ?? 'UNKNOWN',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
