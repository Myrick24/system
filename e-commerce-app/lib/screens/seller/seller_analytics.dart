import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
  List<Map<String, dynamic>> _paymentHistory = [];
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
    _loadPaymentHistory();
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

      // Get orders for this seller
      List<Map<String, dynamic>> allOrders = [];

      // Query orders by sellerId directly
      final ordersQuery = await _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: sellerId)
          .get();

      print('Found ${ordersQuery.docs.length} total orders for seller');

      for (var doc in ordersQuery.docs) {
        final orderData = doc.data();
        orderData['id'] = doc.id;

        // Filter by date range
        final timestamp = orderData['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final orderDate = timestamp.toDate();
          if (orderDate.isAfter(startDate) ||
              orderDate.isAtSameMomentAs(startDate)) {
            allOrders.add(orderData);
            print(
                'Order ${doc.id}: status=${orderData['status']}, amount=${orderData['totalAmount']}');
          }
        }
      }

      print('Filtered to ${allOrders.length} orders in date range');

      // Calculate analytics - ONLY completed/delivered orders matter for seller earnings
      final completedOrders = allOrders.where((order) {
        final status = order['status']?.toString().toLowerCase() ?? '';
        return status == 'delivered' || status == 'completed';
      }).toList();

      analytics['totalOrders'] = allOrders.length;
      analytics['completedOrders'] = completedOrders.length;
      analytics['pendingOrders'] =
          allOrders.where((order) => order['status'] == 'pending').length;

      double totalSellerIncome = 0.0; // What seller actually receives
      double totalCoopHolds = 0.0; // What coop is holding/will pay

      print('Processing ${completedOrders.length} completed orders');

      for (var order in completedOrders) {
        // Try to get amountToSeller, if not available, calculate it
        double amountToSeller = (order['amountToSeller'] ?? 0.0).toDouble();

        // If amountToSeller is 0, calculate from totalAmount - deliveryFee
        if (amountToSeller == 0.0) {
          final totalAmount = (order['totalAmount'] ?? 0.0).toDouble();
          final deliveryFee = (order['deliveryFee'] ?? 0.0).toDouble();
          // Assuming seller gets total minus delivery fee (coop keeps delivery fee)
          amountToSeller = totalAmount - deliveryFee;
          print(
              'Calculated seller amount for order ${order['id']}: $amountToSeller (total: $totalAmount, delivery: $deliveryFee)');
        } else {
          print('Order ${order['id']}: amountToSeller = $amountToSeller');
        }

        totalSellerIncome += amountToSeller;

        // Check if payment has been released to seller
        // Check both old field (paymentReleasedToSeller) and new field (payoutStatus)
        final paymentReleased = order['paymentReleasedToSeller'] ?? false;
        final payoutStatus =
            order['payoutStatus']?.toString().toLowerCase() ?? '';
        final isPaid = paymentReleased || payoutStatus == 'paid';

        if (!isPaid) {
          totalCoopHolds += amountToSeller;
        }
      }

      print('Total Seller Income: $totalSellerIncome');
      print('Held by Coop: $totalCoopHolds');

      analytics['totalSellerIncome'] = totalSellerIncome;
      analytics['totalCoopHolds'] = totalCoopHolds;
      analytics['alreadyReceived'] = totalSellerIncome - totalCoopHolds;

      analytics['averageOrderValue'] = analytics['completedOrders'] > 0
          ? totalSellerIncome / analytics['completedOrders']
          : 0.0;

      // Get top performing products (based on seller's income from each product)
      Map<String, Map<String, dynamic>> productStats = {};
      for (var order in completedOrders) {
        String productId = order['productId'] ?? '';
        String productName = order['productName'] ?? 'Unknown Product';

        if (!productStats.containsKey(productId)) {
          productStats[productId] = {
            'name': productName,
            'orders': 0,
            'income': 0.0, // Seller's income from this product
            'quantity': 0,
          };
        }

        // Calculate seller's income for this order
        double orderIncome = (order['amountToSeller'] ?? 0.0).toDouble();
        if (orderIncome == 0.0) {
          final totalAmount = (order['totalAmount'] ?? 0.0).toDouble();
          final deliveryFee = (order['deliveryFee'] ?? 0.0).toDouble();
          orderIncome = totalAmount - deliveryFee;
        }

        productStats[productId]!['orders'] += 1;
        productStats[productId]!['income'] += orderIncome;
        productStats[productId]!['quantity'] += (order['quantity'] ?? 0);
      }

      // Sort products by seller's income
      List<Map<String, dynamic>> topProducts = productStats.values.toList();
      topProducts.sort(
          (a, b) => (b['income'] as double).compareTo(a['income'] as double));
      analytics['topProducts'] = topProducts.take(5).toList();

      // Get recent completed orders (last 10)
      completedOrders.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      analytics['recentOrders'] = completedOrders.take(10).toList();

      // Calculate monthly seller income for chart
      Map<String, double> monthlyIncome = {};
      for (var order in completedOrders) {
        final timestamp = order['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final date = timestamp.toDate();
          final monthKey = '${date.month}/${date.year}';
          final amountToSeller = (order['amountToSeller'] ?? 0.0).toDouble();
          monthlyIncome[monthKey] =
              (monthlyIncome[monthKey] ?? 0.0) + amountToSeller;
        }
      }
      analytics['monthlyIncome'] = monthlyIncome;

      return analytics;
    } catch (e) {
      print('Error getting seller analytics: $e');
      return {};
    }
  }

  Future<void> _loadPaymentHistory() async {
    if (_auth.currentUser == null) return;

    try {
      final sellerId = _auth.currentUser!.uid;

      print('========================================');
      print('Loading payment history for seller: $sellerId');

      // Load payment history from seller_payouts collection
      final payoutsSnapshot = await _firestore
          .collection('seller_payouts')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .get();

      print('Found ${payoutsSnapshot.docs.length} payment records in database');

      List<Map<String, dynamic>> validPayments = [];
      List<String> invalidPayoutIds = [];
      Set<String> seenReferences =
          {}; // Track reference numbers to detect duplicates

      for (var doc in payoutsSnapshot.docs) {
        final data = doc.data();
        print('---');
        print('Document ID: ${doc.id}');
        print('Seller ID: ${data['sellerId']}');
        print('Total Amount: ${data['totalAmount']}');
        print('Order Count: ${data['orderCount']}');
        print('Order IDs: ${data['orderIds']}');
        print('Payment Method: ${data['paymentMethod']}');
        print('Reference: ${data['referenceNumber']}');
        print('Created At: ${data['createdAt']}');

        // Check for duplicate reference numbers
        final refNumber = data['referenceNumber']?.toString() ?? '';
        if (refNumber.isNotEmpty && seenReferences.contains(refNumber)) {
          print('Duplicate reference detected: $refNumber');
          invalidPayoutIds.add(doc.id);
          continue;
        }
        if (refNumber.isNotEmpty) {
          seenReferences.add(refNumber);
        }

        // Keep all payout records - they are historical records of payments received
        validPayments.add({
          'id': doc.id,
          ...data,
        });
      }

      // Delete invalid payout records
      if (invalidPayoutIds.isNotEmpty) {
        print('Deleting ${invalidPayoutIds.length} invalid payout records...');
        for (var payoutId in invalidPayoutIds) {
          await _firestore.collection('seller_payouts').doc(payoutId).delete();
          print('Deleted payout record: $payoutId');
        }
      }

      setState(() {
        _paymentHistory = validPayments;
      });

      print('Valid payment history loaded: ${_paymentHistory.length} payments');
      print('========================================');
    } catch (e) {
      print('Error loading payment history: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  String _formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Earnings'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadAnalytics();
              _loadPaymentHistory();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : RefreshIndicator(
              onRefresh: () async {
                await _loadAnalytics();
                await _loadPaymentHistory();
              },
              color: Colors.green,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period Selector
                    _buildPeriodSelector(),
                    const SizedBox(height: 20),

                    // 1. Their own income
                    _buildIncomeCard(),
                    const SizedBox(height: 16),

                    // 2. Their own completed orders
                    _buildCompletedOrdersCard(),
                    const SizedBox(height: 16),

                    // 3. How much they will receive from the coop
                    _buildCoopPaymentCard(),
                    const SizedBox(height: 24),

                    // Payment history from cooperative
                    _buildPaymentHistory(),
                    const SizedBox(height: 24),

                    // List of completed orders
                    _buildOrdersList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Period',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _periods.map((period) {
              final isSelected = period == _selectedPeriod;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPeriod = period;
                  });
                  _loadAnalytics();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    period,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 1. Their own income
  Widget _buildIncomeCard() {
    final totalIncome = _analytics['totalSellerIncome'] ?? 0.0;
    final completedOrders = _analytics['completedOrders'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade600, Colors.green.shade700],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet,
                  color: Colors.white, size: 32),
              const SizedBox(width: 12),
              const Text(
                'My Total Income',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _formatCurrency(totalIncome),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'From $completedOrders completed ${completedOrders == 1 ? 'order' : 'orders'}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // 2. Their own completed orders
  Widget _buildCompletedOrdersCard() {
    final completedOrders = _analytics['completedOrders'] ?? 0;
    final avgPerOrder = _analytics['averageOrderValue'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.check_circle,
                color: Colors.green.shade700, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Completed Orders',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completedOrders',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Avg: ${_formatCurrency(avgPerOrder)} per order',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. How much they will receive from the coop
  Widget _buildCoopPaymentCard() {
    final coopHolds = _analytics['totalCoopHolds'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.savings, color: Colors.orange.shade700, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'To Receive from Coop',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(coopHolds),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pending payment from cooperative',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory() {
    print('Building payment history widget. Count: ${_paymentHistory.length}');

    // Calculate total
    double totalReceived = 0.0;
    int totalOrders = 0;

    for (var payment in _paymentHistory) {
      final amount = (payment['totalAmount'] ?? payment['amount'] ?? 0.0);
      final orderCount = ((payment['orderCount'] ?? 1) as num).toInt();

      print('Payment record: amount=$amount, orderCount=$orderCount');

      totalReceived += amount;
      totalOrders += orderCount;
    }

    print('Total Received: $totalReceived, Total Orders: $totalOrders');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade200, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.1),
                blurRadius: 10,
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.account_balance_wallet,
                        color: Colors.green.shade700, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Received',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₱${totalReceived.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_paymentHistory.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Payments',
                        '${_paymentHistory.length}',
                        Icons.payments,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        'Orders Paid',
                        '$totalOrders',
                        Icons.shopping_bag,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        if (_paymentHistory.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Payment History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_paymentHistory.length, (index) {
            final payment = _paymentHistory[index];
            final amount =
                (payment['totalAmount'] ?? payment['amount'] ?? 0.0).toDouble();
            final orderCount = ((payment['orderCount'] ?? 1) as num).toInt();
            final paymentMethod = payment['paymentMethod'] ?? 'N/A';
            final reference = payment['referenceNumber'] ?? 'N/A';
            final createdAt = payment['createdAt'] as Timestamp?;
            final dateStr = createdAt != null
                ? DateFormat('MMM dd, yyyy - hh:mm a')
                    .format(createdAt.toDate())
                : 'N/A';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.payments,
                    color: Colors.green.shade700,
                    size: 24,
                  ),
                ),
                title: Text(
                  '₱${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '$orderCount ${orderCount > 1 ? 'orders' : 'order'} • $paymentMethod',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ref: $reference',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 2),
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
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    final recentOrders =
        _analytics['recentOrders'] as List<Map<String, dynamic>>? ?? [];

    if (recentOrders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No completed orders yet',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Completed Orders (${recentOrders.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentOrders.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = recentOrders[index];
            final timestamp = order['timestamp'] as Timestamp?;
            final date = timestamp != null
                ? DateFormat('MMM dd, yyyy').format(timestamp.toDate())
                : 'N/A';

            // Calculate seller's income - same logic as above
            double myIncome = (order['amountToSeller'] ?? 0.0).toDouble();
            if (myIncome == 0.0) {
              final totalAmount = (order['totalAmount'] ?? 0.0).toDouble();
              final deliveryFee = (order['deliveryFee'] ?? 0.0).toDouble();
              myIncome = totalAmount - deliveryFee;
            }

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.check_circle,
                        color: Colors.green.shade600, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order['productName'] ?? 'Unknown Product',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(myIncome),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'My Income',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
