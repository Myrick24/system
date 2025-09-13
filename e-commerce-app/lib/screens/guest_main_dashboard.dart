import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'buyer/buyer_home_content.dart';
import 'buyer/product_details_screen.dart';
import 'login_screen.dart';
import 'unified_main_dashboard.dart';

class GuestMainDashboard extends StatefulWidget {
  const GuestMainDashboard({Key? key}) : super(key: key);

  @override
  State<GuestMainDashboard> createState() => _GuestMainDashboardState();
}

class _GuestMainDashboardState extends State<GuestMainDashboard> {
  int _selectedIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if user is authenticated
  bool get _isAuthenticated => _auth.currentUser != null;

  final List<Widget> _pages = [
    const BuyerHomeContent(), // Home page accessible to guests
    const _GuestBrowseScreen(), // Guest browsing with database access
    const _PlaceholderScreen(title: 'Cart'),
    const _PlaceholderScreen(title: 'Messages'),
    const _PlaceholderScreen(title: 'Account'),
  ];

  void _onItemTapped(int index) {
    if (index == 0 || index == 1) {
      // Home and Browse are accessible to guests
      setState(() {
        _selectedIndex = index;
      });
    } else {
      // For other tabs, check authentication
      if (_isAuthenticated) {
        // If authenticated, navigate to the full dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const UnifiedMainDashboard(),
          ),
        );
      } else {
        // Show login prompt
        _showLoginPrompt(index);
      }
    }
  }

  void _showLoginPrompt(int targetIndex) {
    String feature = '';
    switch (targetIndex) {
      case 1:
        // This shouldn't happen since Browse is now accessible to guests
        feature = 'browse products';
        break;
      case 2:
        feature = 'access your cart';
        break;
      case 3:
        feature = 'view messages';
        break;
      case 4:
        feature = 'access your account';
        break;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Login Required'),
          content: Text('Please sign in to $feature.'),
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
                ).then((result) {
                  // If login was successful, check auth state and navigate
                  if (_auth.currentUser != null) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UnifiedMainDashboard(),
                      ),
                    );
                  }
                });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          'Harvest',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_isAuthenticated)
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                ).then((result) {
                  // If login was successful, navigate to full dashboard
                  if (_auth.currentUser != null) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UnifiedMainDashboard(),
                      ),
                    );
                  }
                });
              },
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text(
                'Sign In',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Browse',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

// Placeholder screen for restricted content
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Sign in required',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please sign in to access $title',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

// Guest browse screen with database access - shows same products as buyer home
class _GuestBrowseScreen extends StatefulWidget {
  const _GuestBrowseScreen();

  @override
  State<_GuestBrowseScreen> createState() => _GuestBrowseScreenState();
}

class _GuestBrowseScreenState extends State<_GuestBrowseScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  // Check if user is authenticated
  bool get _isAuthenticated => _auth.currentUser != null;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Stream<QuerySnapshot> _getProductsStream() {
    Query query = _firestore.collection('products')
        .where('status', isEqualTo: 'approved');

    // Apply category filter
    if (_selectedCategory != null) {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    return query.orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  List<DocumentSnapshot> _filterBySearch(List<DocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;
    
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final description = (data['description'] ?? '').toString().toLowerCase();
      final category = (data['category'] ?? '').toString().toLowerCase();
      final searchLower = _searchQuery.toLowerCase();
      
      return name.contains(searchLower) || 
             description.contains(searchLower) || 
             category.contains(searchLower);
    }).toList();
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
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      icon: Icon(Icons.search),
                      hintText: 'Search for farm products',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
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

                // Products Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'All Products',
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
              stream: _getProductsStream(),
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

                // Filter products by search query
                final filteredDocs = _filterBySearch(snapshot.data!.docs);
                
                if (filteredDocs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Container(
                      height: 200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('No products match your search', 
                               style: TextStyle(color: Colors.grey[600], fontSize: 18)),
                          const SizedBox(height: 8),
                          Text('Try different keywords or browse all products',
                               style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  );
                }

                return SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      var product = filteredDocs[index].data() as Map<String, dynamic>;
                      String productId = filteredDocs[index].id;

                      double stockValue = (product['currentStock'] ?? product['quantity'] ?? 0).toDouble();

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
                      );
                    },
                    childCount: filteredDocs.length,
                  ),
                );
              },
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
      required String productId}) {
    bool hasStock = currentStock != null && currentStock > 0;

    return Card(
      elevation: 2,
      child: GestureDetector(
        onTap: () {
          // Allow guests to view product details without requiring login
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
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image with Stock Indicator
          Stack(
            children: [
              Container(
                height: 100,
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
              padding: const EdgeInsets.all(4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    price,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (hasStock) ...[
                    const SizedBox(height: 1),
                    Text(
                      'Stock: ${currentStock.toInt()}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  // Action Buttons
                  SizedBox(
                    height: 26,
                    child: Row(
                      children: [
                        Expanded(
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
                              backgroundColor: hasStock ? color : Colors.grey,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 26),
                            ),
                            child: const Text('View',
                                style: TextStyle(fontSize: 10)),
                          ),
                        ),
                        const SizedBox(width: 3),
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: ElevatedButton(
                            onPressed: hasStock
                                ? () async {
                                    // Check if user is authenticated
                                    if (!_isAuthenticated) {
                                      _showLoginPrompt();
                                      return;
                                    }
                                    // Cart functionality would go here for authenticated users
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  hasStock ? Colors.orange : Colors.grey,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                            ),
                            child: const Icon(Icons.add_shopping_cart,
                                size: 12),
                          ),
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
    );
  }
}
