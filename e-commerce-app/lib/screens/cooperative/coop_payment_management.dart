import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Payment Management Screen for Cooperative
/// Manages Cash on Delivery payments and GCash transactions
class CoopPaymentManagement extends StatefulWidget {
  const CoopPaymentManagement({Key? key}) : super(key: key);

  @override
  State<CoopPaymentManagement> createState() => _CoopPaymentManagementState();
}

class _CoopPaymentManagementState extends State<CoopPaymentManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Cash on Delivery', 'GCash'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Section
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Payments',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                value: _selectedFilter,
                items: _filters.map((filter) {
                  return DropdownMenuItem(
                    value: filter,
                    child: Text(filter),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                  });
                },
              ),
            ],
          ),
        ),

        // Summary Cards
        Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('orders').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              var orders = snapshot.data!.docs;
              double totalRevenue = 0;
              double pendingCOD = 0;
              double gcashPayments = 0;
              int codOrders = 0;

              for (var doc in orders) {
                final data = doc.data() as Map<String, dynamic>;
                final paymentMethod = data['paymentMethod'] ?? '';
                final status = data['status'] ?? '';
                final amount = (data['totalAmount'] ?? 0.0).toDouble();

                if (status == 'delivered' || status == 'completed') {
                  totalRevenue += amount;
                }

                if (paymentMethod == 'Cash on Delivery') {
                  codOrders++;
                  if (status != 'delivered' &&
                      status != 'completed' &&
                      status != 'cancelled') {
                    pendingCOD += amount;
                  }
                } else if (paymentMethod == 'GCash') {
                  if (status == 'delivered' || status == 'completed') {
                    gcashPayments += amount;
                  }
                }
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Revenue',
                          '₱${totalRevenue.toStringAsFixed(2)}',
                          Icons.attach_money,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Pending COD',
                          '₱${pendingCOD.toStringAsFixed(2)}',
                          Icons.money_off,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'COD Orders',
                          codOrders.toString(),
                          Icons.local_atm,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'GCash Payments',
                          '₱${gcashPayments.toStringAsFixed(2)}',
                          Icons.phone_android,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),

        const Divider(),

        // Payment List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('orders').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var orders = snapshot.data!.docs;

              // Apply payment method filter
              if (_selectedFilter != 'All') {
                orders = orders.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['paymentMethod'] == _selectedFilter;
                }).toList();
              }

              if (orders.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payments, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No payment records found'),
                    ],
                  ),
                );
              }

              // Sort by timestamp (newest first)
              orders.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTimestamp = aData['timestamp'] as Timestamp?;
                final bTimestamp = bData['timestamp'] as Timestamp?;

                if (aTimestamp == null || bTimestamp == null) return 0;
                return bTimestamp.compareTo(aTimestamp);
              });

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index].data() as Map<String, dynamic>;
                  order['id'] = orders[index].id;
                  return _buildPaymentCard(order);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> order) {
    final paymentMethod = order['paymentMethod'] ?? 'Unknown';
    final status = order['status'] ?? 'pending';
    final amount = (order['totalAmount'] ?? 0.0).toDouble();
    final customerName = order['customerName'] ?? 'Unknown';
    final productName = order['productName'] ?? 'Unknown Product';
    final orderId = order['id'] ?? '';

    // Determine payment status
    bool isPaid = false;
    String paymentStatus = 'Pending';
    Color statusColor = Colors.orange;

    if (paymentMethod == 'GCash') {
      // GCash is always paid upfront
      isPaid = true;
      paymentStatus = 'Paid';
      statusColor = Colors.green;
    } else if (paymentMethod == 'Cash on Delivery' || paymentMethod == 'Cash') {
      // For COD/Cash: Check if explicitly marked as collected, or if order is delivered/completed
      final paymentCollected = order['paymentCollected'] ?? false;

      if (paymentCollected || status == 'delivered' || status == 'completed') {
        isPaid = true;
        paymentStatus = 'Collected';
        statusColor = Colors.green;
      } else if (status == 'cancelled') {
        paymentStatus = 'Cancelled';
        statusColor = Colors.red;
      } else {
        paymentStatus = 'Pending Collection';
        statusColor = Colors.orange;
      }
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Order ID and Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isPaid ? Icons.check_circle : Icons.pending,
                          color: statusColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              productName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    paymentStatus,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Customer Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customerName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Payment Details Grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.attach_money,
                              size: 18, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Amount',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '₱${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),

                  Divider(height: 20, color: Colors.grey.shade200),

                  // Payment Method
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            paymentMethod == 'GCash'
                                ? Icons.phone_android
                                : Icons.money,
                            size: 18,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Payment Method',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        paymentMethod,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  Divider(height: 20, color: Colors.grey.shade200),

                  // Order Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_shipping,
                              size: 18, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Order Status',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Date
                  if (order['timestamp'] != null) ...[
                    Divider(height: 20, color: Colors.grey.shade200),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            const Text(
                              'Date',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _formatTimestamp(order['timestamp']),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Action button for unpaid COD/Cash
            if ((paymentMethod == 'Cash on Delivery' ||
                    paymentMethod == 'Cash') &&
                !isPaid) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markAsPaid(orderId),
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: const Text(
                    'Mark as Paid (Cash Collected)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
        return Colors.teal;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPaymentInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _markAsPaid(String orderId) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: const Text(
          'Have you collected the Cash on Delivery payment from the customer?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Yes, Collected'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('orders').doc(orderId).update({
          'status': 'completed',
          'paymentCollected': true,
          'paymentCollectedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment marked as collected'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating payment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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

      return DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }
}
