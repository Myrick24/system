import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'buyer_product_browse.dart';
import 'product_details_screen.dart';
import 'seller_details_screen.dart';
import '../chat_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BuyerHomeContent extends StatefulWidget {
  const BuyerHomeContent({Key? key}) : super(key: key);

  @override
  State<BuyerHomeContent> createState() => _BuyerHomeContentState();
}

class _BuyerHomeContentState extends State<BuyerHomeContent> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? _selectedCategory; // Track currently selected category filter

  Future<void> _startChatWithSeller(String sellerId, String sellerName,
      {Map<String, dynamic>? product, String? productId}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to message sellers'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    try {
      // Check if there's an existing chat between this customer and seller
      final chatQuery = await _firestore
          .collection('chats')
          .where('sellerId', isEqualTo: sellerId)
          .where('customerId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      String chatId;

      if (chatQuery.docs.isEmpty) {
        // Create a new chat if none exists
        final chatRef = _firestore.collection('chats').doc();
        chatId = chatRef.id;

        Map<String, dynamic> chatData = {
          'sellerId': sellerId,
          'customerId': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'lastSenderId': '',
          'unreadCustomerCount': 0,
          'unreadSellerCount': 0,
        };

        // Add product information if provided
        if (product != null) {
          chatData['product'] = product;
          chatData['productId'] = productId;
        }

        await chatRef.set(chatData);
      } else {
        // Use existing chat but update product info if provided
        chatId = chatQuery.docs.first.id;

        if (product != null) {
          await _firestore.collection('chats').doc(chatId).update({
            'product': product,
            'productId': productId,
          });
        }
      }

      // Navigate to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            chatId: chatId,
            otherPartyName: sellerName,
            sellerId: sellerId,
            customerId: currentUser.uid,
            isSeller: false,
            product: product,
            productId: productId,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting chat: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Don't show back button when used in unified dashboard
                // Only show when navigated to as a separate screen
                // Search Bar
                GestureDetector(
                  onTap: () {
                    // Navigate to the browse products screen for full search functionality
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BuyerProductBrowse(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey),
                        const SizedBox(width: 12),
                        const Text(
                          'Search for farm products',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
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
                Container(
                  height: 100,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildCategoryItem(Icons.apps, 'All', Colors.purple),
                        const SizedBox(width: 12),
                        _buildCategoryItem(
                            Icons.set_meal, 'Vegetables', Colors.green),
                        const SizedBox(width: 12),
                        _buildCategoryItem(
                            Icons.apple, 'Fruits', Colors.orange),
                        const SizedBox(width: 12),
                        _buildCategoryItem(Icons.grain, 'Grains', Colors.amber),
                        const SizedBox(width: 12),
                        _buildCategoryItem(
                            Icons.all_inbox, 'Others', Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Featured Products Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          _selectedCategory != null
                              ? '$_selectedCategory Products'
                              : 'Featured Products',
                          style: const TextStyle(
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
                                    'Filter Active',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
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

                      double stockValue =
                          (product['currentStock'] ?? product['quantity'] ?? 0)
                              .toDouble();
                      print('Final stock value: $stockValue');

                      return _buildProductCard(
                        product['name'] ?? 'Unknown Product',
                        '₱${(product['price'] ?? 0.0).toStringAsFixed(2)}',
                        Icons.eco,
                        Colors.green,
                        product['category'] ?? 'Others',
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
    final isSelected = (_selectedCategory == label) ||
        (label == 'All' && _selectedCategory == null);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (label == 'All') {
            // Clear any category filter to show all products
            _selectedCategory = null;
          } else {
            // If tapping the already selected category, clear the filter
            if (_selectedCategory == label) {
              _selectedCategory = null;
            } else {
              _selectedCategory = label;
            }
          }
        });
      },
      child: Container(
        width: 80,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isSelected ? color : color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
                border: isSelected ? Border.all(color: color, width: 3) : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : color,
                size: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(
      String title, String price, IconData icon, Color color, String category,
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
              // Product Image with Stock Indicator and Message Icon
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
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(color),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(icon,
                                      color: Colors.grey[400], size: 40),
                                );
                              },
                            ),
                          )
                        : Center(
                            child:
                                Icon(icon, color: Colors.grey[400], size: 40),
                          ),
                  ),
                  // Message Icon
                  if (hasStock && product['sellerId'] != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          final sellerId = product['sellerId'];
                          final sellerName = product['sellerName'] ?? 'Seller';
                          _startChatWithSeller(sellerId, sellerName,
                              product: product, productId: productId);
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.message,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
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
                  padding:
                      const EdgeInsets.all(6.0), // Further reduced from 8.0
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
                        GestureDetector(
                          onTap: () {
                            if (product['sellerId'] != null) {
                              print('DEBUG: Navigating to seller details');
                              print(
                                  'DEBUG: Product sellerId: "${product['sellerId']}"');
                              print(
                                  'DEBUG: Product sellerId type: ${product['sellerId'].runtimeType}');
                              print('DEBUG: Product data: $product');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SellerDetailsScreen(
                                    sellerId: product['sellerId'],
                                    sellerInfo:
                                        null, // Will be loaded in the screen
                                  ),
                                ),
                              );
                            } else {
                              print(
                                  'DEBUG: No sellerId found in product: $product');
                            }
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product['sellerName'],
                                  style: TextStyle(
                                    color: const Color.fromARGB(255, 0, 0, 0),
                                    fontSize: 10, // Further reduced from 10
                                    decoration: TextDecoration.underline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasStock) ...[
                                const SizedBox(width: 2),
                                Icon(Icons.star,
                                    color: Colors.grey.shade400,
                                    size: 10), // Gray star for 0.0 rating
                                const SizedBox(width: 1),
                                Text(
                                  '0.0', // Default rating for products
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ],
                          ),
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
                                      builder: (context) =>
                                          ProductDetailsScreen(
                                        product: product,
                                        productId: productId,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                hasStock ? Colors.green : Colors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                          child: const Text(
                            'View',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
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
