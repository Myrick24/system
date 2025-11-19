import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class NotificationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> notification;

  const NotificationDetailScreen({Key? key, required this.notification})
    : super(key: key);

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final type = widget.notification['type'] ?? '';
    final title = widget.notification['title'] ?? 'Notification';
    final message =
        widget.notification['message'] ?? widget.notification['body'] ?? '';
    final timestamp =
        widget.notification['timestamp'] ?? widget.notification['createdAt'];
    final priority = widget.notification['priority'] ?? 'normal';

    // Extract additional details
    final productId = widget.notification['productId'];
    final productName = widget.notification['productName'];
    final price = widget.notification['price'];
    final quantity = widget.notification['quantity'];
    final unit = widget.notification['unit'];
    final category = widget.notification['category'];
    final sellerName = widget.notification['sellerName'];
    final orderId = widget.notification['orderId'];
    final checkoutId = widget.notification['checkoutId'];
    final buyerName = widget.notification['buyerName'];
    final customerName = widget.notification['customerName'];
    final customerContact = widget.notification['customerContact'];
    final customerEmail = widget.notification['customerEmail'];
    final paymentMethod = widget.notification['paymentMethod'];
    final deliveryMethod = widget.notification['deliveryMethod'];
    final deliveryAddress = widget.notification['deliveryAddress'];
    final meetupLocation = widget.notification['meetupLocation'];
    final pickupLocation = widget.notification['pickupLocation'];
    final totalAmount = widget.notification['totalAmount'];

    // For product_approval, fetch full product details
    if (type == 'product_approval' && productId != null) {
      return _buildProductApprovalScreen(
        productId,
        title,
        timestamp,
        priority,
        type,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(type)),
        backgroundColor: _getNotificationColor(type),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with color based on type
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _getNotificationColor(type),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
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
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getNotificationIcon(type),
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(timestamp),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (priority == 'high') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade800,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.priority_high,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'HIGH PRIORITY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Order Details - Enhanced layout for new_order type
            if (type == 'new_order') ...[
              // Order ID Section
              if (orderId != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order ID',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              orderId,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Date Ordered
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date Ordered',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatFullDate(timestamp),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Order Summary Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
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
                    // Section Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.shopping_bag,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Order Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Product Name
                    if (productName != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PRODUCT',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.5,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              productName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Quantity and Total in Row
                    Row(
                      children: [
                        // Quantity Card
                        if (quantity != null && unit != null)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade50,
                                    Colors.blue.shade100,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.inventory_2,
                                        size: 18,
                                        color: Colors.blue.shade700,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'QUANTITY',
                                        style: TextStyle(
                                          fontSize: 10,
                                          letterSpacing: 0.5,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '$quantity $unit',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(width: 12),

                        // Total Card
                        if (totalAmount != null)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green.shade50,
                                    Colors.green.shade100,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.payments,
                                        size: 18,
                                        color: Colors.green.shade700,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'TOTAL',
                                        style: TextStyle(
                                          fontSize: 10,
                                          letterSpacing: 0.5,
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '₱$totalAmount',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(thickness: 8, color: Color(0xFFF5F5F5)),

              // Buyer Information
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.person,
                            color: Colors.purple.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Buyer Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (customerName != null) ...[
                      _buildInfoRow(
                        icon: Icons.badge,
                        label: 'Name',
                        value: customerName,
                        iconColor: Colors.purple.shade700,
                      ),
                    ],
                    if (customerContact != null) ...[
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        icon: Icons.phone,
                        label: 'Contact',
                        value: customerContact,
                        iconColor: Colors.purple.shade700,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Delivery Information
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.local_shipping,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Delivery Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (deliveryMethod != null) ...[
                      _buildInfoRow(
                        icon: Icons.local_shipping_outlined,
                        label: 'Method',
                        value: deliveryMethod,
                        iconColor: Colors.orange.shade700,
                      ),
                    ],
                    if (pickupLocation != null) ...[
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        icon: Icons.store,
                        label: 'Pickup Location',
                        value: pickupLocation,
                        iconColor: Colors.orange.shade700,
                      ),
                    ],
                    if (deliveryAddress != null) ...[
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        icon: Icons.home,
                        label: 'Cooperative',
                        value: deliveryAddress,
                        iconColor: Colors.orange.shade700,
                      ),
                    ],
                    if (meetupLocation != null) ...[
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        icon: Icons.location_on,
                        label: 'Location',
                        value: meetupLocation,
                        iconColor: Colors.orange.shade700,
                      ),
                    ],
                  ],
                ),
              ),

              const Divider(thickness: 8, color: Color(0xFFF5F5F5)),

              // Status Card
              FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('orders').doc(orderId).get(),
                builder: (context, snapshot) {
                  String orderStatus = 'pending';
                  if (snapshot.hasData && snapshot.data!.exists) {
                    orderStatus =
                        (snapshot.data!.data()
                            as Map<String, dynamic>)['status'] ??
                        'pending';
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              orderStatus,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getStatusIcon(orderStatus),
                            color: _getStatusColor(orderStatus),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order Status',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    orderStatus,
                                  ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _getStatusColor(orderStatus),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  orderStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(orderStatus),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Container(
                margin: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Accept Order Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed:
                            _isProcessing ? null : () => _acceptOrder(orderId!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child:
                            _isProcessing
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle, size: 22),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Accept Order',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Decline Order Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed:
                            _isProcessing
                                ? null
                                : () => _declineOrder(orderId!),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cancel, size: 22),
                            const SizedBox(width: 8),
                            const Text(
                              'Decline Order',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]
            // For non-order notifications, show original message layout
            else ...[
              // Message content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Message',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Additional details section (for non-order notifications)
            if (type != 'new_order' &&
                (productName != null ||
                    orderId != null ||
                    checkoutId != null ||
                    buyerName != null)) ...[
              const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Product details
                    if (productName != null) ...[
                      _buildDetailRow(
                        icon: Icons.inventory_2,
                        label: 'Product',
                        value: productName,
                      ),
                      if (price != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.currency_exchange,
                          label: 'Price',
                          value: '₱${price.toString()}',
                          valueColor: Colors.green.shade700,
                        ),
                      ],
                      if (quantity != null && unit != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.production_quantity_limits,
                          label: 'Quantity',
                          value: '$quantity $unit',
                        ),
                      ],
                      if (category != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.category,
                          label: 'Category',
                          value: category,
                        ),
                      ],
                      if (sellerName != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.person,
                          label: 'Seller',
                          value: sellerName,
                        ),
                      ],
                    ],

                    // Order details
                    if (orderId != null) ...[
                      _buildDetailRow(
                        icon: Icons.receipt_long,
                        label: 'Order ID',
                        value: orderId,
                        isMonospace: true,
                      ),
                    ],

                    // Checkout details
                    if (checkoutId != null) ...[
                      if (orderId != null) const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.shopping_cart,
                        label: 'Checkout ID',
                        value: checkoutId,
                        isMonospace: true,
                      ),
                    ],

                    // Buyer details (for new_order notifications)
                    if (customerName != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.person_outline,
                        label: 'Customer Name',
                        value: customerName,
                      ),
                    ],
                    if (customerContact != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.phone,
                        label: 'Contact Number',
                        value: customerContact,
                      ),
                    ],
                    if (customerEmail != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.email,
                        label: 'Email',
                        value: customerEmail,
                      ),
                    ],

                    // Legacy buyer field (for older notifications)
                    if (buyerName != null && customerName == null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.person_outline,
                        label: 'Buyer',
                        value: buyerName,
                      ),
                    ],

                    // Payment method
                    if (paymentMethod != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.payment,
                        label: 'Payment Method',
                        value: paymentMethod,
                      ),
                    ],

                    // Delivery method
                    if (deliveryMethod != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.local_shipping,
                        label: 'Delivery Method',
                        value: deliveryMethod,
                      ),
                    ],

                    // Meetup location (for Meet-up delivery)
                    if (meetupLocation != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.location_on,
                        label: 'Meet-up Location',
                        value: meetupLocation,
                      ),
                    ],

                    // Delivery address (for Cooperative Delivery)
                    if (deliveryAddress != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.home,
                        label: 'Delivery Address',
                        value: deliveryAddress,
                      ),
                    ],

                    // Pickup location (for Pickup at Coop)
                    if (pickupLocation != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.store,
                        label: 'Pickup Location',
                        value: pickupLocation,
                      ),
                    ],

                    // Total amount
                    if (totalAmount != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.payments,
                        label: 'Total Amount',
                        value: '₱${totalAmount.toString()}',
                        valueColor: Colors.green.shade700,
                      ),
                    ],

                    // Product ID (technical detail)
                    if (productId != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        icon: Icons.tag,
                        label: 'Product ID',
                        value: productId,
                        isMonospace: true,
                        isSmall: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Action buttons
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Product Approval Actions
                  if (type == 'product_approval' && productId != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isProcessing
                                ? null
                                : () => _approveProduct(productId),
                        icon: const Icon(Icons.check_circle),
                        label:
                            _isProcessing
                                ? const Text('Processing...')
                                : const Text('Approve Product'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _isProcessing
                                ? null
                                : () => _rejectProduct(productId),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Reject Product'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ]
                  // Other product-related notifications
                  else if (productId != null &&
                      (type == 'product_approved' ||
                          type == 'product_rejected' ||
                          type == 'new_product_market' ||
                          type == 'new_product_buyer'))
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(
                            context,
                            '/product-detail',
                            arguments: {'productId': productId},
                          );
                        },
                        icon: const Icon(Icons.visibility),
                        label: const Text('View Product Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (orderId != null &&
                      (type == 'order_received' ||
                          type == 'order_cancelled' ||
                          type == 'order_completed'))
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(
                            context,
                            '/order-status',
                            arguments: {'orderId': orderId},
                          );
                        },
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('View Order Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductApprovalScreen(
    String productId,
    String title,
    dynamic timestamp,
    String priority,
    String type,
  ) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('products').doc(productId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_getAppBarTitle(type)),
              backgroundColor: _getNotificationColor(type),
              foregroundColor: Colors.white,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_getAppBarTitle(type)),
              backgroundColor: _getNotificationColor(type),
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Product not found'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final productData = snapshot.data!.data() as Map<String, dynamic>;
        final sellerId = productData['sellerId'];

        // Fetch seller details - try sellers collection first, then users collection
        return FutureBuilder<Map<String, dynamic>?>(
          future: _fetchSellerData(sellerId),
          builder: (context, sellerSnapshot) {
            Map<String, dynamic>? sellerData = sellerSnapshot.data;

            return _buildProductApprovalContent(
              productData,
              sellerData,
              title,
              timestamp,
              priority,
              type,
              productId,
            );
          },
        );
      },
    );
  }

  Widget _buildProductApprovalContent(
    Map<String, dynamic> productData,
    Map<String, dynamic>? sellerData,
    String title,
    dynamic timestamp,
    String priority,
    String type,
    String productId,
  ) {
    final productName = productData['name'] ?? 'Unknown Product';
    final price = productData['price'];
    final quantity = productData['quantity'];
    final unit = productData['unit'] ?? 'kg';
    final category = productData['category'] ?? 'Uncategorized';
    final description = productData['description'] ?? '';
    final imageUrl = productData['imageUrl'];
    final availableFrom = productData['availableFrom'];
    final availableTo = productData['availableTo'];
    final harvestDate = productData['harvestDate'];
    final timespan = productData['timespan'];
    final timespanUnit = productData['timespanUnit'];
    final cooperativeName = productData['cooperativeName'] ?? '';
    final pickupLocation = productData['pickupLocation'] ?? '';
    final deliveryMethods = productData['deliveryOptions'] ?? [];
    final orderType = productData['orderType'] ?? '';

    final sellerName =
        sellerData?['businessName'] ?? sellerData?['name'] ?? 'Unknown Seller';
    final sellerEmail = sellerData?['email'] ?? '';
    final sellerPhone = sellerData?['phoneNumber'] ?? '';
    final sellerAddress = sellerData?['address'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(type)),
        backgroundColor: _getNotificationColor(type),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image with Hero Animation
            if (imageUrl != null)
              GestureDetector(
                onTap: () => _showFullScreenImage(context, imageUrl),
                child: Hero(
                  tag: 'product_image_$productId',
                  child: Container(
                    width: double.infinity,
                    height: 350,
                    color: Colors.grey.shade100,
                    child: Stack(
                      children: [
                        Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: 350,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                              ),
                            );
                          },
                        ),
                        // Gradient overlay for better readability
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.3),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.5),
                              ],
                            ),
                          ),
                        ),
                        // Zoom hint (Bottom Right)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.zoom_in,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Tap to enlarge',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Product name overlay (Bottom)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  productName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(0, 1),
                                        blurRadius: 3,
                                        color: Colors.black,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTimestamp(timestamp),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13,
                                    shadows: const [
                                      Shadow(
                                        offset: Offset(0, 1),
                                        blurRadius: 3,
                                        color: Colors.black,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Quick Info Cards
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  Expanded(
                    child: _buildQuickInfoCard(
                      icon: Icons.currency_exchange,
                      label: 'Price',
                      value: '₱${price?.toStringAsFixed(2) ?? '0.00'}',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickInfoCard(
                      icon: Icons.inventory_2,
                      label: 'Quantity',
                      value: '${quantity?.toString() ?? '0'} $unit',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickInfoCard(
                      icon: Icons.category,
                      label: 'Category',
                      value: category,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),

            // Product Details Section
            _buildSection(
              title: 'Product Information',
              icon: Icons.info_outline,
              children: [
                if (description.isNotEmpty) ...[
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Order Type
                if (orderType.isNotEmpty) ...[
                  const Text(
                    'Order Type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    icon: Icons.shopping_cart,
                    label: 'Type',
                    value: orderType,
                    iconColor: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                ],

                if (availableFrom != null ||
                    availableTo != null ||
                    harvestDate != null) ...[
                  const Text(
                    'Availability',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (availableFrom != null)
                    _buildInfoRow(
                      icon: Icons.calendar_today,
                      label: 'Available From',
                      value: _formatDate(availableFrom),
                      iconColor: Colors.green,
                    ),
                  if (availableTo != null) ...[
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      icon: Icons.event_busy,
                      label: 'Available Until',
                      value: _formatDate(availableTo),
                      iconColor: AppTheme.primaryGreen,
                    ),
                  ],
                  if (harvestDate != null) ...[
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      icon: Icons.agriculture,
                      label: 'Harvest Date',
                      value: _formatDate(harvestDate),
                      iconColor: Colors.brown,
                    ),
                  ],
                  if (timespan != null && timespanUnit != null) ...[
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      icon: Icons.timer,
                      label: 'Product Freshness',
                      value: '$timespan $timespanUnit',
                      iconColor: Colors.orange,
                    ),
                  ],
                  const SizedBox(height: 16),
                ],

                // Pick-up Location
                if (pickupLocation.isNotEmpty) ...[
                  const Text(
                    'Pick-up Information',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    icon: Icons.location_on,
                    label: 'Pick-up Location',
                    value: pickupLocation,
                    iconColor: Colors.red,
                  ),
                  const SizedBox(height: 16),
                ],

                // Delivery Methods
                if (deliveryMethods is List && deliveryMethods.isNotEmpty) ...[
                  const Text(
                    'Available Delivery Methods',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(
                    deliveryMethods.length,
                    (index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: index < deliveryMethods.length - 1 ? 10.0 : 0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.local_shipping,
                              size: 18,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                deliveryMethods[index].toString(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Cooperative Name
                if (cooperativeName.isNotEmpty) ...[
                  const Text(
                    'Cooperative',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    icon: Icons.business,
                    label: 'Assigned Cooperative',
                    value: cooperativeName,
                    iconColor: Colors.deepPurple,
                  ),
                ],
              ],
            ),

            // Seller Information Section
            _buildSection(
              title: 'Seller Information',
              icon: Icons.store,
              children: [
                _buildInfoRow(
                  icon: Icons.business,
                  label: 'Business Name',
                  value: sellerName,
                  iconColor: Colors.purple,
                ),
                if (sellerEmail.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    icon: Icons.email,
                    label: 'Email',
                    value: sellerEmail,
                    iconColor: Colors.blue,
                  ),
                ],
                if (sellerPhone.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    icon: Icons.phone,
                    label: 'Phone',
                    value: sellerPhone,
                    iconColor: Colors.teal,
                  ),
                ],
                if (sellerAddress.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    icon: Icons.location_on,
                    label: 'Address',
                    value: sellerAddress,
                    iconColor: Colors.red,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Review Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _isProcessing
                                  ? null
                                  : () => _approveProduct(productId),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 22,
                          ),
                          label:
                              _isProcessing
                                  ? const Text('Processing...')
                                  : const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _isProcessing
                                  ? null
                                  : () => _rejectProduct(productId),
                          icon: const Icon(Icons.cancel_outlined, size: 22),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      label: const Text('Close'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';

    if (date is Timestamp) {
      return DateFormat('MMM dd, yyyy').format(date.toDate());
    } else if (date is String) {
      try {
        final parsedDate = DateTime.parse(date);
        return DateFormat('MMM dd, yyyy').format(parsedDate);
      } catch (e) {
        return date;
      }
    }

    return date.toString();
  }

  Future<Map<String, dynamic>?> _fetchSellerData(String? sellerId) async {
    if (sellerId == null || sellerId.isEmpty) return null;

    try {
      // First, try to fetch from sellers collection
      final sellerDoc =
          await _firestore.collection('sellers').doc(sellerId).get();
      if (sellerDoc.exists) {
        return sellerDoc.data();
      }

      // If not found in sellers, try users collection (seller might be registered as user)
      final userDoc = await _firestore.collection('users').doc(sellerId).get();
      if (userDoc.exists) {
        return userDoc.data();
      }

      // If still not found, try querying sellers by email/ID
      final sellerQuery =
          await _firestore
              .collection('sellers')
              .where('id', isEqualTo: sellerId)
              .limit(1)
              .get();

      if (sellerQuery.docs.isNotEmpty) {
        return sellerQuery.docs.first.data();
      }

      return null;
    } catch (e) {
      print('Error fetching seller data: $e');
      return null;
    }
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                title: const Text('Product Image'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              body: Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.white,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Failed to load image',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value:
                              loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
      ),
    );
  }

  Future<void> _approveProduct(String productId) async {
    setState(() => _isProcessing = true);

    try {
      // Get product details before updating
      final productDoc =
          await _firestore.collection('products').doc(productId).get();
      final productData = productDoc.data();

      if (productData == null) {
        throw Exception('Product not found');
      }

      final sellerId = productData['sellerId'] as String?;
      final productName = productData['name'] as String? ?? 'Product';

      // Update product status to approved
      await _firestore.collection('products').doc(productId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to seller
      if (sellerId != null) {
        await _firestore.collection('notifications').add({
          'userId': sellerId,
          'title': '✅ Product Approved',
          'body':
              'Your product "$productName" has been approved and is now live!',
          'message':
              'Your product "$productName" has been approved and is now live!',
          'type': 'product_approved',
          'productId': productId,
          'productName': productName,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product approved successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Close the screen
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving product: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectProduct(String productId) async {
    // Show dialog to get rejection reason
    final TextEditingController reasonController = TextEditingController();
    final String? selectedReason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String? dropdownValue;
        final List<String> reasons = [
          'Poor quality images',
          'Incorrect pricing',
          'Missing information',
          'Inappropriate content',
          'Duplicate product',
          'Other',
        ];

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Reject Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please select a reason for rejection:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      hint: const Text('Select reason'),
                      value: dropdownValue,
                      items:
                          reasons
                              .map(
                                (reason) => DropdownMenuItem(
                                  value: reason,
                                  child: Text(reason),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() => dropdownValue = value);
                      },
                    ),
                    if (dropdownValue == 'Other') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter rejection reason...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (dropdownValue == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please select a reason'),
                          backgroundColor: AppTheme.primaryGreen,
                        ),
                      );
                      return;
                    }

                    final reason =
                        dropdownValue == 'Other'
                            ? reasonController.text.trim()
                            : dropdownValue!;

                    if (reason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please provide a reason'),
                          backgroundColor: AppTheme.primaryGreen,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context, reason);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reject'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedReason == null || selectedReason.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      // Get product details before updating
      final productDoc =
          await _firestore.collection('products').doc(productId).get();
      final productData = productDoc.data();

      if (productData == null) {
        throw Exception('Product not found');
      }

      final sellerId = productData['sellerId'] as String?;
      final productName = productData['name'] as String? ?? 'Product';

      // Update product status to rejected with reason
      await _firestore.collection('products').doc(productId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': selectedReason,
      });

      // Send notification to seller
      if (sellerId != null) {
        await _firestore.collection('notifications').add({
          'userId': sellerId,
          'title': '❌ Product Rejected',
          'body':
              'Your product "$productName" was rejected. Reason: $selectedReason',
          'message':
              'Your product "$productName" was rejected. Reason: $selectedReason',
          'type': 'product_rejected',
          'productId': productId,
          'productName': productName,
          'rejectionReason': selectedReason,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Product rejected successfully'),
          backgroundColor: AppTheme.primaryGreen,
          duration: const Duration(seconds: 3),
        ),
      );

      // Close the screen
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting product: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() => _isProcessing = false);
    }
  }

  Widget _buildQuickInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primaryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Accept Order
  Future<void> _acceptOrder(String orderId) async {
    setState(() => _isProcessing = true);

    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Order accepted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      print('Error accepting order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // Decline Order
  Future<void> _declineOrder(String orderId) async {
    // Show dialog to select reason
    final reasons = [
      'Out of stock',
      'Price changed',
      'Cannot deliver to location',
      'Product no longer available',
      'Other reason',
    ];

    String? selectedReason = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Decline Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please select a reason for declining this order:'),
              const SizedBox(height: 16),
              ...reasons.map(
                (reason) => ListTile(
                  title: Text(reason),
                  onTap: () => Navigator.pop(context, reason),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selectedReason == null) return;

    setState(() => _isProcessing = true);

    try {
      print('=== DECLINING ORDER (Notification Screen) ===');
      print('Order ID: $orderId');
      print('Reason: $selectedReason');
      
      // Get order data to ensure we have all fields
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      final orderData = orderDoc.data();
      
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'declinedAt': FieldValue.serverTimestamp(),
        'declineReason': selectedReason,
        'updatedAt': FieldValue.serverTimestamp(),
        'notes': 'Declined: $selectedReason',
      });

      print('✅ Order status updated to cancelled');
      
      // Ensure buyerId field is set (critical for buyer to see it)
      if (orderData != null) {
        if (orderData['buyerId'] == null && orderData['userId'] != null) {
          print('⚠️ Adding buyerId field to order...');
          await _firestore.collection('orders').doc(orderId).update({
            'buyerId': orderData['userId'],
          });
          print('✅ Added buyerId field to order');
        }
        
        // Send notification to buyer
        final buyerId = orderData['buyerId'] ?? orderData['userId'];
        print('📧 Sending notification to buyerId: $buyerId');
        
        if (buyerId != null) {
          await _firestore.collection('notifications').add({
            'userId': buyerId,
            'orderId': orderId,
            'type': 'order_status',
            'status': 'cancelled',
            'message': 'Your order for ${orderData['productName'] ?? 'product'} was declined: $selectedReason',
            'productName': orderData['productName'] ?? 'Product',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
          print('✅ Notification sent to buyer');
        }
        
        // Return stock to product inventory
        final productId = orderData['productId'];
        final quantity = orderData['quantity'] ?? 0;

        if (productId != null && quantity > 0) {
          try {
            await _firestore.collection('products').doc(productId).update({
              'currentStock': FieldValue.increment(quantity),
            });
            print('Stock restored: +$quantity to product $productId');
          } catch (e) {
            print('Error restoring stock: $e');
            // Continue even if stock restoration fails
          }
        }
      }
      
      print('=== DECLINE COMPLETE ===');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Order declined'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      print('Error declining order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // Format full date
  String _formatFullDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'N/A';
    }

    return DateFormat('MMMM dd, yyyy • hh:mm a').format(dateTime);
  }

  // Build header info row for order header card
  Widget _buildHeaderInfoRow(
    String label,
    String value, {
    bool isMonospace = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: isMonospace ? 'monospace' : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Get status icon
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'accepted':
        return Icons.check_circle;
      case 'declined':
      case 'cancelled':
        return Icons.cancel;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.info_outline;
    }
  }

  // Get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'declined':
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEnhancedDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
    bool isClickable = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? Colors.blue.shade700).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    decoration: isClickable ? TextDecoration.underline : null,
                    decorationColor: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isMonospace = false,
    bool isSmall = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: isSmall ? 16 : 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmall ? 12 : 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: isSmall ? 12 : 16,
                  color: valueColor ?? Colors.black87,
                  fontWeight: FontWeight.w500,
                  fontFamily: isMonospace ? 'monospace' : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'Just now';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
    }
  }

  String _getAppBarTitle(String type) {
    switch (type) {
      case 'product_approval':
        return 'Product Approval Request';
      case 'product_approved':
        return 'Product Approved';
      case 'product_rejected':
        return 'Product Rejected';
      case 'new_order':
        return 'Order Details';
      case 'order_received':
        return 'New Order';
      case 'order_cancelled':
        return 'Order Cancelled';
      case 'order_completed':
        return 'Order Completed';
      case 'checkout_seller':
        return 'Checkout Notification';
      case 'checkout_buyer':
        return 'Checkout Update';
      case 'seller_approved':
        return 'Registration Approved';
      case 'seller_rejected':
        return 'Registration Rejected';
      case 'new_product_market':
      case 'new_product_buyer':
        return 'New Product Available';
      default:
        return 'Notification Details';
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'product_approved':
      case 'seller_approved':
      case 'order_completed':
        return Colors.green;
      case 'product_rejected':
      case 'seller_rejected':
      case 'order_cancelled':
        return Colors.red;
      case 'product_approval':
        return AppTheme.primaryGreen;
      case 'new_order':
      case 'order_received':
        return Colors.blue.shade700;
      case 'checkout_seller':
      case 'checkout_buyer':
        return Colors.blue;
      case 'new_product_market':
      case 'new_product_buyer':
        return Colors.purple;
      default:
        return AppTheme.primaryGreen;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'product_approved':
        return Icons.check_circle;
      case 'product_rejected':
        return Icons.cancel;
      case 'product_approval':
        return Icons.pending;
      case 'new_order':
        return Icons.receipt_long;
      case 'order_received':
        return Icons.shopping_bag;
      case 'order_cancelled':
        return Icons.cancel;
      case 'order_completed':
        return Icons.check_circle;
      case 'checkout_seller':
      case 'checkout_buyer':
        return Icons.shopping_cart;
      case 'seller_approved':
        return Icons.verified_user;
      case 'seller_rejected':
        return Icons.block;
      case 'new_product_market':
      case 'new_product_buyer':
        return Icons.new_releases;
      default:
        return Icons.notifications;
    }
  }
}
