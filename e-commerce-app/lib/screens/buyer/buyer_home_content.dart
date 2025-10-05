import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'buyer_product_browse.dart';
import 'product_details_screen.dart';

class BuyerHomeContent extends StatefulWidget {
  const BuyerHomeContent({Key? key}) : super(key: key);

  @override
  State<BuyerHomeContent> createState() => _BuyerHomeContentState();
}

class _BuyerHomeContentState extends State<BuyerHomeContent> {
  final _firestore = FirebaseFirestore.instance;
  String? _selectedCategory; // Track currently selected category filter

  @override
  Widget build(BuildContext context) {
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
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BuyerProductBrowse(),
                          ),
                        );
                      },
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
                    childAspectRatio: 0.71, // Adjusted to prevent overflow
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      var product =
                          products[index].data() as Map<String, dynamic>;
                      String productId = products[index].id;

                      // Debug: Print stock information
                      print('Product: ${product['name']}');
                      print('currentStock: ${product['currentStock']}');
                      print('quantity: ${product['quantity']}');
                      print('inventory: ${product['inventory']}');
                      
                      double stockValue = (product['currentStock'] ?? product['quantity'] ?? 0).toDouble();
                      print('Final stock value: $stockValue');

                      return _buildProductCard(
                        product['name'] ?? 'Unknown Product',
                        '₱${(product['price'] ?? 0.0).toStringAsFixed(2)}',
                        Icons.eco,
                        Colors.green,
                        '4.5',
                        product['category'] ?? 'Other',
                        allowsReservation: true,
                        currentStock: stockValue,
                        product: product,
                        productId: productId,
                        unit: product['unit'] ?? 'pcs',
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

  Widget _buildProductCard(String title, String price, IconData icon,
      Color color, String rating, String weight,
      {bool? allowsReservation,
      double? currentStock,
      required Map<String, dynamic> product,
      required String productId,
      String? unit}) {
    bool hasStock = currentStock != null && currentStock > 0;

    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailsScreen(
                product: product,
                productId: productId,
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image with Stock Indicator
              Stack(
                children: [
                  Container(
                    height: 100, // Further reduced to match seller cards
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: product['imageUrl'] != null &&
                            product['imageUrl'].toString().isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
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
                                  child: Icon(icon, color: Colors.grey[400], size: 40),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Icon(icon, color: Colors.grey[400], size: 40),
                          ),
                  ),
                  if (!hasStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
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
              // Product Info with better spacing and styling
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6.0), // Further reduced from 8.0
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Product Title
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15, // Further reduced from 12
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2), // Further reduced from 3
                      // Price with unit
                      Row(
                        children: [
                          Text(
                            price,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 15, // Further reduced from 14
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/${unit ?? 'pcs'}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1), // Further reduced from 2
                      // Seller info with rating
                      if (product['sellerName'] != null)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product['sellerName'],
                                style: TextStyle(
                                  color: const Color.fromARGB(255, 0, 0, 0),
                                  fontSize: 10, // Further reduced from 10
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasStock) ...[
                              const SizedBox(width: 2),
                              Icon(Icons.star, color: Colors.amber, size: 10),
                              const SizedBox(width: 1),
                              Text(
                                rating.isNotEmpty ? rating : '4.5',
                                style: TextStyle(
                                  color: const Color.fromARGB(255, 0, 0, 0),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ],
                        ),
                      const Spacer(),
                      // View Button - full width and bold
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: hasStock
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductDetailsScreen(
                                        product: product,
                                        productId: productId,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasStock ? Colors.green : Colors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                          child: const Text(
                            'View',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
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
    );
  }
}
