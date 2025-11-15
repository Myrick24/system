import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SellerProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onProductDeleted;

  const SellerProductDetailScreen({
    Key? key,
    required this.product,
    required this.onProductDeleted,
  }) : super(key: key);

  @override
  State<SellerProductDetailScreen> createState() =>
      _SellerProductDetailScreenState();
}

class _SellerProductDetailScreenState extends State<SellerProductDetailScreen> {
  bool _isDeleting = false;
  int _currentImageIndex = 0;

  bool _isProductExpired() {
    if (widget.product['approvedAt'] == null ||
        widget.product['timespan'] == null ||
        widget.product['timespanUnit'] == null) {
      return false;
    }

    try {
      final approvedAt = (widget.product['approvedAt'] as Timestamp).toDate();
      final timespan = widget.product['timespan'] as int;
      final timespanUnit = widget.product['timespanUnit'] as String;

      final expiryTime = timespanUnit == 'Hours'
          ? approvedAt.add(Duration(hours: timespan))
          : approvedAt.add(Duration(days: timespan));

      final now = DateTime.now();
      return now.isAfter(expiryTime);
    } catch (e) {
      return false;
    }
  }

  String _calculateRemainingTime() {
    if (widget.product['approvedAt'] == null ||
        widget.product['timespan'] == null ||
        widget.product['timespanUnit'] == null) {
      return 'N/A';
    }

    try {
      final approvedAt = (widget.product['approvedAt'] as Timestamp).toDate();
      final timespan = widget.product['timespan'] as int;
      final timespanUnit = widget.product['timespanUnit'] as String;

      final expiryTime = timespanUnit == 'Hours'
          ? approvedAt.add(Duration(hours: timespan))
          : approvedAt.add(Duration(days: timespan));

      final now = DateTime.now();
      final difference = expiryTime.difference(now);

      if (difference.isNegative) {
        return 'Expired';
      }

      if (difference.inDays > 0) {
        return '${difference.inDays}d ${difference.inHours % 24}h remaining';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ${difference.inMinutes % 60}m remaining';
      } else {
        return '${difference.inMinutes}m remaining';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _deleteProduct() async {
    try {
      setState(() => _isDeleting = true);

      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product['id'])
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        widget.onProductDeleted();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting product: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text(
              'Are you sure you want to delete "${widget.product['name']}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteProduct();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        text = 'APPROVED';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'REJECTED';
        break;
      case 'expired':
        color = Colors.red.shade700;
        text = 'EXPIRED';
        break;
      case 'pending':
      default:
        color = Colors.orange;
        text = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.green, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getProductImages() {
    List<String> images = [];

    // Check for multiple images first
    if (widget.product['imageUrls'] != null &&
        widget.product['imageUrls'] is List &&
        (widget.product['imageUrls'] as List).isNotEmpty) {
      images = List<String>.from(widget.product['imageUrls']);
    } else if (widget.product['imageUrl'] != null) {
      // Fall back to single image
      images = [widget.product['imageUrl']];
    }

    return images;
  }

  @override
  Widget build(BuildContext context) {
    final status = _isProductExpired()
        ? 'expired'
        : (widget.product['status'] ?? 'pending');
    final images = _getProductImages();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _isDeleting ? null : _showDeleteConfirmation,
            tooltip: 'Delete Product',
          ),
        ],
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Gallery Section
                  if (images.isNotEmpty)
                    Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 300,
                            child: PageView.builder(
                              itemCount: images.length,
                              onPageChanged: (index) {
                                setState(() => _currentImageIndex = index);
                              },
                              itemBuilder: (context, index) {
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      images[index],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: Icon(
                                              Icons.image_not_supported,
                                              size: 80,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    if (_isProductExpired() &&
                                        status.toLowerCase() == 'expired')
                                      Container(
                                        color: Colors.red.withOpacity(0.7),
                                        child: const Center(
                                          child: Text(
                                            'EXPIRED',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 32,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                          if (images.length > 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  images.length,
                                  (index) => Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _currentImageIndex == index
                                          ? Colors.green
                                          : Colors.grey[300],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Product Name and Status
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                widget.product['name'] ?? 'Unnamed Product',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            _buildStatusBadge(status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.category,
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              widget.product['category'] ?? 'Uncategorized',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Price, Stock, and Quantity Info Cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                'Price',
                                '₱${widget.product['price']?.toString() ?? '0.00'}',
                                Icons.attach_money,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCard(
                                'Unit',
                                widget.product['unit'] ?? 'N/A',
                                Icons.straighten,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                'Original Qty',
                                '${widget.product['quantity']?.toString() ?? '0'}',
                                Icons.inventory,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCard(
                                'Current Stock',
                                '${widget.product['currentStock']?.toString() ?? widget.product['quantity']?.toString() ?? '0'}',
                                Icons.inventory_2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Basic Product Information
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Product Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow('Product Name',
                            widget.product['name'] ?? 'Unnamed Product'),
                        const Divider(),
                        _buildDetailRow('Description',
                            widget.product['description'] ?? 'No description'),
                        const Divider(),
                        _buildDetailRow('Category',
                            widget.product['category'] ?? 'Uncategorized'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Order & Delivery Information
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_shipping,
                                color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Order & Delivery Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow('Order Type',
                            widget.product['orderType'] ?? 'Available Now'),
                        const Divider(),
                        _buildDetailRow(
                            'Pickup Location',
                            widget.product['pickupLocation'] ??
                                'Not specified'),
                        const Divider(),
                        if (widget.product['deliveryOptions'] != null &&
                            widget.product['deliveryOptions'] is List)
                          _buildDetailRow(
                            'Delivery Options',
                            (widget.product['deliveryOptions'] as List)
                                .join(', '),
                          ),
                        if (widget.product['deliveryOptions'] != null &&
                            widget.product['deliveryOptions'] is List)
                          const Divider(),
                        if (widget.product['harvestDate'] != null)
                          _buildDetailRow('Harvest Date',
                              _formatTimestamp(widget.product['harvestDate'])),
                        if (widget.product['harvestDate'] != null)
                          const Divider(),
                        if (widget.product['estimatedAvailabilityDate'] != null)
                          _buildDetailRow(
                            'Estimated Availability',
                            _formatTimestamp(
                                widget.product['estimatedAvailabilityDate']),
                          ),
                        if (widget.product['estimatedAvailabilityDate'] != null)
                          const Divider(),
                        _buildDetailRow(
                          'Cooperative',
                          widget.product['cooperativeName'] ?? 'Not specified',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sales Information
                  if (widget.product['sold'] != null ||
                      widget.product['reserved'] != null)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.analytics,
                                  color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Sales Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoCard(
                                  'Sold',
                                  '${widget.product['sold'] ?? 0}',
                                  Icons.shopping_bag,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInfoCard(
                                  'Reserved',
                                  '${widget.product['reserved'] ?? 0}',
                                  Icons.bookmark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  if (widget.product['sold'] != null ||
                      widget.product['reserved'] != null)
                    const SizedBox(height: 16),

                  // Freshness Information (if approved)
                  if (widget.product['status'] == 'approved' &&
                      widget.product['timespan'] != null)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Freshness Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow('Timespan',
                              '${widget.product['timespan']} ${widget.product['timespanUnit']}'),
                          const Divider(),
                          _buildDetailRow(
                              'Approved At',
                              widget.product['approvedAt'] != null
                                  ? _formatTimestamp(
                                      widget.product['approvedAt'])
                                  : 'N/A'),
                          const Divider(),
                          _buildDetailRow(
                              'Freshness Status', _calculateRemainingTime()),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Seller Information
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Seller Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow('Seller Name',
                            widget.product['sellerName'] ?? 'Not specified'),
                        const Divider(),
                        _buildDetailRow('Seller Email',
                            widget.product['sellerEmail'] ?? 'Not specified'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Timestamps Section
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Timeline',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                            'Created At',
                            widget.product['createdAt'] != null
                                ? _formatTimestamp(widget.product['createdAt'])
                                : 'N/A'),
                        if (widget.product['updatedAt'] != null)
                          const Divider(),
                        if (widget.product['updatedAt'] != null)
                          _buildDetailRow('Last Updated',
                              _formatTimestamp(widget.product['updatedAt'])),
                        if (widget.product['approvedAt'] != null)
                          const Divider(),
                        if (widget.product['approvedAt'] != null)
                          _buildDetailRow('Approved At',
                              _formatTimestamp(widget.product['approvedAt'])),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Rejection Reason (if rejected)
                  if (widget.product['status'] == 'rejected' &&
                      widget.product['rejectionReason'] != null)
                    Container(
                      color: Colors.red.shade50,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Rejection Reason',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.product['rejectionReason'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Delete Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isDeleting ? null : _showDeleteConfirmation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 24),
                        label: const Text(
                          'Delete Product',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dateTime = (timestamp as Timestamp).toDate();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];

      final month = months[dateTime.month - 1];
      final day = dateTime.day;
      final year = dateTime.year;

      // Format time with AM/PM
      final hour = dateTime.hour > 12
          ? dateTime.hour - 12
          : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';

      return '$month $day, $year at $hour:$minute $period';
    } catch (e) {
      return 'N/A';
    }
  }
}
