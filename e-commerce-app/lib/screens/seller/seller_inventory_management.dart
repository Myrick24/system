import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellerInventoryManagement extends StatefulWidget {
  const SellerInventoryManagement({Key? key}) : super(key: key);

  @override
  State<SellerInventoryManagement> createState() =>
      _SellerInventoryManagementState();
}

class _SellerInventoryManagementState extends State<SellerInventoryManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _ascending = true;

  // Check if product is expired
  bool _isProductExpired(Map<String, dynamic> product) {
    if (product['approvedAt'] == null ||
        product['timespan'] == null ||
        product['timespanUnit'] == null) {
      return false;
    }

    try {
      final approvedAt = (product['approvedAt'] as Timestamp).toDate();
      final timespan = product['timespan'] as int;
      final timespanUnit = product['timespanUnit'] as String;

      // Calculate expiry time
      final expiryTime = timespanUnit == 'Hours'
          ? approvedAt.add(Duration(hours: timespan))
          : approvedAt.add(Duration(days: timespan));

      final now = DateTime.now();
      return now.isAfter(expiryTime);
    } catch (e) {
      print('Error checking if product expired: $e');
      return false;
    }
  }

  // Calculate remaining time for product
  String _calculateRemainingTime(Map<String, dynamic> product) {
    if (product['approvedAt'] == null ||
        product['timespan'] == null ||
        product['timespanUnit'] == null) {
      return 'N/A';
    }

    try {
      final approvedAt = (product['approvedAt'] as Timestamp).toDate();
      final timespan = product['timespan'] as int;
      final timespanUnit = product['timespanUnit'] as String;

      final expiryTime = timespanUnit == 'Hours'
          ? approvedAt.add(Duration(hours: timespan))
          : approvedAt.add(Duration(days: timespan));

      final now = DateTime.now();

      if (now.isAfter(expiryTime)) {
        return 'Expired';
      }

      final remaining = expiryTime.difference(now);
      if (remaining.inDays > 0) {
        final hours = remaining.inHours % 24;
        return '${remaining.inDays} ${remaining.inDays == 1 ? 'day' : 'days'}${hours > 0 ? ', $hours ${hours == 1 ? 'hour' : 'hours'}' : ''} left';
      } else if (remaining.inHours > 0) {
        return '${remaining.inHours} ${remaining.inHours == 1 ? 'hour' : 'hours'} left';
      } else {
        return '${remaining.inMinutes} ${remaining.inMinutes == 1 ? 'minute' : 'minutes'} left';
      }
    } catch (e) {
      print('Error calculating remaining time: $e');
      return 'N/A';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (_auth.currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final sellerId = _auth.currentUser!.uid;
      final query = await _firestore
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .where('status', isEqualTo: 'approved') // Only show approved products
          .get();

      List<Map<String, dynamic>> products = [];
      for (var doc in query.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        products.add(data);
      }

      _sortProducts(products);

      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading products: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _sortProducts(List<Map<String, dynamic>> products) {
    products.sort((a, b) {
      dynamic aValue = a[_sortBy];
      dynamic bValue = b[_sortBy];

      if (aValue == null && bValue == null) return 0;
      if (aValue == null) return _ascending ? -1 : 1;
      if (bValue == null) return _ascending ? 1 : -1;

      int comparison;
      if (aValue is String && bValue is String) {
        comparison = aValue.toLowerCase().compareTo(bValue.toLowerCase());
      } else if (aValue is num && bValue is num) {
        comparison = aValue.compareTo(bValue);
      } else {
        comparison = aValue.toString().compareTo(bValue.toString());
      }

      return _ascending ? comparison : -comparison;
    });
  }

  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;

    return _products.where((product) {
      final name = (product['name'] ?? '').toString().toLowerCase();
      final category = (product['category'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      return name.contains(query) || category.contains(query);
    }).toList();
  }

  Future<void> _updateProductQuantity(String productId, int newQuantity) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'quantity': newQuantity,
        'currentStock': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Check for low stock and send notification
      if (newQuantity < 10) {
        await _sendLowStockNotification(productId, newQuantity);
      }

      _loadProducts(); // Refresh the list

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inventory updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update inventory: $e')),
        );
      }
    }
  }

  Future<void> _sendLowStockNotification(String productId, int quantity) async {
    try {
      final productDoc =
          await _firestore.collection('products').doc(productId).get();
      if (productDoc.exists) {
        final productData = productDoc.data()!;

        await _firestore.collection('notifications').add({
          'userId': _auth.currentUser!.uid,
          'type': 'low_stock',
          'title': 'Low Stock Alert',
          'message':
              'Product "${productData['name']}" is running low (${quantity} left)',
          'productId': productId,
          'productName': productData['name'],
          'quantity': quantity,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    } catch (e) {
      print('Error sending low stock notification: $e');
    }
  }

  void _showUpdateQuantityDialog(Map<String, dynamic> product) {
    final controller =
        TextEditingController(text: product['quantity']?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Inventory'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Product: ${product['name']}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Quantity',
                border: OutlineInputBorder(),
                suffixText: 'units',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQuantity = int.tryParse(controller.text);
              if (newQuantity != null && newQuantity >= 0) {
                Navigator.pop(context);
                _updateProductQuantity(product['id'], newQuantity);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a valid quantity')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showExpiredProductRecommendations(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Text('Expired Product - Best Practices'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product: ${product['name']}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'Recommended Actions:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildRecommendationItem(
                Icons.delete_outline,
                'Remove from Inventory',
                'Delete or archive this expired product to keep your inventory clean and accurate.',
                Colors.red,
              ),
              _buildRecommendationItem(
                Icons.block,
                'Already Hidden from Buyers',
                'Expired products are automatically hidden from customers and cannot be purchased.',
                Colors.blue,
              ),
              _buildRecommendationItem(
                Icons.refresh,
                'Restock with Fresh Product',
                'If you have fresh stock of the same product, update the timespan and mark it as newly approved.',
                Colors.green,
              ),
              _buildRecommendationItem(
                Icons.analytics,
                'Review Sales Data',
                'Analyze why the product expired. Consider adjusting timespan, pricing, or stock quantities.',
                Colors.purple,
              ),
              _buildRecommendationItem(
                Icons.recycling,
                'Proper Disposal',
                'For organic products, ensure proper composting or disposal according to environmental guidelines.',
                Colors.teal,
              ),
              _buildRecommendationItem(
                Icons.warning_amber,
                'Quality Check',
                'Never sell expired products. Customer safety and trust are paramount.',
                Colors.orange,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tips_and_updates,
                            color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Pro Tip',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Set realistic timespans based on actual product freshness. Monitor your inventory daily to minimize expired products and maximize sales.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Could add delete functionality here
              _showDeleteExpiredProductDialog(product);
            },
            icon: const Icon(Icons.delete),
            label: const Text('Remove Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(
      IconData icon, String title, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteExpiredProductDialog(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Expired Product'),
        content: Text(
          'Are you sure you want to remove "${product['name']}" from your inventory? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore
                    .collection('products')
                    .doc(product['id'])
                    .delete();
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close recommendations
                Navigator.pop(context); // Close product details
                _loadProducts(); // Refresh list
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Product removed successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to remove product: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showProductDetails(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    product['name'] ?? 'Unknown Product',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStockBadge(product),
              ],
            ),
            const SizedBox(height: 20),

            // Product Details
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildDetailCard('Basic Information', [
                      _buildDetailRow('Category', product['category'] ?? 'N/A'),
                      _buildDetailRow('Price',
                          '₱${(product['price'] ?? 0).toStringAsFixed(2)}'),
                      _buildDetailRow('Unit', product['unit'] ?? 'N/A'),
                      _buildDetailRow('Organic',
                          (product['isOrganic'] ?? false) ? 'Yes' : 'No'),
                    ]),
                    _buildDetailCard('Inventory', [
                      _buildDetailRow(
                          'Current Stock', '${product['quantity'] ?? 0}'),
                      _buildDetailRow(
                          'Reserved', '${product['reserved'] ?? 0}'),
                      _buildDetailRow('Available',
                          '${(product['quantity'] ?? 0) - (product['reserved'] ?? 0)}'),
                      _buildDetailRow('Status', _getStockStatus(product)),
                      _buildDetailRow(
                          'Freshness', _calculateRemainingTime(product)),
                    ]),
                    _buildDetailCard('Description', [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          product['description'] ?? 'No description available',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProductExpired(product)
                        ? null
                        : () {
                            Navigator.pop(context);
                            _showUpdateQuantityDialog(product);
                          },
                    icon: const Icon(Icons.edit),
                    label: const Text('Update Stock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      disabledForegroundColor: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to edit product screen
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Edit Product'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            // Show expired product recommendations
            if (_isProductExpired(product)) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _showExpiredProductRecommendations(product),
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('View Expired Product Recommendations'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStockBadge(Map<String, dynamic> product) {
    Color color;
    String label;
    final quantity = product['quantity'] ?? 0;
    final isExpired = _isProductExpired(product);

    if (isExpired) {
      color = Colors.red.shade700;
      label = 'EXPIRED';
    } else if (quantity == 0) {
      color = Colors.red;
      label = 'OUT OF STOCK';
    } else if (quantity < 10) {
      color = Colors.orange;
      label = 'LOW STOCK';
    } else {
      color = Colors.green;
      label = 'IN STOCK';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getStockStatus(Map<String, dynamic> product) {
    final quantity = product['quantity'] ?? 0;
    final isExpired = _isProductExpired(product);

    if (isExpired) return 'Expired - Not Available';
    if (quantity == 0) return 'Out of Stock';
    if (quantity < 10) return 'Low Stock';
    return 'Good Stock';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                if (value == _sortBy) {
                  _ascending = !_ascending;
                } else {
                  _sortBy = value;
                  _ascending = true;
                }
              });
              _sortProducts(_products);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
              const PopupMenuItem(
                  value: 'quantity', child: Text('Sort by Stock')),
              const PopupMenuItem(value: 'price', child: Text('Sort by Price')),
              const PopupMenuItem(
                  value: 'category', child: Text('Sort by Category')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // Product List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No products found',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            final quantity = product['quantity'] ?? 0;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Stack(
                                children: [
                                  InkWell(
                                    onTap: () => _showProductDetails(product),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          // Product Image Placeholder
                                          Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: product['imageUrl'] != null
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: Image.network(
                                                      product['imageUrl'],
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                          error, stackTrace) {
                                                        return const Icon(Icons
                                                            .image_not_supported);
                                                      },
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.image_not_supported),
                                          ),

                                          const SizedBox(width: 16),

                                          // Product Info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product['name'] ??
                                                      'Unknown Product',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${product['category'] ?? 'N/A'} • ₱${(product['price'] ?? 0).toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.inventory,
                                                      size: 16,
                                                      color: Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '$quantity ${product['unit'] ?? ''}',
                                                      style: const TextStyle(
                                                          fontSize: 14),
                                                    ),
                                                    const Spacer(),
                                                    _buildStockBadge(product),
                                                  ],
                                                ),
                                                // Show remaining time for non-expired products
                                                if (!_isProductExpired(
                                                    product)) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.timer_outlined,
                                                        size: 14,
                                                        color: Colors.orange,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        _calculateRemainingTime(
                                                            product),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .orange[700],
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),

                                          // Quick Update Button
                                          IconButton(
                                            onPressed: _isProductExpired(
                                                    product)
                                                ? null
                                                : () =>
                                                    _showUpdateQuantityDialog(
                                                        product),
                                            icon: const Icon(Icons.edit),
                                            color: Colors.blue,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Expired overlay
                                  if (_isProductExpired(product))
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.red.shade300,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add-product'),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}
