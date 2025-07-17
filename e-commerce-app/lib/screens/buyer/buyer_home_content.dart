import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/cart_service.dart';

class BuyerHomeContent extends StatefulWidget {
  const BuyerHomeContent({Key? key}) : super(key: key);

  @override
  State<BuyerHomeContent> createState() => _BuyerHomeContentState();
}

class _BuyerHomeContentState extends State<BuyerHomeContent> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String? _selectedCategory; // Track currently selected category filter

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    setState(() {
      _isLoading = true;
    });

    // Simple initialization delay
    await Future.delayed(const Duration(milliseconds: 100));

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      icon: Icon(Icons.search),
                      hintText: 'Search for farm products',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fresh Farm Products',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Direct from local farmers',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                // Scroll to products section
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              child: const Text('Shop Now'),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.agriculture,
                        color: Colors.white,
                        size: 60,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Categories Icons
                SizedBox(
                  height: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCategoryItem(Icons.apple, 'Fruits', Colors.orange),
                      _buildCategoryItem(
                          Icons.set_meal, 'Vegetables', Colors.green),
                      _buildCategoryItem(Icons.grain, 'Grains', Colors.amber),
                      _buildCategoryItem(Icons.all_inbox, 'Other', Colors.blue),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Featured Products Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Featured Products',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedCategory != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _selectedCategory!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedCategory = null;
                                      });
                                    },
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('See All >'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
          // Products grid as a separate sliver
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: StreamBuilder<QuerySnapshot>(
              stream: _selectedCategory != null
                  ? _firestore
                      .collection('products')
                      .where('category', isEqualTo: _selectedCategory)
                      .where('status',
                          isEqualTo: 'approved') // Only show approved products
                      .orderBy('createdAt', descending: true)
                      .limit(20)
                      .snapshots()
                  : _firestore
                      .collection('products')
                      .where('status',
                          isEqualTo: 'approved') // Only show approved products
                      .orderBy('createdAt', descending: true)
                      .limit(20)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Center(child: Text('Error: ${snapshot.error}')),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Container(
                      height: 200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_basket,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedCategory != null
                                ? 'No $_selectedCategory products available'
                                : 'No products available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Check back later for new products!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                List<QueryDocumentSnapshot> products = snapshot.data!.docs;

                return SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio:
                        0.8, // Increased from 0.75 to give more height
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      var product =
                          products[index].data() as Map<String, dynamic>;
                      String productId = products[index].id;

                      return _buildProductCard(
                        product['name'] ?? 'Unknown Product',
                        '₱${(product['price'] ?? 0.0).toStringAsFixed(2)}',
                        Icons.eco,
                        Colors.green,
                        '4.5',
                        product['category'] ?? 'Other',
                        allowsReservation: true,
                        currentStock: (product['inventory'] ?? 0).toDouble(),
                        product: product,
                        productId: productId,
                      );
                    },
                    childCount: products.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String label, Color color) {
    // Check if this is the currently selected category
    final isSelected = _selectedCategory == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          // If tapping the already selected category, clear the filter
          if (_selectedCategory == label) {
            _selectedCategory = null;
          } else {
            _selectedCategory = label;
          }
        });
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isSelected ? color : color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? Border.all(color: color, width: 2) : null,
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? color : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Fruits':
        return Icons.apple;
      case 'Vegetables':
        return Icons.set_meal;
      case 'Grains':
        return Icons.grain;
      default:
        return Icons.eco;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Fruits':
        return Colors.orange;
      case 'Vegetables':
        return Colors.green;
      case 'Grains':
        return Colors.amber;
      default:
        return Colors.blue;
    }
  }

  Widget _buildProductCard(String title, String price, IconData icon,
      Color color, String rating, String weight,
      {bool? allowsReservation,
      double? currentStock,
      required Map<String, dynamic> product,
      required String productId}) {
    bool hasStock = currentStock != null && currentStock > 0;

    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image with Stock Indicator
          Stack(
            children: [
              Container(
                height: 100, // Reduced from 120 to give more space for content
                width: double.infinity,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: product['imageUrl'] != null &&
                        product['imageUrl'].toString().isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                        child: Image.network(
                          product['imageUrl'],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(icon, color: color, size: 40),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Icon(icon, color: color, size: 40),
                      ),
              ),
              if (!hasStock)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'OUT OF STOCK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Product Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6.0), // Reduced padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Added to prevent overflow
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13, // Slightly smaller font
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2), // Reduced spacing
                  Text(
                    price,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14, // Smaller font
                    ),
                  ),
                  if (hasStock) ...[
                    const SizedBox(height: 2), // Reduced spacing
                    Text(
                      'Stock: ${currentStock.toInt()}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11, // Smaller font
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: hasStock
                              ? () {
                                  // Navigate to a simple product details page - using a placeholder
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Viewing ${product['name']}'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasStock ? color : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 2), // Reduced padding
                            minimumSize: const Size(0, 28), // Smaller button
                          ),
                          child: const Text('View',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        // Changed from Container to SizedBox for better constraint handling
                        width: 28, // Smaller button
                        height: 28,
                        child: ElevatedButton(
                          onPressed: hasStock
                              ? () async {
                                  final cartService = Provider.of<CartService>(
                                      context,
                                      listen: false);

                                  // Create a CartItem and add it using the addItem method
                                  final cartItem = CartItem(
                                    id: DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString(),
                                    productId: productId,
                                    sellerId: product['sellerId'] ?? '',
                                    productName:
                                        product['name'] ?? 'Unknown Product',
                                    price: (product['price'] ?? 0.0).toDouble(),
                                    quantity: 1,
                                    unit: product['unit'] ?? 'piece',
                                    isReservation: false,
                                    imageUrl: product['imageUrl'],
                                  );

                                  bool success =
                                      await cartService.addItem(cartItem);

                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            '${product['name']} added to cart'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Failed to add ${product['name']} to cart'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                hasStock ? Colors.orange : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                          ),
                          child: const Icon(Icons.add_shopping_cart,
                              size: 14), // Smaller icon
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
