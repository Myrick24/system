import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({
    Key? key,
    required this.order,
  }) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isProcessing = false;
  String? _fetchedBuyerAddress;

  @override
  void initState() {
    super.initState();
    _fetchBuyerAddressIfNeeded();
  }

  Future<void> _fetchBuyerAddressIfNeeded() async {
    // If address is already available, no need to fetch
    print('===== ORDER DETAIL SCREEN DEBUG =====');
    print('Order data keys: ${widget.order.keys.toList()}');
    print('buyerAddress: ${widget.order['buyerAddress']}');
    print('customerAddress: ${widget.order['customerAddress']}');
    print('userId: ${widget.order['userId']}');

    if ((widget.order['buyerAddress'] != null && widget.order['buyerAddress'].toString().isNotEmpty) ||
        (widget.order['customerAddress'] != null && widget.order['customerAddress'].toString().isNotEmpty)) {
      print(
          'Address already available: ${widget.order['buyerAddress'] ?? widget.order['customerAddress']}');
      print('===== END ORDER DETAIL DEBUG =====');
      return;
    }

    // If we don't have the buyer's address, fetch it from the user profile
    if (widget.order.containsKey('userId') && widget.order['userId'] != null) {
      try {
        print('Fetching buyer address for userId: ${widget.order['userId']}');
        final userDoc = await _firestore
            .collection('users')
            .doc(widget.order['userId'])
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          print('User data fields: ${userData.keys.toList()}');
          print('fullAddress: ${userData['fullAddress']}');
          print('address: ${userData['address']}');
          print('deliveryAddress: ${userData['deliveryAddress']}');
          print('location: ${userData['location']}');

          // Get buyer's signup address - Priority: fullAddress > address > location > deliveryAddress
          final address = userData['fullAddress'] ??
              userData['address'] ??
              userData['location'] ??
              userData['deliveryAddress'];

          print('Fetched address: $address');

          if (address != null && address.toString().isNotEmpty) {
            setState(() {
              _fetchedBuyerAddress = address.toString();
            });
            print('Set _fetchedBuyerAddress: $_fetchedBuyerAddress');
          }
        } else {
          print('User document does not exist');
        }
      } catch (e) {
        print('Error fetching buyer address: $e');
      }
    }
    print('===== END ORDER DETAIL DEBUG =====');
  }

  @override
  Widget build(BuildContext context) {
    final orderId = widget.order['orderId'] ?? widget.order['id'];
    final productName = widget.order['productName'] ?? 'N/A';
    final productImage = widget.order['productImage'];
    final quantity = widget.order['quantity'];
    final unit = widget.order['unit'] ?? 'units';
    final totalAmount = widget.order['totalAmount'];
    final customerName = widget.order['customerName'] ?? 'N/A';
    final customerContact = widget.order['customerContact'];
    final customerEmail =
        widget.order['customerEmail'] ?? widget.order['userEmail'];
    final customerAddress = widget.order['buyerAddress'] ??
        widget.order['customerAddress'] ??
        _fetchedBuyerAddress ??
        'No address provided';
    final deliveryMethod = widget.order['deliveryMethod'];
    final deliveryAddress = widget.order['deliveryAddress'];
    final meetupLocation = widget.order['meetupLocation'];
    final pickupLocation = widget.order['pickupLocation'];
    final timestamp = widget.order['timestamp'] ?? widget.order['createdAt'];
    final status = widget.order['status']?.toString().toLowerCase() ?? 'pending';

    // Debug: Print available order data
    print('Order Debug - customerAddress: $customerAddress');
    print('Order Debug - deliveryAddress: $deliveryAddress');
    print('Order keys: ${widget.order.keys}');

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order #${orderId ?? 'N/A'}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              Text(
                _formatTimestamp(timestamp),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              if (productImage != null && productImage.toString().isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _showImageFullScreen(context, productImage.toString());
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        productImage.toString(),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 200,
                          color: Colors.grey.shade300,
                          child: Icon(
                            Icons.image_not_supported,
                            size: 60,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.teal.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shopping_bag,
                                color: Colors.green.shade700, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Product Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Product:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Flexible(
                              child: Text(
                                productName,
                                textAlign: TextAlign.end,
                                style: TextStyle(color: Colors.grey.shade800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Quantity:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              '$quantity $unit',
                              style: TextStyle(color: Colors.grey.shade800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Divider(color: Colors.green.shade200),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              '₱${totalAmount ?? 0}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.cyan.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person,
                                color: Colors.blue.shade700, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Customer Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Name:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Flexible(
                              child: Text(
                                customerName,
                                textAlign: TextAlign.end,
                                style: TextStyle(color: Colors.grey.shade800),
                              ),
                            ),
                          ],
                        ),
                        if (customerContact != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Contact:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Flexible(
                                child: Text(
                                  customerContact.toString(),
                                  textAlign: TextAlign.end,
                                  style: TextStyle(color: Colors.grey.shade800),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (customerEmail != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Email:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Flexible(
                                child: Text(
                                  customerEmail.toString(),
                                  textAlign: TextAlign.end,
                                  style: TextStyle(color: Colors.grey.shade800),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Divider(color: Colors.blue.shade200),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined,
                                color: Colors.green.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Address:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(
                                    customerAddress ?? 'No address provided',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade50, Colors.amber.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_shipping_outlined,
                                color: Colors.orange.shade700, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Delivery Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (deliveryMethod != null) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Method:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text(deliveryMethod.toString()),
                            ],
                          ),
                        ],
                        if (pickupLocation != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Pickup:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Flexible(child: Text(pickupLocation.toString())),
                            ],
                          ),
                        ],
                        if (deliveryAddress != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Address:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Flexible(child: Text(deliveryAddress.toString())),
                            ],
                          ),
                        ],
                        if (meetupLocation != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Meetup:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Flexible(child: Text(meetupLocation.toString())),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade50, Colors.cyan.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payment,
                                color: Colors.teal.shade700, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Payment Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Payment Method:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              _getPaymentMethodDisplay(widget.order),
                              style: TextStyle(
                                color: _getPaymentMethodColor(widget.order),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
<<<<<<< HEAD
              
              // Conditional buttons based on order status
              if (status == 'pending' || status == 'confirmed') ...[
                // Show Accept/Decline buttons for pending orders
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isProcessing ? null : () => _acceptOrder(orderId!),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Accept Order'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
=======
              // Show different buttons based on order status
              if (widget.order['status'] == 'pending' ||
                  widget.order['status'] == null)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isProcessing ? null : () => _acceptOrder(orderId!),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Accept Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing
                            ? null
                            : () => _declineOrder(orderId!),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Decline Order'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          side:
                              BorderSide(color: Colors.red.shade600, width: 2),
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                )
              else if (widget.order['status'] == 'processing')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _markAsReadyForPickup(orderId!),
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Mark as Ready for Pickup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
>>>>>>> d22e04245da246de0243f3f2c4876ca75f51afad
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
<<<<<<< HEAD
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        _isProcessing ? null : () => _declineOrder(orderId!),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Decline Order'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade600, width: 2),
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ] else if (status == 'processing') ...[
                // Show Ready to Ship button for processing orders
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isProcessing ? null : () => _markAsReadyToShip(orderId!),
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Mark as Ready to Ship'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ] else ...[
                // Show status indicator for other statuses
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Order Status: ${status.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
=======
>>>>>>> d22e04245da246de0243f3f2c4876ca75f51afad
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acceptOrder(String orderId) async {
    setState(() => _isProcessing = true);

    try {
      // Use the same pattern as seller_order_management
      final now = DateTime.now();

      await _firestore.collection('orders').doc(orderId).update({
        'status': 'processing',
        'updatedAt': FieldValue.serverTimestamp(),
        'statusUpdates': FieldValue.arrayUnion([
          {
            'status': 'processing',
            'timestamp': Timestamp.fromDate(now),
          }
        ]),
      });

      // Send notification to buyer
      final buyerId = widget.order['buyerId'] ?? widget.order['userId'];
      if (buyerId != null) {
        await _firestore.collection('notifications').add({
          'userId': buyerId,
          'orderId': orderId,
          'type': 'order_status',
          'status': 'processing',
          'message':
              'Your order for ${widget.order['productName']} is now being prepared',
          'productName': widget.order['productName'],
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Order accepted and is now being prepared!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error accepting order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _markAsReadyForPickup(String orderId) async {
    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now();

      await _firestore.collection('orders').doc(orderId).update({
        'status': 'ready_for_pickup',
        'updatedAt': FieldValue.serverTimestamp(),
        'statusUpdates': FieldValue.arrayUnion([
          {
            'status': 'ready_for_pickup',
            'timestamp': Timestamp.fromDate(now),
          }
        ]),
      });

      // Send notification to buyer
      final buyerId = widget.order['buyerId'] ?? widget.order['userId'];
      if (buyerId != null) {
        await _firestore.collection('notifications').add({
          'userId': buyerId,
          'orderId': orderId,
          'type': 'order_status',
          'status': 'ready_for_pickup',
          'message':
              'Your order for ${widget.order['productName']} is ready for pickup!',
          'productName': widget.order['productName'],
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Order marked as ready for pickup!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error marking order as ready: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _declineOrder(String orderId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Order'),
        content: const Text('Select a reason:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateDeclineReason(orderId, 'Out of Stock');
            },
            child: const Text('Out of Stock'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateDeclineReason(orderId, 'Cannot Deliver');
            },
            child: const Text('Cannot Deliver'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateDeclineReason(String orderId, String reason) async {
    setState(() => _isProcessing = true);

    try {
      // Use the same pattern as seller_order_management
      final now = DateTime.now();

      await _firestore.collection('orders').doc(orderId).update({
        'status': 'declined',
        'notes': 'Declined: $reason',
        'updatedAt': FieldValue.serverTimestamp(),
        'statusUpdates': FieldValue.arrayUnion([
          {
            'status': 'declined',
            'reason': reason,
            'timestamp': Timestamp.fromDate(now),
          }
        ]),
      });

      // Send notification to buyer
      final buyerId = widget.order['buyerId'] ?? widget.order['userId'];
      if (buyerId != null) {
        await _firestore.collection('notifications').add({
          'userId': buyerId,
          'orderId': orderId,
          'type': 'order_status',
          'status': 'declined',
          'message':
              'Your order for ${widget.order['productName']} was declined: $reason',
          'productName': widget.order['productName'],
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Order declined: $reason'),
              backgroundColor: Colors.red),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error declining order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _markAsReadyToShip(String orderId) async {
    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now();

      // Update order status to ready_for_shipping
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'ready_for_shipping',
        'updatedAt': FieldValue.serverTimestamp(),
        'statusUpdates': FieldValue.arrayUnion([
          {
            'status': 'ready_for_shipping',
            'timestamp': Timestamp.fromDate(now),
          }
        ]),
      });

      // Send push notification to buyer
      final buyerId = widget.order['buyerId'] ?? widget.order['userId'];
      if (buyerId != null) {
        await _firestore.collection('notifications').add({
          'userId': buyerId,
          'orderId': orderId,
          'type': 'order_status',
          'status': 'ready_for_shipping',
          'message':
              'Good news! Your order for ${widget.order['productName']} is ready to ship! 📦',
          'productName': widget.order['productName'],
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'priority': 'high',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as ready to ship! Buyer has been notified. 📦'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error marking order as ready to ship: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final DateTime dateTime = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.parse(timestamp.toString());
      return DateFormat('MMMM dd, yyyy • hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _getPaymentMethodDisplay(Map<String, dynamic> order) {
    final paymentOption = order['paymentOption'] ??
        order['payment_option'] ??
        order['paymentMethod'] ??
        order['payment_method'] ??
        order['selectedPaymentMethod'] ??
        'Not specified';
    return paymentOption.toString();
  }

  Color _getPaymentMethodColor(Map<String, dynamic> order) {
    final payment = _getPaymentMethodDisplay(order).toLowerCase();

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
}
