import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProductViewScreen extends StatefulWidget {
  const ProductViewScreen({Key? key}) : super(key: key);

  @override
  State<ProductViewScreen> createState() => _ProductViewScreenState();
}

class _ProductViewScreenState extends State<ProductViewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.green,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.green,
              tabs: const [
                Tab(text: 'All Products'),
                Tab(text: 'Approved'),
                Tab(text: 'Pending'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductList(null), // All products
                _buildProductList('approved'),
                _buildProductList('pending'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(String? status) {
    return StreamBuilder<QuerySnapshot>(
      stream: status == null
          ? _firestore
              .collection('products')
              .orderBy('createdAt', descending: true)
              .snapshots()
          : _firestore
              .collection('products')
              .where('status', isEqualTo: status)
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No products found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final product = doc.data() as Map<String, dynamic>;
            final productId = doc.id;

            return _buildProductCard(product, productId);
          },
        );
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, String productId) {
    final status = product['status'] ?? 'pending';
    final name = product['name'] ?? 'Unknown Product';
    final price = product['price']?.toString() ?? '0';
    final currentStock = product['currentStock']?.toString() ?? '0';
    final reserved = product['reserved']?.toString() ?? '0';
    final sold = product['sold']?.toString() ?? '0';
    final unit = product['unit'] ?? '';
    final category = product['category'] ?? '';
    final imageUrl = product['imageUrl'];
    final imageUrls = product['imageUrls'] as List<dynamic>?;
    final createdAt = product['createdAt'] as Timestamp?;

    // Calculate available stock
    final currentStockNum = int.tryParse(currentStock) ?? 0;
    final reservedNum = int.tryParse(reserved) ?? 0;
    final availableStock = currentStockNum - reservedNum;

    // Get all images
    final List<String> images = [];
    if (imageUrls != null && imageUrls.isNotEmpty) {
      images.addAll(imageUrls.map((e) => e.toString()));
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      images.add(imageUrl.toString());
    }

    // Debug
    if (images.length > 1) {
      print('Card - Product: $name has ${images.length} images');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showProductDetails(product, productId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image with multiple images indicator
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    images.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              images[0],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.image_not_supported,
                                    size: 40, color: Colors.grey);
                              },
                            ),
                          )
                        : const Icon(Icons.shopping_bag,
                            size: 40, color: Colors.grey),
                    // Multiple images indicator
                    if (images.length > 1)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.photo_library,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${images.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
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
              const SizedBox(width: 16),

              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Category
                    if (category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),

                    // Price and Stock
                    Row(
                      children: [
                        Text(
                          '₱$price',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          ' / $unit',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.inventory_2,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$currentStock $unit',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Inventory Information
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2,
                                size: 14,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Inventory',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildInventoryItem(
                                'Total',
                                '$currentStock $unit',
                                Colors.blue,
                              ),
                              _buildInventoryItem(
                                'Available',
                                '$availableStock $unit',
                                Colors.green,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildInventoryItem(
                                'Reserved',
                                '$reserved $unit',
                                Colors.orange,
                              ),
                              _buildInventoryItem(
                                'Sold',
                                '$sold $unit',
                                Colors.purple,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Status Badge and Date
                    Row(
                      children: [
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'approved'
                                ? Colors.green.shade50
                                : status == 'rejected'
                                    ? Colors.red.shade50
                                    : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: status == 'approved'
                                  ? Colors.green
                                  : status == 'rejected'
                                      ? Colors.red
                                      : Colors.orange,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                status == 'approved'
                                    ? Icons.check_circle
                                    : status == 'rejected'
                                        ? Icons.cancel
                                        : Icons.pending,
                                size: 14,
                                color: status == 'approved'
                                    ? Colors.green
                                    : status == 'rejected'
                                        ? Colors.red
                                        : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: status == 'approved'
                                      ? Colors.green.shade700
                                      : status == 'rejected'
                                          ? Colors.red.shade700
                                          : Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Date
                        if (createdAt != null)
                          Text(
                            DateFormat('MMM dd, yyyy')
                                .format(createdAt.toDate()),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductDetails(Map<String, dynamic> product, String productId) {
    final status = product['status'] ?? 'pending';
    final name = product['name'] ?? 'Unknown Product';
    final price = product['price']?.toString() ?? '0';
    final currentStock = product['currentStock']?.toString() ?? '0';
    final reserved = product['reserved']?.toString() ?? '0';
    final sold = product['sold']?.toString() ?? '0';
    final unit = product['unit'] ?? '';
    final category = product['category'] ?? '';
    final description = product['description'] ?? 'No description available';
    final imageUrl = product['imageUrl'];
    final imageUrls = product['imageUrls'] as List<dynamic>?;
    final sellerName = product['sellerName'] ?? 'Unknown Seller';
    final cooperativeName = product['cooperativeName'] ?? 'Unknown Cooperative';

    // Calculate available stock
    final currentStockNum = int.tryParse(currentStock) ?? 0;
    final reservedNum = int.tryParse(reserved) ?? 0;
    final availableStock = currentStockNum - reservedNum;

    // Get all images
    final List<String> images = [];
    if (imageUrls != null && imageUrls.isNotEmpty) {
      images.addAll(imageUrls.map((e) => e.toString()));
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      images.add(imageUrl.toString());
    }

    // Debug: Print image count
    print('Product: $name');
    print('Total images: ${images.length}');
    print('Images: $images');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Images with PageView
              if (images.isNotEmpty) _buildImageGallery(images),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: status == 'approved'
                            ? Colors.green.shade50
                            : status == 'rejected'
                                ? Colors.red.shade50
                                : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: status == 'approved'
                              ? Colors.green
                              : status == 'rejected'
                                  ? Colors.red
                                  : Colors.orange,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            status == 'approved'
                                ? Icons.check_circle
                                : status == 'rejected'
                                    ? Icons.cancel
                                    : Icons.pending,
                            size: 16,
                            color: status == 'approved'
                                ? Colors.green
                                : status == 'rejected'
                                    ? Colors.red
                                    : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Status: ${status.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: status == 'approved'
                                  ? Colors.green.shade700
                                  : status == 'rejected'
                                      ? Colors.red.shade700
                                      : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Seller Information
                    _buildDetailRow('Seller', sellerName),
                    const Divider(height: 24),

                    // Cooperative
                    _buildDetailRow('Cooperative', cooperativeName),
                    const Divider(height: 24),

                    // Category
                    _buildDetailRow('Category', category),
                    const Divider(height: 24),

                    // Price
                    _buildDetailRow('Price', '₱$price / $unit'),
                    const Divider(height: 24),

                    // Inventory Details
                    const Text(
                      'Inventory',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          _buildInventoryDetailRow(
                            'Total Stock',
                            '$currentStock $unit',
                            Icons.inventory_2,
                            Colors.blue,
                          ),
                          const Divider(height: 16),
                          _buildInventoryDetailRow(
                            'Available',
                            '$availableStock $unit',
                            Icons.check_circle,
                            Colors.green,
                          ),
                          const Divider(height: 16),
                          _buildInventoryDetailRow(
                            'Reserved',
                            '$reserved $unit',
                            Icons.lock_clock,
                            Colors.orange,
                          ),
                          const Divider(height: 16),
                          _buildInventoryDetailRow(
                            'Sold',
                            '$sold $unit',
                            Icons.shopping_cart,
                            Colors.purple,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 24),

                    // Description
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
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
        ],
      ),
    );
  }

  Widget _buildImageGallery(List<String> images) {
    print('_buildImageGallery called with ${images.length} images');

    if (images.isEmpty) {
      return Container(
        height: 200,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
        ),
      );
    }

    if (images.length == 1) {
      // Single image
      print('Showing single image');
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
        child: Image.network(
          images[0],
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 200,
              color: Colors.grey[200],
              child: const Icon(Icons.image_not_supported,
                  size: 60, color: Colors.grey),
            );
          },
        ),
      );
    }

    // Multiple images with PageView
    print('Showing multiple images with PageView: ${images.length} images');
    return _ImageGalleryWidget(images: images);
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryDetailRow(
      String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// Stateful widget for image gallery with multiple images
class _ImageGalleryWidget extends StatefulWidget {
  final List<String> images;

  const _ImageGalleryWidget({required this.images});

  @override
  State<_ImageGalleryWidget> createState() => _ImageGalleryWidgetState();
}

class _ImageGalleryWidgetState extends State<_ImageGalleryWidget> {
  int _currentPage = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    print(
        '_ImageGalleryWidget initialized with ${widget.images.length} images');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(
        '_ImageGalleryWidget building PageView with ${widget.images.length} images');
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // PageView for images
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
                child: Image.network(
                  widget.images[index],
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[100],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.green,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.image_not_supported,
                              size: 60, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            'Image ${index + 1} not available',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        // Page indicators
        Positioned(
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.photo_library,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_currentPage + 1}/${widget.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
