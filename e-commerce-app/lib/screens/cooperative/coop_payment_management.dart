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

    // Determine payment status
    bool isPaid = false;
    String paymentStatus = 'Pending';
    Color statusColor = Colors.orange;

    if (paymentMethod == 'GCash') {
      isPaid = true;
      paymentStatus = 'Paid (GCash)';
      statusColor = Colors.green;
    } else if (paymentMethod == 'Cash on Delivery') {
      if (status == 'delivered' || status == 'completed') {
        isPaid = true;
        paymentStatus = 'Paid (COD)';
        statusColor = Colors.green;
      } else {
        paymentStatus = 'Unpaid (COD)';
        statusColor = Colors.orange;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order #${order['id'].substring(0, 8)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    paymentStatus,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: statusColor,
                  avatar: Icon(
                    isPaid ? Icons.check_circle : Icons.pending,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Payment Details
            Row(
              children: [
                Expanded(
                  child: _buildPaymentInfo('Customer', customerName),
                ),
                Expanded(
                  child: _buildPaymentInfo(
                      'Amount', '₱${amount.toStringAsFixed(2)}'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildPaymentInfo('Method', paymentMethod),
                ),
                Expanded(
                  child: _buildPaymentInfo('Status', status.toUpperCase()),
                ),
              ],
            ),

            if (order['timestamp'] != null) ...[
              const SizedBox(height: 8),
              _buildPaymentInfo(
                'Date',
                _formatTimestamp(order['timestamp']),
              ),
            ],

            // Action button for unpaid COD
            if (paymentMethod == 'Cash on Delivery' && !isPaid) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markAsPaid(order['id']),
                  icon: const Icon(Icons.check),
                  label: const Text('Mark as Paid (Collected COD)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
