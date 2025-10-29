import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/cart_service.dart';
import 'product_details_screen.dart';
import 'seller_details_screen.dart';
import '../cart_screen.dart';
import '../login_screen.dart';
import '../chat_detail_screen.dart';

class BuyerProductBrowse extends StatefulWidget {
  const BuyerProductBrowse({Key? key}) : super(key: key);

  @override
  State<BuyerProductBrowse> createState() => _BuyerProductBrowseState();
}

class _BuyerProductBrowseState extends State<BuyerProductBrowse> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  List<QueryDocumentSnapshot> _products = [];
  List<QueryDocumentSnapshot> _filteredProducts = [];
  String? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Vegetables',
    'Fruits',
    'Grains',
    'Herbs',
    'Livestock',
    'Dairy',
    'Others'
  ];

  @override
  void initState() {
    super.initState();
    _loadApprovedProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApprovedProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final query = await _firestore
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _products = query.docs;
        _filteredProducts = query.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading products: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterProducts() {
    List<QueryDocumentSnapshot> filtered = _products;

    // Filter by category
    if (_selectedCategory != null && _selectedCategory != 'All') {
      filtered = filtered.where((product) {
        final data = product.data() as Map<String, dynamic>;
        return data['category'] == _selectedCategory;
      }).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) {
        final data = product.data() as Map<String, dynamic>;
        final productName =
            (data['productName'] ?? '').toString().toLowerCase();
        final description =
            (data['description'] ?? '').toString().toLowerCase();
        final category = (data['category'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();

        return productName.contains(query) ||
            description.contains(query) ||
            category.contains(query);
      }).toList();
    }

    setState(() {
      _filteredProducts = filtered;
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _filterProducts();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterProducts();
  }

  Future<void> _startChatWithSeller(String sellerId, String sellerName, {Map<String, dynamic>? product, String? productId}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showLoginPrompt();
      return;
    }

    try {
      // Check if there's an existing chat between this customer and seller
      final chatQuery = await _firestore.collection('chats')
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
          chatData['product'] = {
            'id': productId,
            'name': product['name'] ?? 'Product',
            'price': product['price'] ?? 0,
            'imageUrl': product['imageUrl'],
            'unit': product['unit'] ?? 'piece',
          };
          chatData['productId'] = productId;
        }
        
        await chatRef.set(chatData);
      } else {
        // Use existing chat but update product info if provided
        chatId = chatQuery.docs.first.id;
        
        if (product != null) {
          await _firestore.collection('chats').doc(chatId).update({
            'product': {
              'id': productId,
              'name': product['name'] ?? 'Product',
              'price': product['price'] ?? 0,
              'imageUrl': product['imageUrl'],
              'unit': product['unit'] ?? 'piece',
            },
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

  Future<void> _addToCart(
      Map<String, dynamic> product, String productId) async {
    if (_auth.currentUser == null) {
      _showLoginPrompt();
      return;
    }

    try {
      final cartService = Provider.of<CartService>(context, listen: false);

      final cartItem = CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        productId: productId,
        productName: product['productName'] ?? product['name'] ?? 'Unknown Product',
        price: (product['price'] ?? 0).toDouble(),
        imageUrl: product['imageUrl'],
        sellerId: product['sellerId'] ?? '',
        unit: product['unit'] ?? 'pc',
        quantity: 1,
        isReservation: false,
      );

      print('DEBUG: Adding item to cart from browse - ProductID: $productId');
      
      bool success = await cartService.addItem(cartItem);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['productName'] ?? product['name']} added to cart'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View Cart',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                );
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to add to cart - insufficient stock or other error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to cart: $e')),
      );
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Login Required'),
          content: const Text('Please sign in to add items to your cart.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign In'),
            ),
          ],
        );
      },
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '₱0.00';
    if (price is int) return '₱${price.toDouble().toStringAsFixed(2)}';
    if (price is double) return '₱${price.toStringAsFixed(2)}';
    return '₱0.00';
  }

  String _formatAvailableDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Available now';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      if (date.isBefore(now) || date.isAtSameMomentAs(now)) {
        return 'Available now';
      } else {
        return 'Available ${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Available now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Browse Products'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartScreen()),
                  );
                },
              ),
              Consumer<CartService>(
                builder: (context, cart, child) {
                  if (cart.itemCount == 0) return const SizedBox();
                  return Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
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
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Category Filter
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      _onCategorySelected(selected ? category : 'All');
                    },
                    selectedColor: Colors.green.withOpacity(0.3),
                    checkmarkColor: Colors.green,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Products Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No products found',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            Text(
                              'Try adjusting your search or filters',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadApprovedProducts,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.6, // Increased from 0.75 to give more height
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final productDoc = _filteredProducts[index];
                            final product =
                                productDoc.data() as Map<String, dynamic>;
                            final productId = productDoc.id;

                            return _buildProductCard(product, productId);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, String productId) {
    final double currentStock = (product['currentStock'] ?? product['stock'] ?? product['quantity'] ?? 0).toDouble();
    final bool hasStock = currentStock > 0;
    final String productName = product['productName'] ?? product['name'] ?? 'Unknown Product';
    final String price = _formatPrice(product['price']);
    final String unit = product['unit'] ?? 'pcs';
    final String category = product['category'] ?? 'Others';
    
    // Get icon and color based on category
    IconData icon = Icons.shopping_basket;
    Color color = Colors.green;
    
    switch (category.toLowerCase()) {
      case 'vegetables':
        icon = Icons.eco;
        color = Colors.green;
        break;
      case 'fruits':
        icon = Icons.apple;
        color = Colors.orange;
        break;
      case 'grains':
        icon = Icons.grain;
        color = Colors.brown;
        break;
      case 'herbs':
        icon = Icons.local_florist;
        color = Colors.lightGreen;
        break;
      case 'livestock':
        icon = Icons.cruelty_free;
        color = Colors.red;
        break;
      case 'dairy':
        icon = Icons.breakfast_dining;
        color = Colors.blue;
        break;
      default:
        icon = Icons.shopping_basket;
        color = Colors.green;
    }
    
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
                    height: 100,
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
                  // Message Icon
                  if (hasStock && product['sellerId'] != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          final sellerId = product['sellerId'];
                          final sellerName = product['sellerName'] ?? 'Seller';
                          _startChatWithSeller(sellerId, sellerName, product: product, productId: productId);
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
                  padding: const EdgeInsets.all(6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Product Title
                      Text(
                        productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Price with unit
                      Row(
                        children: [
                          Text(
                            price,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/$unit',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      // Seller info with rating
                      if (product['sellerName'] != null)
                        GestureDetector(
                          onTap: () {
                            if (product['sellerId'] != null) {
                              print('DEBUG: Navigating to seller details');
                              print('DEBUG: Product sellerId: "${product['sellerId']}"');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SellerDetailsScreen(
                                    sellerId: product['sellerId'],
                                    sellerInfo: null,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product['sellerName'],
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 0, 0, 0),
                                    fontSize: 10,
                                    decoration: TextDecoration.underline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasStock) ...[
                                const SizedBox(width: 2),
                                Icon(Icons.star, color: Colors.grey.shade400, size: 10),
                                const SizedBox(width: 1),
                                Text(
                                  '0.0',
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
