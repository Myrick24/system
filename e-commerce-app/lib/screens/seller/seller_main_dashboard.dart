import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'seller_product_dashboard.dart';
import 'seller_order_management.dart';
import 'seller_inventory_management.dart';
import 'seller_analytics.dart';
import 'seller_profile_management.dart';
import 'add_product_screen.dart';
import 'notifications_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/realtime_notification_widgets.dart';
import '../../services/cooperative_chat_service.dart';

class SellerMainDashboard extends StatefulWidget {
  const SellerMainDashboard({Key? key}) : super(key: key);

  @override
  State<SellerMainDashboard> createState() => _SellerMainDashboardState();
}

class _SellerMainDashboardState extends State<SellerMainDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _sellerName = '';
  bool _isLoading = true;
  Map<String, dynamic> _dashboardStats = {
    'totalProducts': 0,
    'activeProducts': 0,
    'pendingOrders': 0,
    'completedOrders': 0,
    'totalRevenue': 0.0,
    'lowStockProducts': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadSellerInfo();
    _loadDashboardStats();
  }

  Future<void> _loadSellerInfo() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Get seller info from Firestore
        final sellerQuery = await _firestore
            .collection('sellers')
            .where('email', isEqualTo: currentUser.email)
            .limit(1)
            .get();

        if (sellerQuery.docs.isNotEmpty) {
          final sellerData = sellerQuery.docs.first.data();
          setState(() {
            _sellerName = sellerData['fullName'] ?? 'Seller';
          });
        }
      }
    } catch (e) {
      print('Error loading seller info: $e');
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get seller products
      final productsQuery = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: currentUser.uid)
          .get();

      // Get seller orders
      final ordersQuery = await _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: currentUser.uid)
          .get();

      int totalProducts = productsQuery.docs.length;
      int activeProducts = productsQuery.docs
          .where((doc) =>
              doc.data()['status'] == 'approved' &&
              doc.data()['isActive'] == true)
          .length;

      // Check for low stock products - consider both 'stock' and 'quantity' fields
      // Low stock threshold: less than or equal to 5 units
      int lowStockProducts = 0;
      for (var doc in productsQuery.docs) {
        final data = doc.data();
        final productName = data['name'] ?? data['productName'] ?? 'Unknown';
        final stock =
            data['stock'] ?? data['quantity'] ?? data['currentStock'] ?? 0;

        int stockValue = 0;
        if (stock is int) {
          stockValue = stock;
        } else if (stock is double) {
          stockValue = stock.toInt();
        } else if (stock is String) {
          try {
            stockValue = int.parse(stock);
          } catch (e) {
            print('Error parsing stock for product $productName: $e');
            continue;
          }
        }

        // Debug: Print stock levels
        print('Product: $productName, Stock: $stockValue');

        // Only count as low stock if 5 or less
        if (stockValue <= 5) {
          lowStockProducts++;
          print('LOW STOCK: $productName has only $stockValue units');
        }
      }

      int pendingOrders = ordersQuery.docs
          .where((doc) => doc.data()['status'] == 'pending')
          .length;
      int completedOrders = ordersQuery.docs
          .where((doc) =>
              doc.data()['status'] == 'completed' ||
              doc.data()['status'] == 'delivered')
          .length;

      double totalRevenue = 0.0;
      for (var order in ordersQuery.docs) {
        final status = order.data()['status'];
        if (status == 'completed' || status == 'delivered') {
          final amount = order.data()['totalAmount'];
          if (amount != null) {
            totalRevenue +=
                (amount is int ? amount.toDouble() : amount.toDouble());
          }
        }
      }

      setState(() {
        _dashboardStats = {
          'totalProducts': totalProducts,
          'activeProducts': activeProducts,
          'pendingOrders': pendingOrders,
          'completedOrders': completedOrders,
          'totalRevenue': totalRevenue,
          'lowStockProducts': lowStockProducts,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Dashboard'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.primaryGradientDecoration,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.store,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome back!',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        _sellerName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Manage your products and track your sales performance',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Quick Stats Section
                      const Text(
                        'Quick Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats Grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.3,
                        children: [
                          _buildStatCard(
                            'Total Products',
                            _dashboardStats['totalProducts'].toString(),
                            Icons.inventory,
                            AppTheme.primaryGreen,
                          ),
                          _buildStatCard(
                            'Active Products',
                            _dashboardStats['activeProducts'].toString(),
                            Icons.check_circle,
                            AppTheme.primaryGreenLight,
                          ),
                          _buildStatCard(
                            'Pending Orders',
                            _dashboardStats['pendingOrders'].toString(),
                            Icons.pending,
                            AppTheme.accentOrange,
                          ),
                          _buildStatCard(
                            'Total Revenue',
                            '₱${_dashboardStats['totalRevenue'].toStringAsFixed(2)}',
                            Icons.monetization_on,
                            AppTheme.primaryGreenDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Quick Actions Section
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action Cards
                      Column(
                        children: [
                          _buildActionCard(
                            'Manage Products',
                            'Add, edit, and view your product listings',
                            Icons.inventory_2,
                            AppTheme.primaryGreen,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SellerProductDashboard(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildActionCard(
                            'Order Management',
                            'View and manage customer orders',
                            Icons.shopping_cart,
                            AppTheme.primaryGreenLight,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SellerOrderManagement(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildActionCard(
                            'Inventory Control',
                            'Track stock levels and manage inventory',
                            Icons.warehouse,
                            AppTheme.accentOrange,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SellerInventoryManagement(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildActionCard(
                            'Sales Analytics',
                            'View sales reports and performance metrics',
                            Icons.analytics,
                            AppTheme.accentPurple,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SellerAnalytics(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildActionCard(
                            'Profile Settings',
                            'Update your seller profile and information',
                            Icons.person_outline,
                            AppTheme.primaryGreenDark,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SellerProfileManagement(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Alerts Section (if any)
                      if (_dashboardStats['lowStockProducts'] > 0) ...[
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SellerInventoryManagement(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.errorColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.red.shade600,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Low Stock Alert',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_dashboardStats['lowStockProducts']} ${_dashboardStats['lowStockProducts'] == 1 ? 'product has' : 'products have'} low stock (5 units or less)',
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to view and restock',
                                        style: TextStyle(
                                          color: Colors.red.shade600,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.red.shade600,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Pending Orders Alert
                      if (_dashboardStats['pendingOrders'] > 0) ...[
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SellerOrderManagement(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.accentOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      AppTheme.accentOrange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.pending_actions,
                                    color: Colors.orange.shade700,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pending Orders',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'You have ${_dashboardStats['pendingOrders']} ${_dashboardStats['pendingOrders'] == 1 ? 'order' : 'orders'} waiting for processing',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to review and process',
                                        style: TextStyle(
                                          color: Colors.orange.shade600,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.orange.shade600,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Contact Cooperative Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () async {
                            final currentUser = _auth.currentUser;
                            if (currentUser != null) {
                              try {
                                final userDoc = await _firestore
                                    .collection('users')
                                    .doc(currentUser.uid)
                                    .get();

                                if (userDoc.exists) {
                                  final userData =
                                      userDoc.data() as Map<String, dynamic>;
                                  final cooperativeId =
                                      userData['cooperativeId'] as String?;

                                  if (cooperativeId != null) {
                                    final coopDoc = await _firestore
                                        .collection('users')
                                        .doc(cooperativeId)
                                        .get();

                                    if (coopDoc.exists) {
                                      final cooperativeName =
                                          coopDoc.data()?['name'] ??
                                              'Cooperative';

                                      await CooperativeChatService
                                          .startSellerCooperativeChat(
                                        context: context,
                                        cooperativeId: cooperativeId,
                                        cooperativeName: cooperativeName,
                                      );
                                    }
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'You are not assigned to a cooperative yet'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.support_agent,
                                    color: Colors.blue.shade700,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Contact Cooperative',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Get help and support from your cooperative',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey.shade400,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
