import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    'confirmed',
    'processing',
    'ready',
    'delivered',
    'completed'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _loadDashboardStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ordersSnapshot = await _firestore.collection('orders').get();

      int totalOrders = ordersSnapshot.docs.length;
      int pendingOrders = 0;
      int readyForPickup = 0;
      int inDelivery = 0;
      int completed = 0;
      int unpaidCOD = 0;
      double totalRevenue = 0.0;
      double pendingPayments = 0.0;

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? 'pending';
        final paymentMethod = data['paymentMethod'] ?? '';
        final totalAmount = (data['totalAmount'] ?? 0.0).toDouble();

        // Count by status
        if (status == 'pending' || status == 'confirmed') {
          pendingOrders++;
        } else if (status == 'ready') {
          readyForPickup++;
        } else if (status == 'processing' || status == 'shipped') {
          inDelivery++;
        } else if (status == 'delivered' || status == 'completed') {
          completed++;
          totalRevenue += totalAmount;
        }

        // Track Cash on Delivery payments
        if (paymentMethod == 'Cash on Delivery' &&
            status != 'delivered' &&
            status != 'completed') {
          unpaidCOD++;
          pendingPayments += totalAmount;
        }
      }

      setState(() {
        _stats = {
          'totalOrders': totalOrders,
          'pendingOrders': pendingOrders,
          'readyForPickup': readyForPickup,
          'inDelivery': inDelivery,
          'completed': completed,
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
                    backgroundColor: Colors.green.shade700,
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
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.local_shipping), text: 'Deliveries'),
            Tab(icon: Icon(Icons.store), text: 'Pickups'),
            Tab(icon: Icon(Icons.payments), text: 'Payments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildDeliveriesTab(),
          _buildPickupsTab(),
          _buildPaymentsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadDashboardStats,
        backgroundColor: Colors.green.shade700,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
    );
  }

  // ========== OVERVIEW TAB ==========
  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Welcome Header with Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business, size: 40, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cooperative Dashboard',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage deliveries, pickups & payments',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Priority Actions - What needs attention NOW
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.priority_high, color: Colors.orange.shade700, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Needs Your Attention',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildPriorityCard(
                        'Pending Orders',
                        _stats['pendingOrders']?.toString() ?? '0',
                        Icons.pending_actions,
                        Colors.orange,
                        'Need confirmation',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPriorityCard(
                        'COD to Collect',
                        _stats['unpaidCOD']?.toString() ?? '0',
                        Icons.attach_money,
                        Colors.red,
                        '₱${(_stats['pendingPayments'] ?? 0.0).toStringAsFixed(0)}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick Action Buttons - Prominent & Easy to Tap
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildLargeActionButton(
                  'View Deliveries',
                  Icons.local_shipping,
                  Colors.purple.shade600,
                  _stats['inDelivery']?.toString() ?? '0',
                  'in progress',
                  () => _tabController.animateTo(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLargeActionButton(
                  'View Pickups',
                  Icons.store,
                  Colors.blue.shade600,
                  _stats['readyForPickup']?.toString() ?? '0',
                  'ready',
                  () => _tabController.animateTo(2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Single row for Payments button
          _buildFullWidthActionButton(
            'Manage Payments',
            Icons.payments,
            Colors.green.shade600,
            'View all transactions',
            () => _tabController.animateTo(3),
          ),

          const SizedBox(height: 24),

          // Order Status Overview - Clear Visual Breakdown
          const Text(
            'Order Status Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatusRow(
                    'Total Orders',
                    _stats['totalOrders']?.toString() ?? '0',
                    Icons.shopping_bag,
                    Colors.blue.shade600,
                    'All time',
                  ),
                  const Divider(height: 24),
                  _buildStatusRow(
                    'In Progress',
                    _stats['inDelivery']?.toString() ?? '0',
                    Icons.autorenew,
                    Colors.purple.shade600,
                    'Being processed',
                  ),
                  const Divider(height: 24),
                  _buildStatusRow(
                    'Ready for Pickup',
                    _stats['readyForPickup']?.toString() ?? '0',
                    Icons.check_circle,
                    Colors.green.shade600,
                    'Waiting for customer',
                  ),
                  const Divider(height: 24),
                  _buildStatusRow(
                    'Completed',
                    _stats['completed']?.toString() ?? '0',
                    Icons.done_all,
                    Colors.teal.shade600,
                    'Successfully finished',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Financial Summary - Clear & Bold
          const Text(
            'Financial Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildFinancialRow(
                    'Total Revenue',
                    '₱${(_stats['totalRevenue'] ?? 0.0).toStringAsFixed(2)}',
                    Icons.trending_up,
                    Colors.green.shade700,
                    'From completed orders',
                  ),
                  const Divider(height: 32),
                  _buildFinancialRow(
                    'Pending COD',
                    '₱${(_stats['pendingPayments'] ?? 0.0).toStringAsFixed(2)}',
                    Icons.pending,
                    Colors.orange.shade700,
                    'Yet to be collected',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // New Priority Card for urgent items
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Large action button with badge
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 32, color: Colors.white),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Full width action button
  Widget _buildFullWidthActionButton(
    String title,
    IconData icon,
    Color color,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Colors.white),
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
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
          ],
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
          padding: const EdgeInsets.all(16),
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
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
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
                  if (order['customerContact'] != null || order['customerAddress'] != null) ...[
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

    if (status == 'pending' || status == 'confirmed') {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateOrderStatus(orderId, 'processing'),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Start'),
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

    if (status == 'processing' && deliveryMethod == 'Pickup at Coop') {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateOrderStatus(orderId, 'ready'),
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('Ready'),
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

    if (status == 'ready' ||
        (status == 'processing' && deliveryMethod == 'Cooperative Delivery')) {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateOrderStatus(orderId, 'delivered'),
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
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
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'ready':
        return Colors.green;
      case 'shipped':
      case 'delivered':
        return Colors.teal;
      case 'completed':
        return Colors.green.shade700;
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
      case 'confirmed':
        return Icons.check;
      case 'processing':
        return Icons.autorenew;
      case 'ready':
        return Icons.check_circle;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.done_all;
      case 'completed':
        return Icons.verified;
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
