import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/cart_service.dart';
import '../../services/rating_service.dart';
import '../../models/rating_model.dart';
import '../../widgets/rating_widgets.dart';
import '../buy_now_screen.dart';
import '../login_screen.dart';
import '../chat_detail_screen.dart';
import 'seller_details_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final String productId;

  const ProductDetailsScreen({
    Key? key,
    required this.product,
    required this.productId,
  }) : super(key: key);

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RatingService _ratingService = RatingService();

  Map<String, dynamic>? _sellerInfo;
  SellerRatingStats? _ratingStats;
  bool _isLoadingSeller = true;
  bool _isLoadingRating = true;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _loadSellerInfo();
  }

  Future<void> _loadSellerInfo() async {
    try {
      final sellerId = widget.product['sellerId'];
      if (sellerId != null) {
        // Load seller info and rating stats in parallel
        final futures = await Future.wait([
          _firestore.collection('users').doc(sellerId).get(),
          _ratingService.getSellerRatingStats(sellerId),
        ]);

        final sellerDoc = futures[0] as DocumentSnapshot;
        final ratingStats = futures[1] as SellerRatingStats;

        if (sellerDoc.exists) {
          setState(() {
            _sellerInfo = sellerDoc.data() as Map<String, dynamic>?;
            _ratingStats = ratingStats;
          });
        }
      }
    } catch (e) {
      print('Error loading seller info: $e');
    } finally {
      setState(() {
        _isLoadingSeller = false;
        _isLoadingRating = false;
      });
    }
  }

  Future<void> _startChatWithSeller() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showLoginPrompt();
      return;
    }

    final sellerId = widget.product['sellerId'];
    if (sellerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seller information not available'),
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

        await chatRef.set({
          'sellerId': sellerId,
          'customerId': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'lastSenderId': '',
          'unreadCustomerCount': 0,
          'unreadSellerCount': 0,
          'product': {
            'id': widget.productId,
            'name': widget.product['name'] ?? 'Product',
            'price': widget.product['price'] ?? 0,
            'imageUrl': widget.product['imageUrl'],
            'unit': widget.product['unit'] ?? 'piece',
          },
          'productId': widget.productId,
        });
      } else {
        // Use existing chat but update product info
        chatId = chatQuery.docs.first.id;

        await _firestore.collection('chats').doc(chatId).update({
          'product': {
            'id': widget.productId,
            'name': widget.product['name'] ?? 'Product',
            'price': widget.product['price'] ?? 0,
            'imageUrl': widget.product['imageUrl'],
            'unit': widget.product['unit'] ?? 'piece',
          },
          'productId': widget.productId,
        });
      }

      // Get seller name for the chat screen
      String sellerName = 'Seller';
      if (_sellerInfo != null) {
        sellerName =
            '${_sellerInfo!['firstName'] ?? ''} ${_sellerInfo!['lastName'] ?? ''}'
                .trim();
        if (sellerName.isEmpty) {
          sellerName = _sellerInfo!['name'] ?? 'Seller';
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
            product: widget.product,
            productId: widget.productId,
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

  Future<void> _addToCart() async {
    if (_auth.currentUser == null) {
      _showLoginPrompt();
      return;
    }

    try {
      final cartService = Provider.of<CartService>(context, listen: false);

      final cartItem = CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        productId: widget.productId,
        productName: widget.product['productName'] ??
            widget.product['name'] ??
            'Unknown Product',
        price: (widget.product['price'] ?? 0).toDouble(),
        imageUrl: widget.product['imageUrl'],
        sellerId: widget.product['sellerId'] ?? '',
        unit: widget.product['unit'] ?? 'pc',
        quantity: _quantity,
        isReservation: false,
      );

      print(
          'DEBUG: Adding item to cart - ProductID: ${widget.productId}, Quantity: $_quantity');

      bool success = await cartService.addItem(cartItem);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${widget.product['productName'] ?? widget.product['name']} added to cart'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Failed to add to cart - insufficient stock or other error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('ERROR: Failed to add to cart: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to cart: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
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

  String _formatHarvestDate(dynamic harvestDate) {
    if (harvestDate == null) return 'Date not specified';
    try {
      DateTime date;
      if (harvestDate is Timestamp) {
        date = harvestDate.toDate();
      } else if (harvestDate is String) {
        date = DateTime.parse(harvestDate);
      } else {
        return 'Date not specified';
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Date not specified';
    }
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

  String _getSellerName() {
    if (_sellerInfo == null) return 'Seller';

    // Try multiple name fields in order of preference
    final firstName = _sellerInfo!['firstName'];
    final lastName = _sellerInfo!['lastName'];
    final fullName = _sellerInfo!['fullName'];
    final name = _sellerInfo!['name'];
    final displayName = _sellerInfo!['displayName'];

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
    } else if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    } else {
      // Fallback to email username
      final email = _sellerInfo!['email'];
      if (email != null && email.isNotEmpty) {
        final emailName = email.toString().split('@').first;
        return emailName[0].toUpperCase() + emailName.substring(1);
      }
    }

    return 'Seller';
  }

  String _getSellerLocation() {
    if (_sellerInfo == null) return '';

    // Try multiple location fields
    final address = _sellerInfo!['address'];
    final location = _sellerInfo!['location'];
    final city = _sellerInfo!['city'];
    final province = _sellerInfo!['province'];
    final region = _sellerInfo!['region'];

    if (address != null && address.isNotEmpty) {
      return address;
    } else if (location != null && location.isNotEmpty) {
      return location;
    } else if (city != null && city.isNotEmpty) {
      if (province != null && province.isNotEmpty) {
        return '$city, $province';
      } else {
        return city;
      }
    } else if (province != null && province.isNotEmpty) {
      return province;
    } else if (region != null && region.isNotEmpty) {
      return region;
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.product['productName'] ??
        widget.product['name'] ??
        'Unknown Product';
    final description =
        widget.product['description'] ?? 'No description available';
    final category = widget.product['category'] ?? 'Uncategorized';
    final unit = widget.product['unit'] ?? 'pc';
    final price = widget.product['price'] ?? 0;
    final imageUrl = widget.product['imageUrl'];
    final currentStock = widget.product['currentStock'];
    final availableDate = widget.product['availableDate'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              width: double.infinity,
              height: 300,
              color: Colors.grey.shade200,
              child: imageUrl != null && imageUrl.toString().isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 80,
                          ),
                        );
                      },
                    )
                  : const Icon(
                      Icons.image,
                      color: Colors.grey,
                      size: 80,
                    ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name and Category
                  Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Price and Unit
                  Row(
                    children: [
                      Text(
                        _formatPrice(price),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        ' per $unit',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Stock and Availability
                  Row(
                    children: [
                      if (currentStock != null) ...[
                        Icon(
                          Icons.inventory,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Stock: ${currentStock.toInt()}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      // Only show availability date for Pre Order products
                      if (widget.product['orderType'] == 'Pre Order') ...[
                        if (currentStock != null) const SizedBox(width: 16),
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatAvailableDate(availableDate),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Order Type
                  if (widget.product['orderType'] != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.product['orderType'] == 'Available Now'
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.product['orderType'] == 'Available Now'
                              ? Colors.green
                              : Colors.orange,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.product['orderType'] == 'Available Now'
                                ? Icons.check_circle
                                : Icons.schedule,
                            size: 16,
                            color:
                                widget.product['orderType'] == 'Available Now'
                                    ? Colors.green
                                    : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.product['orderType'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color:
                                  widget.product['orderType'] == 'Available Now'
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 24),

                  // Delivery Options
                  if (widget.product['deliveryOptions'] != null &&
                      (widget.product['deliveryOptions'] as List)
                          .isNotEmpty) ...[
                    const Text(
                      'Available Delivery Methods',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.local_shipping,
                                color: Colors.green.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'This seller offers:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children:
                                (widget.product['deliveryOptions'] as List)
                                    .map<Widget>((option) {
                              IconData iconData;
                              Color chipColor;
                              Color textColor;
                              String displayText = option.toString();

                              switch (option.toString().toLowerCase()) {
                                case 'delivery':
                                case 'cooperative delivery':
                                  iconData = Icons.delivery_dining;
                                  chipColor = Colors.blue;
                                  textColor = Colors.blue.shade700;
                                  displayText = 'Cooperative Delivery';
                                  break;
                                case 'pick up':
                                  iconData = Icons.storefront;
                                  chipColor = Colors.green;
                                  textColor = Colors.green.shade700;
                                  displayText = 'Pick Up';
                                  break;
                                default:
                                  iconData = Icons.local_shipping;
                                  chipColor = Colors.grey;
                                  textColor = Colors.grey.shade700;
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: chipColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: chipColor.withOpacity(0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      iconData,
                                      size: 14,
                                      color: textColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      displayText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Harvest Date (if available)
                  if (widget.product['harvestDate'] != null) ...[
                    const Text(
                      'Harvest Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.agriculture,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Harvested on: ${_formatHarvestDate(widget.product['harvestDate'])}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 8),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Seller Information
                  if (!_isLoadingSeller && _sellerInfo != null) ...[
                    const Text(
                      'Seller Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SellerDetailsScreen(
                              sellerId: widget.product['sellerId'],
                              sellerInfo: _sellerInfo,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            // Enhanced Avatar with border
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.green.shade300, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.green,
                                child: Text(
                                  (_sellerInfo!['firstName']?[0] ??
                                          _sellerInfo!['name']?[0] ??
                                          _sellerInfo!['fullName']?[0] ??
                                          'S')
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Seller Name
                                  Text(
                                    _getSellerName(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Rating Section
                                  if (!_isLoadingRating &&
                                      _ratingStats != null) ...[
                                    RatingWidget(
                                      rating: _ratingStats!.averageRating,
                                      showText: true,
                                      size: 16,
                                      customText:
                                          '${_ratingStats!.averageRating.toStringAsFixed(1)} (${_ratingStats!.totalReviews})',
                                    ),
                                  ] else if (!_isLoadingRating) ...[
                                    Row(
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(5, (index) {
                                            return Icon(
                                              Icons.star_border,
                                              color: Colors.grey.shade400,
                                              size: 16,
                                            );
                                          }),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'No rating (0)',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Row(
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(5, (index) {
                                            return Icon(
                                              Icons.star_border,
                                              color: Colors.grey.shade300,
                                              size: 16,
                                            );
                                          }),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Loading...',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 4),

                                  // Location
                                  if (_getSellerLocation().isNotEmpty)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          color: Colors.grey.shade600,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            _getSellerLocation(),
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),

                                  // Tap to view profile hint
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to view seller profile',
                                    style: TextStyle(
                                      color: Colors.green.shade600,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),

                                  // Member since or verification badge
                                  if (_sellerInfo!['verified'] == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.verified,
                                            color: Colors.blue,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Verified Seller',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Message button and arrow icon
                            Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    onPressed: _startChatWithSeller,
                                    icon: const Icon(
                                      Icons.message,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    tooltip: 'Message Seller',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey.shade400,
                                  size: 16,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Quantity Selector
                  Row(
                    children: [
                      const Text(
                        'Quantity:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                              icon: const Icon(Icons.remove),
                              iconSize: 20,
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                _quantity.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _quantity++),
                              icon: const Icon(Icons.add),
                              iconSize: 20,
                            ),
                          ],
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addToCart,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add to Cart'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (_auth.currentUser == null) {
                    _showLoginPrompt();
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BuyNowScreen(
                        product: widget.product,
                        productId: widget.productId,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Buy Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
