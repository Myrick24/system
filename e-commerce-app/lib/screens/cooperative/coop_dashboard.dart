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
    'processing',
    'shipped',
    'delivered'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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

      // Send notification to seller
      await _firestore.collection('user_notifications').add({
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

  // Show product details dialog
  void _showProductDetails(Map<String, dynamic> product, String productId) {
    final status = product['status'] ?? 'pending';
    final imageUrl = product['imageUrl']; // Use imageUrl field directly

    // Get delivery options as list
    final deliveryOptions = product['deliveryOptions'] as List<dynamic>?;
    final deliveryText = deliveryOptions != null && deliveryOptions.isNotEmpty
        ? deliveryOptions.join(', ')
        : 'Not specified';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: status == 'approved'
                      ? Colors.green.shade100
                      : status == 'rejected'
                          ? Colors.red.shade100
                          : Colors.orange.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      status == 'approved'
                          ? Icons.check_circle
                          : status == 'rejected'
                              ? Icons.cancel
                              : Icons.pending,
                      color: status == 'approved'
                          ? Colors.green.shade700
                          : status == 'rejected'
                              ? Colors.red.shade700
                              : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        product['name'] ?? 'Product Details',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image
                      if (imageUrl != null &&
                          imageUrl.toString().isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
                                color: Colors.grey.shade200,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              height: 200,
                              color: Colors.grey.shade200,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image_not_supported,
                                      size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Image not available',
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Product Information Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Product Information',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.green.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow('Price',
                                '₱${product['price']?.toStringAsFixed(2) ?? '0.00'}'),
                            _buildDetailRow(
                                'Quantity', '${product['quantity'] ?? 0}'),
                            _buildDetailRow('Unit', product['unit'] ?? 'N/A'),
                            _buildDetailRow(
                                'Category', product['category'] ?? 'N/A'),
                            _buildDetailRow(
                                'Order Type', product['orderType'] ?? 'N/A'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Description Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Description',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product['description'] ??
                                  'No description provided',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Delivery & Location Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delivery & Location',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.purple.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow('Pickup Location',
                                product['pickupLocation'] ?? 'N/A'),
                            _buildDetailRow('Delivery Options', deliveryText),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Seller & Dates Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seller & Dates',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.orange.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow('Seller Name',
                                product['sellerName'] ?? 'Unknown'),
                            _buildDetailRow('Seller Email',
                                product['sellerEmail'] ?? 'N/A'),
                            _buildDetailRow(
                                'Harvest Date',
                                product['harvestDate'] != null
                                    ? (product['harvestDate'] as Timestamp)
                                        .toDate()
                                        .toString()
                                        .split(' ')[0]
                                    : 'N/A'),
                            if (product['orderType'] == 'Pre Order' &&
                                product['estimatedAvailabilityDate'] != null)
                              _buildDetailRow(
                                  'Est. Availability',
                                  (product['estimatedAvailabilityDate']
                                          as Timestamp)
                                      .toDate()
                                      .toString()
                                      .split(' ')[0]),
                            _buildDetailRow(
                                'Listed',
                                product['createdAt']
                                        ?.toDate()
                                        .toString()
                                        .split(' ')[0] ??
                                    'N/A'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: status == 'approved'
                              ? Colors.green.shade100
                              : status == 'rejected'
                                  ? Colors.red.shade100
                                  : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: status == 'approved'
                                ? Colors.green.shade300
                                : status == 'rejected'
                                    ? Colors.red.shade300
                                    : Colors.orange.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              status == 'approved'
                                  ? Icons.check_circle
                                  : status == 'rejected'
                                      ? Icons.cancel
                                      : Icons.hourglass_empty,
                              color: status == 'approved'
                                  ? Colors.green.shade700
                                  : status == 'rejected'
                                      ? Colors.red.shade700
                                      : Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Status: ${status.toUpperCase()}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: status == 'approved'
                                    ? Colors.green.shade900
                                    : status == 'rejected'
                                        ? Colors.red.shade900
                                        : Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (status == 'pending') ...[
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(context); // Close dialog first
                          await _updateProductStatus(productId, 'rejected');
                        },
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        label: const Text('Reject'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context); // Close dialog first
                          await _updateProductStatus(productId, 'approved');
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ] else ...[
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
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
          await _firestore.collection('user_notifications').add({
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
