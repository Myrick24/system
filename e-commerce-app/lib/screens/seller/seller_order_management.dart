import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../order_detail_screen.dart';

class SellerOrderManagement extends StatefulWidget {
  const SellerOrderManagement({Key? key}) : super(key: key);

  @override
  State<SellerOrderManagement> createState() => _SellerOrderManagementState();
}

class _SellerOrderManagementState extends State<SellerOrderManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  List<Map<String, dynamic>> _allOrders = [];
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (_auth.currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get seller products first
      final sellerProductsQuery = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: currentUser.uid)
          .get();

      List<String> productIds =
          sellerProductsQuery.docs.map((doc) => doc.id).toList();

      if (productIds.isEmpty) {
        setState(() {
          _allOrders = [];
        });
        return;
      }

      // Get all orders for seller's products
      List<Map<String, dynamic>> orders = [];

      // Firestore 'in' query limit is 10, so we need to batch if more products
      for (int i = 0; i < productIds.length; i += 10) {
        final batch = productIds.skip(i).take(10).toList();

        final ordersQuery = await _firestore
            .collection('orders')
            .where('productId', whereIn: batch)
            .get();

        for (var doc in ordersQuery.docs) {
          final orderData = doc.data();
          orderData['id'] = doc.id;

          // Get customer info
          if (orderData.containsKey('userId')) {
            try {
              final userDoc = await _firestore
                  .collection('users')
                  .doc(orderData['userId'])
                  .get();
              if (userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>;
                orderData['customerName'] = userData['name'] ??
                    userData['fullName'] ??
                    'Unknown Customer';
                orderData['customerContact'] = userData['phone'] ??
                    userData['phoneNumber'] ??
                    'No contact';
                orderData['customerEmail'] = userData['email'] ?? 'No email';
                orderData['customerAddress'] =
                    userData['address'] ?? 'No address';
              }
            } catch (e) {
              print('Error fetching customer data: $e');
            }
          }

          orders.add(orderData);
        }
      }

      // Sort by timestamp, newest first
      orders.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      setState(() {
        _allOrders = orders;
      });
    } catch (e) {
      print('Error loading orders: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredOrders() {
    if (_selectedFilter == 'all') {
      return _allOrders;
    }

    // Handle grouped statuses
    switch (_selectedFilter) {
      case 'for_pickup_delivery':
        return _allOrders
            .where((order) =>
                order['status'] == 'ready_for_pickup' ||
                order['status'] == 'ready_for_delivery')
            .toList();
      case 'in_transit':
        return _allOrders
            .where((order) =>
                order['status'] == 'shipped' ||
                order['status'] == 'out_for_delivery')
            .toList();
      case 'completed':
        return _allOrders
            .where((order) =>
                order['status'] == 'delivered' ||
                order['status'] == 'completed')
            .toList();
      default:
        return _allOrders
            .where((order) => order['status'] == _selectedFilter)
            .toList();
    }
  }

  int _getOrderCountByStatus(String status) {
    if (status == 'all') {
      return _allOrders.length;
    }

    // Handle grouped statuses
    switch (status) {
      case 'for_pickup_delivery':
        return _allOrders
            .where((order) =>
                order['status'] == 'ready_for_pickup' ||
                order['status'] == 'ready_for_delivery')
            .length;
      case 'in_transit':
        return _allOrders
            .where((order) =>
                order['status'] == 'shipped' ||
                order['status'] == 'out_for_delivery')
            .length;
      case 'completed':
        return _allOrders
            .where((order) =>
                order['status'] == 'delivered' ||
                order['status'] == 'completed')
            .length;
      default:
        return _allOrders.where((order) => order['status'] == status).length;
    }
  }

  Future<void> _updateOrderStatus(
      Map<String, dynamic> order, String newStatus) async {
    try {
      // Get the current server timestamp
      final now = DateTime.now();

      await _firestore.collection('orders').doc(order['id']).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusUpdates': FieldValue.arrayUnion([
          {
            'status': newStatus,
            'timestamp': Timestamp.fromDate(now),
          }
        ]),
      });

      // Send notification to customer
      await _firestore.collection('notifications').add({
        'userId': order['userId'],
        'orderId': order['id'],
        'type': 'order_status',
        'status': newStatus,
        'message': 'Your order for ${order['productName']} is now $newStatus',
        'productName': order['productName'],
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Refresh the order list
      _loadOrders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order: $e')),
        );
      }
    }
  }

  String _getOrderNumber(String orderId) {
    // Extract a clean order number from the Firebase document ID
    // Take the last 6 characters and convert to uppercase for readability
    if (orderId.length > 6) {
      return orderId.substring(orderId.length - 6).toUpperCase();
    }
    return orderId.toUpperCase();
  }

  void _showOrderDetails(Map<String, dynamic> order) async {
    // Normalize order data - add orderId if not present
    final normalizedOrder = {...order};
    if (!normalizedOrder.containsKey('orderId')) {
      normalizedOrder['orderId'] = order['id'];
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(
          order: normalizedOrder,
        ),
      ),
    );

    // Refresh the order list if order was updated
    if (result == true) {
      _loadOrders();
    }
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
      case 'ready_for_pickup':
      case 'ready_for_delivery':
        return Colors.purple;
      case 'shipped':
      case 'out_for_delivery':
        return Colors.indigo;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(child: _buildOrderList()),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Filter:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.green),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedFilter = newValue;
                      });
                    }
                  },
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(
                          '🟢 All Orders (${_getOrderCountByStatus('all')})'),
                    ),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text(
                          '🕒 Pending / New Orders (${_getOrderCountByStatus('pending')})'),
                    ),
                    DropdownMenuItem(
                      value: 'processing',
                      child: Text(
                          '🧺 Preparing (${_getOrderCountByStatus('processing')})'),
                    ),
                    DropdownMenuItem(
                      value: 'for_pickup_delivery',
                      child: Text(
                          '🚚 For Pickup / Delivery (${_getOrderCountByStatus('for_pickup_delivery')})'),
                    ),
                    DropdownMenuItem(
                      value: 'in_transit',
                      child: Text(
                          '🚛 In Transit (${_getOrderCountByStatus('in_transit')})'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text(
                          '✅ Completed (${_getOrderCountByStatus('completed')})'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text(
                          '❌ Cancelled (${_getOrderCountByStatus('cancelled')})'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    final filteredOrders = _getFilteredOrders();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allOrders.isEmpty) {
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

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.filter_list_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No orders found for this filter',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedFilter = 'all';
                });
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filter'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
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
                          'Order #${_getOrderNumber(order['id'])}',
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
                          'Customer: ${order['customerName'] ?? 'Unknown'}',
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
                      'Qty: ${order['quantity'] ?? 1} ${order['unit'] ?? ''} • ${_formatTimestamp(order['timestamp'])}',
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
