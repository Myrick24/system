import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'product_details_screen.dart';
import '../../models/rating_model.dart';
import '../../services/rating_service.dart';
import '../../widgets/rating_widgets.dart';
import '../../widgets/rating_dialog.dart';

class SellerDetailsScreen extends StatefulWidget {
  final String sellerId;
  final Map<String, dynamic>? sellerInfo;

  const SellerDetailsScreen({
    Key? key,
    required this.sellerId,
    this.sellerInfo,
  }) : super(key: key);

  @override
  State<SellerDetailsScreen> createState() => _SellerDetailsScreenState();
}

class _SellerDetailsScreenState extends State<SellerDetailsScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RatingService _ratingService = RatingService();
  
  Map<String, dynamic>? _sellerInfo;
  List<Map<String, dynamic>> _sellerProducts = [];
  SellerRatingStats? _ratingStats;
  Rating? _currentUserRating;
  bool _isLoadingSeller = true;
  bool _isLoadingProducts = true;
  bool _isLoadingReviews = true;
  bool _isLoadingRatingStats = true;
  bool _hasUserRated = false;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _sellerInfo = widget.sellerInfo;
    if (_sellerInfo != null) {
      _isLoadingSeller = false;
    }
    
    print('DEBUG: SellerDetailsScreen initialized with sellerId: "${widget.sellerId}"');
    print('DEBUG: SellerInfo provided: ${_sellerInfo != null}');
    
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Temporarily disable migration to focus on basic functionality
    // await _runMigrationIfNeeded();
    
    // Load all data
    await Future.wait([
      _loadSellerData(),
      _loadSellerProducts(),
      _loadSellerReviews(),
      _checkUserRating(),
      _loadRatingStats(),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSellerData() async {
    if (_sellerInfo != null) return;
    
    try {
      final sellerDoc = await _firestore.collection('users').doc(widget.sellerId).get();
      if (sellerDoc.exists) {
        Map<String, dynamic> sellerData = sellerDoc.data()!;
        
        // Initialize rating fields if they don't exist
        if (!sellerData.containsKey('rating') || !sellerData.containsKey('totalReviews')) {
          await _firestore.collection('users').doc(widget.sellerId).update({
            'rating': 0.0,
            'totalReviews': 0,
            'ratingInitialized': true,
          });
          sellerData['rating'] = 0.0;
          sellerData['totalReviews'] = 0;
        }
        
        setState(() {
          _sellerInfo = sellerData;
          _isLoadingSeller = false;
        });
      }
    } catch (e) {
      print('Error loading seller data: $e');
      setState(() {
        _isLoadingSeller = false;
      });
    }
  }

  Future<void> _loadSellerProducts() async {
    try {
      print('DEBUG: Starting to load products for sellerId: "${widget.sellerId}"');
      print('DEBUG: SellerId type: ${widget.sellerId.runtimeType}');
      print('DEBUG: SellerId length: ${widget.sellerId.length}');
      
      // Combine results and remove duplicates
      Set<String> productIds = {};
      List<Map<String, dynamic>> allProducts = [];
      
      // Query 1: sellerId field
      try {
        final query1 = await _firestore
            .collection('products')
            .where('sellerId', isEqualTo: widget.sellerId)
            .get();
        print('DEBUG: Query 1 (sellerId) found ${query1.docs.length} products');
        
        for (var doc in query1.docs) {
          if (!productIds.contains(doc.id)) {
            final data = doc.data();
            data['id'] = doc.id;
            allProducts.add(data);
            productIds.add(doc.id);
            print('DEBUG: Added product from sellerId: ${data['name'] ?? data['productName'] ?? 'Unnamed'} (ID: ${doc.id}, Status: ${data['status'] ?? 'no status'})');
          }
        }
      } catch (e) {
        print('DEBUG: Query 1 (sellerId) failed: $e');
      }
      
      // Query 2: userId field
      try {
        final query2 = await _firestore
            .collection('products')
            .where('userId', isEqualTo: widget.sellerId)
            .get();
        print('DEBUG: Query 2 (userId) found ${query2.docs.length} products');
        
        for (var doc in query2.docs) {
          if (!productIds.contains(doc.id)) {
            final data = doc.data();
            data['id'] = doc.id;
            allProducts.add(data);
            productIds.add(doc.id);
            print('DEBUG: Added product from userId: ${data['name'] ?? data['productName'] ?? 'Unnamed'} (ID: ${doc.id}, Status: ${data['status'] ?? 'no status'})');
          }
        }
      } catch (e) {
        print('DEBUG: Query 2 (userId) failed: $e');
      }
      
      // Query 3: owner field (in case products use this field)
      try {
        final query3 = await _firestore
            .collection('products')
            .where('owner', isEqualTo: widget.sellerId)
            .get();
        print('DEBUG: Query 3 (owner) found ${query3.docs.length} products');
        
        for (var doc in query3.docs) {
          if (!productIds.contains(doc.id)) {
            final data = doc.data();
            data['id'] = doc.id;
            allProducts.add(data);
            productIds.add(doc.id);
            print('DEBUG: Added product from owner: ${data['name'] ?? data['productName'] ?? 'Unnamed'} (ID: ${doc.id}, Status: ${data['status'] ?? 'no status'})');
          }
        }
      } catch (e) {
        print('DEBUG: Query 3 (owner) failed: $e');
      }
      
      // Query 4: Try getting ALL products and filter manually (comprehensive check)
      try {
        final queryAll = await _firestore
            .collection('products')
            .get();
        print('DEBUG: Query ALL found ${queryAll.docs.length} total products');
        
        int foundMatches = 0;
        int totalChecked = 0;
        for (var doc in queryAll.docs) {
          final data = doc.data();
          final docSellerId = data['sellerId']?.toString().trim() ?? '';
          final docUserId = data['userId']?.toString().trim() ?? '';
          final docOwner = data['owner']?.toString().trim() ?? '';
          final targetId = widget.sellerId.trim();
          totalChecked++;
          
          // Debug first few products to understand the data structure
          if (totalChecked <= 10) { 
            print('DEBUG: Product $totalChecked: name="${data['name'] ?? data['productName'] ?? 'Unnamed'}", sellerId="$docSellerId", userId="$docUserId", owner="$docOwner", status="${data['status'] ?? 'no status'}"');
          }
          
          // Check all possible fields
          if (docSellerId == targetId || docUserId == targetId || docOwner == targetId) {
            if (!productIds.contains(doc.id)) {
              data['id'] = doc.id;
              allProducts.add(data);
              productIds.add(doc.id);
              foundMatches++;
              print('DEBUG: ✓ MATCH FOUND! Product: ${data['name'] ?? data['productName'] ?? 'Unnamed'} (ID: ${doc.id})');
              print('DEBUG: Match details - sellerId: "$docSellerId", userId: "$docUserId", owner: "$docOwner", target: "$targetId", status: "${data['status'] ?? 'no status'}"');
            }
          }
        }
        print('DEBUG: Manual scan checked $totalChecked products, found $foundMatches matching products');
      } catch (e) {
        print('DEBUG: Query ALL failed: $e');
      }

      // Filter products for display - temporarily show all for debugging
      // final approvedProducts = allProducts.where((product) => product['status'] == 'approved').toList();
      final approvedProducts = allProducts; // TEMPORARY: Show all products for debugging
      print('DEBUG: Total products found: ${allProducts.length}, Showing products: ${approvedProducts.length}');
      
      for (var product in allProducts) {
        print('DEBUG: Product: ${product['name'] ?? product['productName'] ?? 'Unnamed'} (ID: ${product['id']}, Status: ${product['status'] ?? 'no status'})');
      }

      setState(() {
        _sellerProducts = approvedProducts; // Only show approved products
        _isLoadingProducts = false;
      });
      
    } catch (e) {
      print('ERROR: Failed to load seller products: $e');
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _loadSellerReviews() async {
    try {
      final reviewsQuery = await _firestore
          .collection('seller_ratings')
          .where('sellerId', isEqualTo: widget.sellerId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      List<Map<String, dynamic>> reviews = [];
      for (var doc in reviewsQuery.docs) {
        final reviewData = doc.data();
        reviewData['id'] = doc.id;
        
        // Get reviewer info
        try {
          final reviewerDoc = await _firestore
              .collection('users')
              .doc(reviewData['reviewerId'])
              .get();
          if (reviewerDoc.exists) {
            reviewData['reviewerInfo'] = reviewerDoc.data();
          }
        } catch (e) {
          print('Error loading reviewer info: $e');
        }
        
        reviews.add(reviewData);
      }

      setState(() {
        _isLoadingReviews = false;
      });
    } catch (e) {
      print('Error loading seller reviews: $e');
      setState(() {
        _isLoadingReviews = false;
      });
    }
  }

  Future<void> _checkUserRating() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Use the new rating service
      _currentUserRating = await _ratingService.getUserRatingForSeller(widget.sellerId);
      
      if (_currentUserRating != null) {
        setState(() {
          _hasUserRated = true;
        });
      } else {
        // Check old rating system for backward compatibility
        final userRatingQuery = await _firestore
            .collection('seller_ratings')
            .where('sellerId', isEqualTo: widget.sellerId)
            .where('reviewerId', isEqualTo: currentUser.uid)
            .limit(1)
            .get();

        if (userRatingQuery.docs.isNotEmpty) {
          setState(() {
            _hasUserRated = true;
          });
        }
      }
    } catch (e) {
      print('Error checking user rating: $e');
    }
  }

  Future<void> _loadRatingStats() async {
    try {
      setState(() {
        _isLoadingRatingStats = true;
      });

      _ratingStats = await _ratingService.getSellerRatingStats(widget.sellerId);
      
      // Update seller info with latest rating data
      if (_sellerInfo != null && _ratingStats != null) {
        setState(() {
          _sellerInfo!['rating'] = _ratingStats!.averageRating;
          _sellerInfo!['totalReviews'] = _ratingStats!.totalReviews;
        });
      }
      
      setState(() {
        _isLoadingRatingStats = false;
      });
    } catch (e) {
      print('Error loading rating stats: $e');
      setState(() {
        _isLoadingRatingStats = false;
      });
    }
  }

  void _showRatingDialog() {
    showRatingDialog(
      context: context,
      sellerId: widget.sellerId,
      sellerName: _getSellerName(),
      existingRating: _currentUserRating,
    ).then((updated) {
      if (updated == true) {
        // Refresh data
        _checkUserRating();
        _loadRatingStats();
      }
    });
  }

  String _getSellerName() {
    if (_sellerInfo == null) return 'Seller';
    
    final firstName = _sellerInfo!['firstName'];
    final lastName = _sellerInfo!['lastName'];
    final fullName = _sellerInfo!['fullName'];
    final name = _sellerInfo!['name'];
    
    if (firstName != null && firstName.isNotEmpty) {
      if (lastName != null && lastName.isNotEmpty) {
        return '$firstName $lastName';
      } else {
        return firstName;
      }
    } else if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    } else if (name != null && name.isNotEmpty) {
      return name;
    }
    
    return 'Seller';
  }

  String _getSellerLocation() {
    if (_sellerInfo == null) return '';
    
    final address = _sellerInfo!['address'];
    final city = _sellerInfo!['city'];
    final province = _sellerInfo!['province'];
    
    if (address != null && address.isNotEmpty) {
      return address;
    } else if (city != null && city.isNotEmpty) {
      if (province != null && province.isNotEmpty) {
        return '$city, $province';
      } else {
        return city;
      }
    } else if (province != null && province.isNotEmpty) {
      return province;
    }
    
    return '';
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '₱0.00';
    if (price is int) return '₱${price.toDouble().toStringAsFixed(2)}';
    if (price is double) return '₱${price.toStringAsFixed(2)}';
    return '₱0.00';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSeller) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Seller Details'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getSellerName()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Seller Header
          Container(
            width: double.infinity,
            color: Colors.green,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              children: [
                // Seller Avatar and Basic Info
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        child: Text(
                          (_sellerInfo!['firstName']?[0] ?? 
                           _sellerInfo!['name']?[0] ?? 'S').toUpperCase(),
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getSellerName(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_getSellerLocation().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _getSellerLocation(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          // Rating
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  RatingWidget(
                                    rating: _sellerInfo!['rating']?.toDouble() ?? 0.0,
                                    size: 18,
                                    activeColor: Colors.amber,
                                    inactiveColor: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _sellerInfo!['totalReviews'] != null && _sellerInfo!['totalReviews'] > 0
                                        ? '${(_sellerInfo!['rating']?.toDouble() ?? 0).toStringAsFixed(1)}'
                                        : 'No rating yet',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '(${_sellerInfo!['totalReviews'] ?? 0} reviews)',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showRatingDialog,
                        icon: Icon(_hasUserRated ? Icons.edit : Icons.star),
                        label: Text(_hasUserRated ? 'Update Rating' : 'Rate Seller'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Implement chat with seller
                        },
                        icon: const Icon(Icons.message),
                        label: const Text('Message'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: Colors.green,
            indicatorColor: Colors.green,
            tabs: const [
              Tab(text: 'Products'),
              Tab(text: 'Reviews'),
              Tab(text: 'About'),
            ],
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Products Tab
                _buildProductsTab(),
                
                // Reviews Tab
                _buildReviewsTab(),
                
                // About Tab
                _buildAboutTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTab() {
    if (_isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sellerProducts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No products available', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _sellerProducts.length,
      itemBuilder: (context, index) {
        final product = _sellerProducts[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailsScreen(
                  product: product,
                  productId: product['id'],
                ),
              ),
            );
          },
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      color: Colors.grey.shade200,
                    ),
                    child: product['imageUrl'] != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image.network(
                              product['imageUrl'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.image_not_supported, color: Colors.grey);
                              },
                            ),
                          )
                        : const Icon(Icons.image, color: Colors.grey, size: 40),
                  ),
                ),
                
                // Product Info
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product['productName'] ?? product['name'] ?? 'Product',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatPrice(product['price']),
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'per ${product['unit'] ?? 'pc'}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
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
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    return Column(
      children: [
        // Rating Statistics Section
        if (!_isLoadingRatingStats && _ratingStats != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: RatingDistributionWidget(stats: _ratingStats!),
          ),
          const Divider(height: 1),
        ],
        
        // Reviews List
        Expanded(
          child: _buildReviewsList(),
        ),
      ],
    );
  }

  Widget _buildReviewsList() {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    // Use stream to get real-time updates of ratings
    return StreamBuilder<List<Rating>>(
      stream: _ratingService.getSellerRatings(widget.sellerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading reviews: ${snapshot.error}'),
          );
        }

        final ratings = snapshot.data ?? [];

        if (ratings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No reviews yet', style: TextStyle(color: Colors.grey)),
                SizedBox(height: 8),
                Text('Be the first to review this seller!', 
                     style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ratings.length,
          itemBuilder: (context, index) {
            final rating = ratings[index];
            return ReviewCard(
              rating: rating,
              showProductInfo: true,
              onReport: () async {
                await _ratingService.reportReview(
                  ratingId: rating.id,
                  reason: 'Inappropriate content',
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seller Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seller Statistics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'Products',
                          '${_sellerProducts.length}',
                          Icons.inventory_2,
                          Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          'Reviews',
                          '${_sellerInfo!['totalReviews'] ?? 0}',
                          Icons.star,
                          Colors.amber,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          'Rating',
                          _sellerInfo!['totalReviews'] != null && _sellerInfo!['totalReviews'] > 0
                              ? '${(_sellerInfo!['rating']?.toDouble() ?? 0).toStringAsFixed(1)}'
                              : 'N/A',
                          Icons.thumb_up,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Seller Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seller Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_sellerInfo!['email'] != null)
                    _buildInfoRow(Icons.email, 'Email', _sellerInfo!['email']),
                  
                  if (_sellerInfo!['phone'] != null)
                    _buildInfoRow(Icons.phone, 'Phone', _sellerInfo!['phone']),
                  
                  if (_getSellerLocation().isNotEmpty)
                    _buildInfoRow(Icons.location_on, 'Location', _getSellerLocation()),
                  
                  if (_sellerInfo!['verified'] == true)
                    _buildInfoRow(Icons.verified, 'Status', 'Verified Seller'),
                  
                  if (_sellerInfo!['memberSince'] != null)
                    _buildInfoRow(
                      Icons.calendar_today,
                      'Member Since',
                      DateFormat('MMMM y').format(
                        (_sellerInfo!['memberSince'] as Timestamp).toDate()
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}