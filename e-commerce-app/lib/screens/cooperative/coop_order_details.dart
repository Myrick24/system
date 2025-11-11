import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/realtime_notification_service.dart';

/// Order Details Screen for Cooperative
/// Shows detailed information about a specific order
/// Allows cooperative staff to manage the order status and delivery
class CoopOrderDetails extends StatefulWidget {
  final String orderId;

  const CoopOrderDetails({Key? key, required this.orderId}) : super(key: key);

  @override
  State<CoopOrderDetails> createState() => _CoopOrderDetailsState();
}

class _CoopOrderDetailsState extends State<CoopOrderDetails> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _orderData;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final orderDoc =
          await _firestore.collection('orders').doc(widget.orderId).get();

      if (orderDoc.exists) {
        setState(() {
          _orderData = orderDoc.data();
          _orderData!['id'] = orderDoc.id;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order not found'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
          backgroundColor: Colors.green.shade700,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_orderData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
          backgroundColor: Colors.green.shade700,
        ),
        body: const Center(child: Text('Order not found')),
      );
    }

    final status = _orderData!['status'] ?? 'pending';
    final deliveryMethod = _orderData!['deliveryMethod'] ?? '';
    final paymentMethod = _orderData!['paymentMethod'] ?? 'Cash on Delivery';
    final totalAmount = (_orderData!['totalAmount'] ?? 0.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: Colors.green.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrderDetails,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: _getStatusColor(status).withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      size: 40,
                      color: _getStatusColor(status),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Order Status',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(status),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Order Information
            const Text(
              'Order Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow(
                        'Order ID', '#${widget.orderId.substring(0, 12)}'),
                    const Divider(),
                    _buildInfoRow(
                        'Product', _orderData!['productName'] ?? 'Unknown'),
                    const Divider(),
                    _buildInfoRow('Quantity',
                        '${_orderData!['quantity'] ?? 1} ${_orderData!['unit'] ?? ''}'),
                    const Divider(),
                    _buildInfoRow('Price per Unit',
                        '₱${(_orderData!['price'] ?? 0.0).toStringAsFixed(2)}'),
                    const Divider(),
                    _buildInfoRow(
                      'Total Amount',
                      '₱${totalAmount.toStringAsFixed(2)}',
                      isHighlight: true,
                    ),
                    if (_orderData!['timestamp'] != null) ...[
                      const Divider(),
                      _buildInfoRow(
                        'Order Date',
                        _formatTimestamp(_orderData!['timestamp']),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Customer Information
            const Text(
              'Customer Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow(
                        'Name', _orderData!['customerName'] ?? 'Unknown'),
                    if (_orderData!['customerContact'] != null) ...[
                      const Divider(),
                      _buildInfoRow('Contact', _orderData!['customerContact']),
                    ],
                    if (_orderData!['userEmail'] != null) ...[
                      const Divider(),
                      _buildInfoRow('Email', _orderData!['userEmail']),
                    ],
                    if (_orderData!['customerAddress'] != null) ...[
                      const Divider(),
                      _buildInfoRow('Address', _orderData!['customerAddress']),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Delivery & Payment Information
            const Text(
              'Delivery & Payment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow('Delivery Method', deliveryMethod),
                    const Divider(),
                    _buildInfoRow('Payment Method', paymentMethod),
                    if (paymentMethod == 'Cash on Delivery' &&
                        status != 'delivered' &&
                        status != 'completed') ...[
                      const Divider(),
                      _buildInfoRow(
                        'Payment Status',
                        'UNPAID',
                        valueColor: Colors.red,
                      ),
                    ] else if (paymentMethod == 'GCash' ||
                        status == 'delivered' ||
                        status == 'completed') ...[
                      const Divider(),
                      _buildInfoRow(
                        'Payment Status',
                        'PAID',
                        valueColor: Colors.green,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Seller Information
            const Text(
              'Seller Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow(
                        'Seller Name', _orderData!['sellerName'] ?? 'Unknown'),
                    if (_orderData!['sellerId'] != null) ...[
                      const Divider(),
                      _buildInfoRow('Seller ID',
                          _orderData!['sellerId'].substring(0, 12)),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            const Text(
              'Order Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildActionButtons(status, deliveryMethod),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isHighlight = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                color:
                    valueColor ?? (isHighlight ? Colors.green : Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String status, String deliveryMethod) {
    List<Widget> buttons = [];

    // FOR PICKUP AT COOP: Show only "Mark Delivered" button for any active status
    if (deliveryMethod == 'Pickup at Coop') {
      if (status != 'delivered' && status != 'completed' && status != 'cancelled') {
        buttons.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _updateStatus('delivered'),
              icon: const Icon(Icons.done_all),
              label: const Text('Mark Delivered'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        );
      }
    } else {
      // FOR COOPERATIVE DELIVERY: Use the normal flow
      
      // Start Processing
      if (status == 'pending' || status == 'confirmed') {
        buttons.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _updateStatus('processing'),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Processing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        );
      }

      // Mark as Delivered
      if (status == 'processing' || 
          status == 'ready' ||
          status == 'ready_for_pickup' ||
          status == 'ready_for_shipping') {
        buttons.add(
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _updateStatus('delivered'),
              icon: const Icon(Icons.done_all),
              label: const Text('Mark Delivered'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        );
      }
    }

    // Cancel Order (for both delivery methods)
    if (status != 'delivered' &&
        status != 'completed' &&
        status != 'cancelled') {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 12));
      buttons.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isProcessing ? null : () => _showCancelDialog(),
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel Order'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No actions available for ${status.toUpperCase()} status',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Row(
      children: buttons,
    );
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Update order status
      await _firestore.collection('orders').doc(widget.orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If status is 'delivered', send notifications to both buyer and seller
      if (newStatus == 'delivered' && _orderData != null) {
        final buyerId = _orderData!['buyerId'] ?? _orderData!['userId'];
        final sellerId = _orderData!['sellerId'];
        final productName = _orderData!['productName'] ?? 'Product';
        final quantity = _orderData!['quantity'] ?? 1;
        final unit = _orderData!['unit'] ?? '';
        
        final batch = _firestore.batch();
        
        // Notification for BUYER
        if (buyerId != null) {
          final buyerNotificationRef = _firestore.collection('notifications').doc();
          batch.set(buyerNotificationRef, {
            'userId': buyerId,
            'title': '✅ Order Delivered',
            'body': 'Your order for $quantity $unit of $productName has been delivered!',
            'message': 'Your order for $quantity $unit of $productName has been delivered successfully.',
            'type': 'order_status',
            'status': 'delivered',
            'orderId': widget.orderId,
            'productId': _orderData!['productId'],
            'productName': productName,
            'productImage': _orderData!['productImage'] ?? '',
            'quantity': quantity,
            'unit': unit,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });
          
          // Send PUSH NOTIFICATION to buyer
          try {
            await RealtimeNotificationService.sendTestNotification(
              title: '✅ Order Delivered',
              body: 'Your order for $quantity $unit of $productName has been delivered!',
              payload: 'order_status|${widget.orderId}|${_orderData!['productId']}|$productName',
            );
            print('✅ Push notification sent to buyer');
          } catch (e) {
            print('⚠️ Error sending push notification to buyer: $e');
          }
        }
        
        // Notification for SELLER
        if (sellerId != null) {
          final sellerNotificationRef = _firestore.collection('notifications').doc();
          batch.set(sellerNotificationRef, {
            'userId': sellerId,
            'title': '✅ Order Completed',
            'body': 'Order for $quantity $unit of $productName has been delivered to customer',
            'message': 'The cooperative has confirmed delivery of $quantity $unit of $productName to the customer.',
            'type': 'order_status',
            'status': 'delivered',
            'orderId': widget.orderId,
            'productId': _orderData!['productId'],
            'productName': productName,
            'productImage': _orderData!['productImage'] ?? '',
            'quantity': quantity,
            'unit': unit,
            'customerName': _orderData!['customerName'] ?? 'Customer',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });
          
          // Send PUSH NOTIFICATION to seller
          try {
            await RealtimeNotificationService.sendTestNotification(
              title: '✅ Order Completed',
              body: 'Order for $quantity $unit of $productName has been delivered to customer',
              payload: 'order_status|${widget.orderId}|${_orderData!['productId']}|$productName',
            );
            print('✅ Push notification sent to seller');
          } catch (e) {
            print('⚠️ Error sending push notification to seller: $e');
          }
        }
        
        // Commit all notifications
        await batch.commit();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as DELIVERED. Buyer and seller have been notified with push notifications.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to ${newStatus.toUpperCase()}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadOrderDetails();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text(
            'Are you sure you want to cancel this order? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus('cancelled');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'Invalid date';
      }

      return DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
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
      case 'ready_for_pickup':
      case 'ready_for_shipping':
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
      case 'ready_for_pickup':
      case 'ready_for_shipping':
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
}
