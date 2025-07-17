import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'seller_product_dashboard.dart';
import 'seller_order_management.dart';
import 'seller_analytics.dart';
import '../account_screen.dart';
import 'seller_inventory_management.dart';
import '../virtual_wallet_screen.dart';

class ComprehensiveSellerDashboard extends StatefulWidget {
  const ComprehensiveSellerDashboard({Key? key}) : super(key: key);

  @override
  State<ComprehensiveSellerDashboard> createState() =>
      _ComprehensiveSellerDashboardState();
}

class _ComprehensiveSellerDashboardState
    extends State<ComprehensiveSellerDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (_auth.currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final sellerId = _auth.currentUser!.uid;
      Map<String, dynamic> data = {};

      // Get seller products count
      final productsQuery = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .get();

      data['totalProducts'] = productsQuery.docs.length;
      data['approvedProducts'] = productsQuery.docs
          .where((doc) => doc.data()['status'] == 'approved')
          .length;
      data['pendingProducts'] = productsQuery.docs
          .where((doc) => doc.data()['status'] == 'pending')
          .length;

      // Get orders for seller's products
      List<String> productIds =
          productsQuery.docs.map((doc) => doc.id).toList();
      int totalOrders = 0;
      int pendingOrders = 0;

      if (productIds.isNotEmpty) {
        for (int i = 0; i < productIds.length; i += 10) {
          final batch = productIds.skip(i).take(10).toList();

          final ordersQuery = await _firestore
              .collection('orders')
              .where('productId', whereIn: batch)
              .get();

          totalOrders += ordersQuery.docs.length;
          pendingOrders += ordersQuery.docs
              .where((doc) => doc.data()['status'] == 'pending')
              .length;
        }
      }

      data['totalOrders'] = totalOrders;
      data['pendingOrders'] = pendingOrders;

      // Get wallet balance
      try {
        final walletDoc =
            await _firestore.collection('wallets').doc(sellerId).get();
        if (walletDoc.exists) {
          data['walletBalance'] = walletDoc.data()?['balance'] ?? 0.0;
        } else {
          data['walletBalance'] = 0.0;
        }
      } catch (e) {
        data['walletBalance'] = 0.0;
      }

      // Get unread notifications
      final notificationsQuery = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: sellerId)
          .where('read', isEqualTo: false)
          .get();

      data['unreadNotifications'] = notificationsQuery.docs.length;

      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Dashboard'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if ((_dashboardData['unreadNotifications'] ?? 0) > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${_dashboardData['unreadNotifications']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    _buildWelcomeSection(),
                    const SizedBox(height: 24),

                    // Quick Stats
                    _buildQuickStats(),
                    const SizedBox(height: 24),

                    // Quick Actions
                    _buildQuickActions(),
                    const SizedBox(height: 24),

                    // Recent Activity
                    _buildRecentActivity(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeSection() {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.withOpacity(0.1),
              Colors.green.withOpacity(0.05)
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your products, orders, and grow your business',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  'Wallet Balance: ${_formatCurrency(_dashboardData['walletBalance'] ?? 0.0)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Total Products',
              '${_dashboardData['totalProducts'] ?? 0}',
              Icons.inventory,
              Colors.blue,
            ),
            _buildStatCard(
              'Pending Orders',
              '${_dashboardData['pendingOrders'] ?? 0}',
              Icons.pending_actions,
              Colors.orange,
            ),
            _buildStatCard(
              'Approved Products',
              '${_dashboardData['approvedProducts'] ?? 0}',
              Icons.check_circle,
              Colors.green,
            ),
            _buildStatCard(
              'Pending Products',
              '${_dashboardData['pendingProducts'] ?? 0}',
              Icons.hourglass_empty,
              Colors.amber,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.2,
          children: [
            _buildActionCard(
              'Manage Products',
              'View and edit your products',
              Icons.inventory_2,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SellerProductDashboard()),
              ),
            ),
            _buildActionCard(
              'Orders',
              'Manage customer orders',
              Icons.shopping_bag,
              Colors.orange,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SellerOrderManagement()),
              ),
            ),
            _buildActionCard(
              'Browse Products',
              'Shop from other sellers',
              Icons.shopping_cart,
              Colors.red,
              () => Navigator.pushNamed(context, '/buyer-browse'),
            ),
            _buildActionCard(
              'Inventory',
              'Manage product stock',
              Icons.warehouse,
              Colors.indigo,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SellerInventoryManagement()),
              ),
            ),
            _buildActionCard(
              'Analytics',
              'View sales and performance',
              Icons.analytics,
              Colors.purple,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SellerAnalytics()),
              ),
            ),
            _buildActionCard(
              'Account',
              'Manage account settings',
              Icons.person,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountScreen()),
              ),
            ),
            _buildActionCard(
              'Add Product',
              'List new products',
              Icons.add_circle,
              Colors.teal,
              () => Navigator.pushNamed(context, '/add-product'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const Spacer(),
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
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Access',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle, color: Colors.green),
                title: const Text('Add New Product'),
                subtitle: const Text('List a new product for sale'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => Navigator.pushNamed(context, '/add-product'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet,
                    color: Colors.purple),
                title: const Text('Virtual Wallet'),
                subtitle: Text(
                    'Balance: ${_formatCurrency(_dashboardData['walletBalance'] ?? 0.0)}'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const VirtualWalletScreen()),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.help_outline, color: Colors.blue),
                title: const Text('Help & Support'),
                subtitle: const Text('Get help with selling'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Navigate to help screen
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.grey),
                title: const Text('Settings'),
                subtitle: const Text('App preferences'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Navigate to settings screen
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
