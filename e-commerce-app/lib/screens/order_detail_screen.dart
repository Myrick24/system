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
    final deliveryMethod = widget.order['deliveryMethod'];
    final deliveryAddress = widget.order['deliveryAddress'];
    final meetupLocation = widget.order['meetupLocation'];
    final pickupLocation = widget.order['pickupLocation'];
    final timestamp = widget.order['timestamp'] ?? widget.order['createdAt'];

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
                ClipRRect(
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
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Product:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(productName),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Quantity:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('$quantity $unit'),
                        ],
                      ),
                      const Divider(),
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
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Name:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(customerName),
                        ],
                      ),
                      if (customerContact != null) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Contact:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(customerContact.toString()),
                          ],
                        ),
                      ],
                      if (customerEmail != null) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Email:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(customerEmail.toString()),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (deliveryMethod != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Method:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(deliveryMethod.toString()),
                          ],
                        ),
                      ],
                      if (pickupLocation != null) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pickup:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Flexible(child: Text(pickupLocation.toString())),
                          ],
                        ),
                      ],
                      if (deliveryAddress != null) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Address:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Flexible(child: Text(deliveryAddress.toString())),
                          ],
                        ),
                      ],
                      if (meetupLocation != null) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Meetup:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Flexible(child: Text(meetupLocation.toString())),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
}
