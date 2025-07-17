import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellerAnalytics extends StatefulWidget {
  const SellerAnalytics({Key? key}) : super(key: key);

  @override
  State<SellerAnalytics> createState() => _SellerAnalyticsState();
}

class _SellerAnalyticsState extends State<SellerAnalytics> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  Map<String, dynamic> _analytics = {};
  String _selectedPeriod = 'This Month';

  final List<String> _periods = [
    'This Week',
    'This Month',
    'Last 3 Months',
    'This Year'
  ];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    if (_auth.currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final sellerId = _auth.currentUser!.uid;
      final analytics = await _getSellerAnalytics(sellerId);

      setState(() {
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _getSellerAnalytics(String sellerId) async {
    try {
      Map<String, dynamic> analytics = {};

      // Get date range based on selected period
      DateTime now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case 'This Week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'Last 3 Months':
          startDate = DateTime(now.year, now.month - 2, 1);
          break;
        case 'This Year':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, 1);
      }

      // Get seller products
      final productsQuery = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .get();

      List<String> productIds =
          productsQuery.docs.map((doc) => doc.id).toList();

      analytics['totalProducts'] = productsQuery.docs.length;
      analytics['approvedProducts'] = productsQuery.docs
          .where((doc) => doc.data()['status'] == 'approved')
          .length;
      analytics['pendingProducts'] = productsQuery.docs
          .where((doc) => doc.data()['status'] == 'pending')
          .length;

      if (productIds.isEmpty) {
        analytics['totalRevenue'] = 0.0;
        analytics['totalOrders'] = 0;
        analytics['completedOrders'] = 0;
        analytics['pendingOrders'] = 0;
        analytics['averageOrderValue'] = 0.0;
        analytics['topProducts'] = <Map<String, dynamic>>[];
        analytics['recentOrders'] = <Map<String, dynamic>>[];
        analytics['monthlyRevenue'] = <Map<String, double>>{};
        return analytics;
      }

      // Get orders for seller's products
      List<Map<String, dynamic>> allOrders = [];

      // Batch product IDs (Firestore 'in' limit is 10)
      for (int i = 0; i < productIds.length; i += 10) {
        final batch = productIds.skip(i).take(10).toList();

        final ordersQuery = await _firestore
            .collection('orders')
            .where('productId', whereIn: batch)
            .where('timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .get();

        for (var doc in ordersQuery.docs) {
          final orderData = doc.data();
          orderData['id'] = doc.id;
          allOrders.add(orderData);
        }
      }

      // Calculate analytics
      analytics['totalOrders'] = allOrders.length;
      analytics['completedOrders'] =
          allOrders.where((order) => order['status'] == 'delivered').length;
      analytics['pendingOrders'] =
          allOrders.where((order) => order['status'] == 'pending').length;

      double totalRevenue = 0.0;
      for (var order in allOrders) {
        if (order['status'] == 'delivered') {
          totalRevenue += (order['totalAmount'] ?? 0.0);
        }
      }
      analytics['totalRevenue'] = totalRevenue;

      analytics['averageOrderValue'] = analytics['completedOrders'] > 0
          ? totalRevenue / analytics['completedOrders']
          : 0.0;

      // Get top performing products
      Map<String, Map<String, dynamic>> productStats = {};
      for (var order in allOrders) {
        if (order['status'] == 'delivered') {
          String productId = order['productId'] ?? '';
          String productName = order['productName'] ?? 'Unknown Product';

          if (!productStats.containsKey(productId)) {
            productStats[productId] = {
              'name': productName,
              'orders': 0,
              'revenue': 0.0,
              'quantity': 0,
            };
          }

          productStats[productId]!['orders'] += 1;
          productStats[productId]!['revenue'] += (order['totalAmount'] ?? 0.0);
          productStats[productId]!['quantity'] += (order['quantity'] ?? 0);
        }
      }

      // Sort products by revenue
      List<Map<String, dynamic>> topProducts = productStats.values.toList();
      topProducts.sort(
          (a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      analytics['topProducts'] = topProducts.take(5).toList();

      // Get recent orders (last 10)
      allOrders.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      analytics['recentOrders'] = allOrders.take(10).toList();

      // Calculate monthly revenue for chart
      Map<String, double> monthlyRevenue = {};
      for (var order in allOrders) {
        if (order['status'] == 'delivered') {
          final timestamp = order['timestamp'] as Timestamp?;
          if (timestamp != null) {
            final date = timestamp.toDate();
            final monthKey = '${date.month}/${date.year}';
            monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0.0) +
                (order['totalAmount'] ?? 0.0);
          }
        }
      }
      analytics['monthlyRevenue'] = monthlyRevenue;

      // Get wallet balance
      try {
        final walletDoc =
            await _firestore.collection('wallets').doc(sellerId).get();
        if (walletDoc.exists) {
          analytics['walletBalance'] = walletDoc.data()?['balance'] ?? 0.0;
        } else {
          analytics['walletBalance'] = 0.0;
        }
      } catch (e) {
        analytics['walletBalance'] = 0.0;
      }

      return analytics;
    } catch (e) {
      print('Error calculating analytics: $e');
      return {};
    }
  }

  String _formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Analytics'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
              });
              _loadAnalytics();
            },
            itemBuilder: (context) => _periods
                .map((period) => PopupMenuItem(
                      value: period,
                      child: Text(period),
                    ))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedPeriod, style: const TextStyle(fontSize: 14)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Key Metrics Cards
                    _buildMetricsGrid(),
                    const SizedBox(height: 24),

                    // Revenue Chart Section
                    _buildRevenueChart(),
                    const SizedBox(height: 24),

                    // Top Products Section
                    _buildTopProducts(),
                    const SizedBox(height: 24),

                    // Recent Orders Section
                    _buildRecentOrders(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      children: [
        _buildMetricCard(
          'Total Revenue',
          _formatCurrency(_analytics['totalRevenue'] ?? 0.0),
          Icons.attach_money,
          Colors.green,
        ),
        _buildMetricCard(
          'Total Orders',
          '${_analytics['totalOrders'] ?? 0}',
          Icons.shopping_bag,
          Colors.blue,
        ),
        _buildMetricCard(
          'Avg Order Value',
          _formatCurrency(_analytics['averageOrderValue'] ?? 0.0),
          Icons.trending_up,
          Colors.orange,
        ),
        _buildMetricCard(
          'Wallet Balance',
          _formatCurrency(_analytics['walletBalance'] ?? 0.0),
          Icons.wallet,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
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

  Widget _buildRevenueChart() {
    final monthlyRevenue =
        _analytics['monthlyRevenue'] as Map<String, double>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (monthlyRevenue.isEmpty)
              Container(
                height: 200,
                alignment: Alignment.center,
                child: const Text(
                  'No revenue data available',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Container(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: monthlyRevenue.length,
                  itemBuilder: (context, index) {
                    final entry = monthlyRevenue.entries.toList()[index];
                    final maxRevenue =
                        monthlyRevenue.values.reduce((a, b) => a > b ? a : b);
                    final barHeight = (entry.value / maxRevenue) * 150;

                    return Container(
                      width: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _formatCurrency(entry.value),
                            style: const TextStyle(fontSize: 10),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 30,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.key,
                            style: const TextStyle(fontSize: 10),
                          ),
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
  }

  Widget _buildTopProducts() {
    final topProducts =
        _analytics['topProducts'] as List<Map<String, dynamic>>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Performing Products',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (topProducts.isEmpty)
              const Center(
                child: Text(
                  'No product sales data available',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topProducts.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final product = topProducts[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(product['name'] ?? 'Unknown Product'),
                    subtitle: Text(
                        '${product['orders']} orders • ${product['quantity']} units sold'),
                    trailing: Text(
                      _formatCurrency(product['revenue'] ?? 0.0),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders() {
    final recentOrders =
        _analytics['recentOrders'] as List<Map<String, dynamic>>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Orders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (recentOrders.isEmpty)
              const Center(
                child: Text(
                  'No recent orders',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentOrders.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final order = recentOrders[index];
                  return ListTile(
                    leading: Container(
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
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(order['productName'] ?? 'Unknown Product'),
                    subtitle: Text(
                        'Order #${order['id'].toString().substring(0, 8)}'),
                    trailing: Text(
                      _formatCurrency(order['totalAmount'] ?? 0.0),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
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
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
