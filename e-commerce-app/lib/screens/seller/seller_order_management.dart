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

          // Normalize payment option - check multiple possible field names
          final paymentOption = orderData['paymentOption'] ??
              orderData['payment_option'] ??
              orderData['paymentMethod'] ??
              orderData['payment_method'] ??
              orderData['selectedPaymentMethod'] ??
              'Not specified';
          orderData['paymentOption'] = paymentOption;

          // Debug: Print all order fields
          print('========== Order ${orderData['id']} ==========');
          print('Order fields: ${orderData.keys.toList()}');
          print('deliveryAddress: ${orderData['deliveryAddress']}');
          print('address: ${orderData['address']}');
          print('customerAddress: ${orderData['customerAddress']}');

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

                // Debug: Print all user fields
                print('===== USER DATA DEBUG =====');
                print('User ID: ${orderData['userId']}');
                print('All user fields: ${userData.keys.toList()}');
                print('fullAddress: ${userData['fullAddress']}');
                print('address: ${userData['address']}');
                print('deliveryAddress: ${userData['deliveryAddress']}');
                print('location: ${userData['location']}');
                print('street: ${userData['street']}');
                print('city: ${userData['city']}');
                print('state: ${userData['state']}');
                print('postalCode: ${userData['postalCode']}');

                // Get BUYER'S address from user profile (their signup address)
                // Priority: fullAddress > address > location > deliveryAddress > No address
                final buyerAddr = userData['fullAddress'] ??
                    userData['address'] ??
                    userData['location'] ??
                    userData['deliveryAddress'] ??
                    'No address';
                orderData['buyerAddress'] = buyerAddr;
                orderData['customerAddress'] = buyerAddr;

                print('Final buyer address: $buyerAddr');
                print('===== END USER DATA DEBUG =====');
              }
            } catch (e) {
              print('Error fetching customer data: $e');
            }
          }

          // Debug: Print payment option
          print(
              'Order ${orderData['id']} - Payment Option: ${orderData['paymentOption']}');
          print('========== End Order ${orderData['id']} ==========');

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
        padding: const EdgeInsets.all(12),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Header with Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${_getOrderNumber(order['id'])}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            _formatTimestamp(order['timestamp']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order['status']),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          (order['status'] ?? 'PENDING').toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Product Info Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clickable Product Image
                      GestureDetector(
                        onTap: () {
                          if (order['productImage'] != null &&
                              order['productImage'].toString().isNotEmpty) {
                            _showImageFullScreen(
                                context, order['productImage']);
                          }
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            width: 75,
                            height: 75,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[200],
                              border: Border.all(
                                  color: Colors.grey[300]!, width: 0.5),
                            ),
                            child: order['productImage'] != null &&
                                    order['productImage'].toString().isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: Image.network(
                                      order['productImage'],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Icon(Icons.image_not_supported,
                                            color: Colors.grey[400], size: 28);
                                      },
                                    ),
                                  )
                                : Icon(Icons.image,
                                    color: Colors.grey[400], size: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order['productName'] ?? 'Unknown Product',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Qty: ${order['quantity'] ?? 1} ${order['unit'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '₱${(order['totalAmount'] ?? 0).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Customer Info
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 18, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                order['customerName'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue[900],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 18, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                order['customerContact'] ?? 'No contact',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue[800],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment Method - Display what buyer selected
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getPaymentOptionColor(order['paymentOption'])
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _getPaymentOptionColor(order['paymentOption'])
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getPaymentIcon(order['paymentOption']),
                          size: 18,
                          color: _getPaymentOptionColor(order['paymentOption']),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment by Buyer',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                order['paymentOption'] ?? 'Not specified',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _getPaymentOptionColor(
                                      order['paymentOption']),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showOrderDetails(order),
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('Details'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side:
                                const BorderSide(color: Colors.green, width: 1),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      if (order['status'] == 'pending' ||
                          order['status'] == 'processing') ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _markAsReadyForPickup(order, context),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Mark Ready'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getPaymentOptionColor(String? paymentOption) {
    if (paymentOption == null) return Colors.grey;

    final payment = paymentOption.toLowerCase();

    // Mobile Money
    if (payment.contains('momo') || payment.contains('airtel')) {
      return Colors.orange;
    }
    // Card payments
    if (payment.contains('card') ||
        payment.contains('credit') ||
        payment.contains('debit')) {
      return Colors.blue;
    }
    // Cash / Cash on Delivery
    if (payment.contains('cash') ||
        payment.contains('delivery') ||
        payment.contains('cod')) {
      return Colors.green;
    }
    // Bank Transfer
    if (payment.contains('bank') || payment.contains('transfer')) {
      return Colors.purple;
    }
    // Wallet/Balance
    if (payment.contains('wallet') || payment.contains('balance')) {
      return Colors.teal;
    }

    return Colors.grey;
  }

  IconData _getPaymentIcon(String? paymentOption) {
    if (paymentOption == null) return Icons.help_outline;

    final payment = paymentOption.toLowerCase();

    // Mobile Money
    if (payment.contains('momo') || payment.contains('airtel')) {
      return Icons.phone_android;
    }
    // Card payments
    if (payment.contains('card') ||
        payment.contains('credit') ||
        payment.contains('debit')) {
      return Icons.credit_card;
    }
    // Cash / Cash on Delivery
    if (payment.contains('cash') ||
        payment.contains('delivery') ||
        payment.contains('cod')) {
      return Icons.local_offer;
    }
    // Bank Transfer
    if (payment.contains('bank') || payment.contains('transfer')) {
      return Icons.account_balance;
    }
    // Wallet/Balance
    if (payment.contains('wallet') || payment.contains('balance')) {
      return Icons.wallet_giftcard;
    }

    return Icons.help_outline;
  }

  void _showImageFullScreen(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(80),
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.white,
                        size: 64,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () => Navigator.pop(context),
                mini: true,
                backgroundColor: Colors.white,
                child: const Icon(Icons.close, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsReadyForPickup(
      Map<String, dynamic> order, BuildContext context) async {
    try {
      final now = DateTime.now();

      await _firestore.collection('orders').doc(order['id']).update({
        'status': 'ready_for_pickup',
        'updatedAt': FieldValue.serverTimestamp(),
        'statusUpdates': FieldValue.arrayUnion([
          {
            'status': 'ready_for_pickup',
            'timestamp': Timestamp.fromDate(now),
          }
        ]),
      });

      // Send notification to customer
      await _firestore.collection('notifications').add({
        'userId': order['userId'],
        'orderId': order['id'],
        'type': 'order_status',
        'status': 'ready_for_pickup',
        'message':
            'Your order for ${order['productName']} is ready for pickup!',
        'productName': order['productName'],
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Refresh the order list
      _loadOrders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as ready for pickup!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
