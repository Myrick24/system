import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellerOrderManagement extends StatefulWidget {
  const SellerOrderManagement({Key? key}) : super(key: key);

  @override
  State<SellerOrderManagement> createState() => _SellerOrderManagementState();
}

class _SellerOrderManagementState extends State<SellerOrderManagement>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _pendingOrders = [];
  List<Map<String, dynamic>> _processingOrders = [];
  List<Map<String, dynamic>> _shippedOrders = [];
  List<Map<String, dynamic>> _deliveredOrders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      _loadOrdersByTab(_tabController.index);
    });
    _loadOrdersByTab(0); // Load pending orders initially
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
          status = 'pending';
          break;
        case 1:
          status = 'processing';
          break;
        case 2:
          status = 'shipped';
          break;
        case 3:
          status = 'delivered';
          break;
        default:
          status = 'pending';
      }

      final orders = await _getSellerOrdersByStatus(status);

      switch (tabIndex) {
        case 0:
          _pendingOrders = orders;
          break;
        case 1:
          _processingOrders = orders;
          break;
        case 2:
          _shippedOrders = orders;
          break;
        case 3:
          _deliveredOrders = orders;
          break;
      }
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

  Future<List<Map<String, dynamic>>> _getSellerOrdersByStatus(
      String status) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      // Get seller products first
      final sellerProductsQuery = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: currentUser.uid)
          .get();

      List<String> productIds =
          sellerProductsQuery.docs.map((doc) => doc.id).toList();

      if (productIds.isEmpty) return [];

      // Get orders for seller's products with specific status
      List<Map<String, dynamic>> orders = [];

      // Firestore 'in' query limit is 10, so we need to batch if more products
      for (int i = 0; i < productIds.length; i += 10) {
        final batch = productIds.skip(i).take(10).toList();

        final ordersQuery = await _firestore
            .collection('orders')
            .where('productId', whereIn: batch)
            .where('status', isEqualTo: status)
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

      return orders;
    } catch (e) {
      print('Error getting seller orders: $e');
      return [];
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

      // Refresh the current tab
      _loadOrdersByTab(_tabController.index);

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
                  'Order #${_getOrderNumber(order['id'])}',
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

            // Customer Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Information',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Name', order['customerName'] ?? 'Unknown'),
                    _buildDetailRow(
                        'Contact', order['customerContact'] ?? 'No contact'),
                    _buildDetailRow(
                        'Email', order['customerEmail'] ?? 'No email'),
                    _buildDetailRow(
                        'Address', order['customerAddress'] ?? 'No address'),
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
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateOrderStatus(order, 'processing');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Accept Order'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showRejectDialog(order);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Reject Order'),
                    ),
                  ),
                ],
              ),
            ] else if (order['status'] == 'processing') ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateOrderStatus(order, 'shipped');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Mark as Shipped'),
              ),
            ] else if (order['status'] == 'shipped') ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateOrderStatus(order, 'delivered');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Mark as Delivered'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order'),
        content: const Text(
            'Are you sure you want to reject this order? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateOrderStatus(order, 'cancelled');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Processing'),
            Tab(text: 'Shipped'),
            Tab(text: 'Delivered'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(_pendingOrders),
          _buildOrderList(_processingOrders),
          _buildOrderList(_shippedOrders),
          _buildOrderList(_deliveredOrders),
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
