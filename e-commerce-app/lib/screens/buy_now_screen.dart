import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/cart_service.dart';
import '../services/rating_service.dart';
import '../models/rating_model.dart';
import '../widgets/rating_widgets.dart';
import '../widgets/address_selector.dart';
import 'checkout_screen.dart';
import 'login_screen.dart';
import 'buyer/seller_details_screen.dart';
import 'paymongo_gcash_screen.dart';

class BuyNowScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final String productId;

  const BuyNowScreen({
    Key? key,
    required this.product,
    required this.productId,
  }) : super(key: key);

  @override
  State<BuyNowScreen> createState() => _BuyNowScreenState();
}

class _BuyNowScreenState extends State<BuyNowScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final RatingService _ratingService = RatingService();

  Map<String, dynamic>? _sellerInfo;
  SellerRatingStats? _ratingStats;
  bool _isLoadingSeller = true;
  bool _isLoadingRating = true;
  int _quantity = 1;
  bool _isLoading = false;
  String? _selectedDeliveryOption = 'Pickup at Coop';
  String? _selectedPaymentOption = 'Cash';
  // Store delivery address (informational only, actual validation in cart screen)
  // ignore: unused_field
  Map<String, String> _deliveryAddress = {};
  String? _coopPickupLocation;
  bool _isLoadingLocation = false;

  final List<String> _deliveryOptions = [
    'Cooperative Delivery',
    'Pickup at Coop'
  ];
  final List<String> _paymentOptions = ['Cash', 'GCash'];

  @override
  void initState() {
    super.initState();
    _loadSellerInfo();
    _loadCooperativeLocation();
  }

  @override
  void dispose() {
    super.dispose();
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

  Future<void> _loadCooperativeLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Get the product to find the seller ID
      final productDoc = await _firestore
          .collection('products')
          .doc(widget.productId)
          .get();
      
      if (productDoc.exists) {
        final productData = productDoc.data() as Map<String, dynamic>;
        final sellerId = productData['sellerId'] as String?;
        
        if (sellerId != null) {
          // Get the seller document to find their cooperative ID
          final sellerDoc = await _firestore
              .collection('users')
              .doc(sellerId)
              .get();
          
          if (sellerDoc.exists) {
            final sellerData = sellerDoc.data() as Map<String, dynamic>;
            final cooperativeId = sellerData['cooperativeId'] as String?;
            
            if (cooperativeId != null) {
              // Get the cooperative document to retrieve the location
              final coopDoc = await _firestore
                  .collection('users')
                  .doc(cooperativeId)
                  .get();
              
              if (coopDoc.exists) {
                final coopData = coopDoc.data() as Map<String, dynamic>;
                setState(() {
                  _coopPickupLocation = coopData['location'] as String?;
                });
                print('Found cooperative location from seller: $_coopPickupLocation');
                return;
              }
            }
          }
        }
      }
      
      // Fallback: Query for any cooperative user if seller's cooperative not found
      final coopQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'cooperative')
          .limit(1)
          .get();

      if (coopQuery.docs.isNotEmpty) {
        final coopData = coopQuery.docs.first.data();
        setState(() {
          _coopPickupLocation = coopData['location'] as String?;
        });
      }
    } catch (e) {
      print('Error loading cooperative location: $e');
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
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

  double _calculateTotal() {
    double price = widget.product['price'] is int
        ? (widget.product['price'] as int).toDouble()
        : widget.product['price'] as double;
    return price * _quantity;
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

  Future<void> _buyNow() async {
    // Validate user authentication
    if (_auth.currentUser == null) {
      _showLoginPrompt();
      return;
    }

    // Validate delivery address if Cooperative Delivery is selected
    if (_selectedDeliveryOption == 'Cooperative Delivery') {
      if (_deliveryAddress.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your delivery address'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_deliveryAddress['fullAddress'] == null ||
          _deliveryAddress['fullAddress']!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please complete your delivery address'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Show loading state
    setState(() {
      _isLoading = true;
    });

    try {
      print('DEBUG: Starting order placement...');
      print('DEBUG: Selected delivery option: $_selectedDeliveryOption');
      print('DEBUG: Selected payment option: $_selectedPaymentOption');
      print('DEBUG: Delivery address: $_deliveryAddress');

      final cartService = Provider.of<CartService>(context, listen: false);

      // Create a temporary cart with this single item
      final cartItem = CartItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}',
        productId: widget.productId,
        sellerId: widget.product['sellerId'],
        productName: widget.product['name'],
        price: widget.product['price'] is int
            ? (widget.product['price'] as int).toDouble()
            : widget.product['price'] as double,
        quantity: _quantity,
        unit: widget.product['unit'] ?? 'piece',
        isReservation: false,
        imageUrl: widget.product['imageUrl'],
      );

      print(
          'DEBUG: Cart item created: ${cartItem.productName} x ${cartItem.quantity}');

      // Clear cart and add only this item
      await cartService.clearCart();
      print('DEBUG: Cart cleared');

      final added = await cartService.addItem(cartItem);
      print('DEBUG: Item added to cart: $added');

      if (!added) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Sorry, not enough stock available for this quantity'),
              duration: Duration(seconds: 4),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      print('DEBUG: Processing cart...');

      // Process the order directly
      final success = await cartService.processCart(
        _auth.currentUser!.uid,
        paymentMethod: _selectedPaymentOption ?? 'Cash',
        deliveryMethod: _selectedDeliveryOption ?? 'Pickup at Coop',
        meetupLocation: null,
        deliveryAddress: _selectedDeliveryOption == 'Cooperative Delivery'
            ? _deliveryAddress['fullAddress']
            : null,
      );

      print('DEBUG: Cart processed successfully: $success');

      if (success) {
        print('DEBUG: Order placed successfully!');

        // If GCash payment is selected, navigate to PayMongo GCash payment screen
        if (_selectedPaymentOption == 'GCash') {
          if (mounted) {
            // Get the order ID that was just created
            final orderId =
                'order_${DateTime.now().millisecondsSinceEpoch}_${widget.productId}';

            // Navigate to PayMongo GCash payment screen
            final paymentCompleted = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PayMongoGCashScreen(
                  amount: (widget.product['price'] is int
                          ? (widget.product['price'] as int).toDouble()
                          : widget.product['price'] as double) *
                      _quantity,
                  orderId: orderId,
                  userId: _auth.currentUser!.uid,
                  orderDetails: {
                    'productName': widget.product['name'],
                    'quantity': _quantity,
                    'unit': widget.product['unit'] ?? 'pc',
                    'deliveryMethod': _selectedDeliveryOption,
                    'deliveryAddress':
                        _selectedDeliveryOption == 'Cooperative Delivery'
                            ? _deliveryAddress['fullAddress']
                            : null,
                  },
                ),
              ),
            );

            // After returning from GCash payment, go to orders screen
            if (paymentCompleted == true && mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const CheckoutScreen(),
                ),
              );
            }
          }
        } else {
          // For Cash payment, show success dialog
          if (mounted) {
            _showSuccessDialog();
          }
        }
      } else {
        print('DEBUG: Order placement failed - processCart returned false');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Unable to place order. Please check your connection and try again.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('ERROR placing order: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'An error occurred: ${e.toString()}',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 6),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: () {
                _buyNow();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('DEBUG: Order placement process completed');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Text(
                'Order Placed Successfully!',
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your order has been successfully placed!',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Divider(),
              SizedBox(height: 8),
              Text(
                'Order Details:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Text('Product: ${widget.product['name']}'),
              Text('Quantity: $_quantity ${widget.product['unit'] ?? 'pc'}'),
              Text(
                'Total: ₱${((widget.product['price'] is int ? (widget.product['price'] as int).toDouble() : widget.product['price'] as double) * _quantity).toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 8),
              Text('Delivery: $_selectedDeliveryOption'),
              Text('Payment: $_selectedPaymentOption'),
              if (_selectedDeliveryOption == 'Cooperative Delivery' &&
                  _deliveryAddress['fullAddress'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Address: ${_deliveryAddress['fullAddress']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to product list
              },
              child: Text('Continue Shopping'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CheckoutScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('View Orders'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extract product data
    final productName = widget.product['name'] ?? 'Product Name';
    final description =
        widget.product['description'] ?? 'No description available';
    final unit = widget.product['unit'] ?? 'unit';
    final double price = widget.product['price'] is int
        ? (widget.product['price'] as int).toDouble()
        : widget.product['price'] as double;

    // Get current stock information
    final double currentStock = widget.product['currentStock'] is int
        ? (widget.product['currentStock'] as int).toDouble()
        : (widget.product['currentStock'] as double? ?? 0.0);

    // Set max quantity to available stock
    final int maxQuantity = currentStock.toInt();

    // Availability date
    String availableDate = 'Now';
    if (widget.product['availableDate'] != null) {
      try {
        final date = DateTime.parse(widget.product['availableDate']);
        availableDate = DateFormat('MM/dd/yyyy').format(date);
      } catch (e) {
        // Use default
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Share functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.grey[200],
              child: widget.product['imageUrl'] != null &&
                      widget.product['imageUrl'].toString().isNotEmpty
                  ? Image.network(
                      widget.product['imageUrl'],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.green),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                        child: Icon(
                          Icons.shopping_basket,
                          size: 80,
                          color: Colors.green,
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.shopping_basket,
                        size: 80,
                        color: Colors.green,
                      ),
                    ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Product Description
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quantity and Availability
                  Row(
                    children: [
                      // Weight/Quantity - Updated to show current stock
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            StreamBuilder<DocumentSnapshot>(
                              stream: _firestore
                                  .collection('products')
                                  .doc(widget.productId)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                // Default to the initial value from the product
                                double stockDisplay = currentStock;

                                // Update with live data if available
                                if (snapshot.hasData &&
                                    snapshot.data != null &&
                                    snapshot.data!.exists) {
                                  final data = snapshot.data!.data()
                                      as Map<String, dynamic>?;
                                  if (data != null &&
                                      data['currentStock'] != null) {
                                    stockDisplay = data['currentStock'] is int
                                        ? (data['currentStock'] as int)
                                            .toDouble()
                                        : data['currentStock'] as double;
                                  }
                                }

                                return Text(
                                  '${stockDisplay.toStringAsFixed(0)} $unit available',
                                  style: TextStyle(
                                    color: stockDisplay > 0
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Availability Date
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              availableDate,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Seller Information
                  GestureDetector(
                    onTap: () {
                      if (widget.product['sellerId'] != null &&
                          _sellerInfo != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SellerDetailsScreen(
                              sellerId: widget.product['sellerId'],
                              sellerInfo: _sellerInfo,
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.green.shade300, width: 2),
                            ),
                            child: CircleAvatar(
                              backgroundColor: Colors.green,
                              radius: 20,
                              child: Text(
                                !_isLoadingSeller && _sellerInfo != null
                                    ? _getSellerName()[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  !_isLoadingSeller
                                      ? _getSellerName()
                                      : 'Loading...',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                if (!_isLoadingSeller &&
                                    _getSellerLocation().isNotEmpty)
                                  Text(
                                    _getSellerLocation(),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                const SizedBox(height: 4),
                                // Rating Section
                                if (!_isLoadingRating &&
                                    _ratingStats != null) ...[
                                  RatingWidget(
                                    rating: _ratingStats!.averageRating,
                                    showText: true,
                                    size: 14,
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
                                            size: 14,
                                          );
                                        }),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'No rating (0)',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
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
                                            size: 14,
                                          );
                                        }),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Loading...',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey.shade400,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 32),

                  // Order Options
                  const Text(
                    'Order Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quantity Selector
                  Row(
                    children: [
                      const Text(
                        'Quantity:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              onPressed: _quantity > 1
                                  ? () {
                                      setState(() {
                                        _quantity--;
                                      });
                                    }
                                  : null,
                            ),
                            Text(
                              _quantity.toString(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              onPressed: _quantity < maxQuantity
                                  ? () {
                                      setState(() {
                                        _quantity++;
                                      });
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Delivery Options
                  const Text(
                    'Delivery Options',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Delivery Radio Buttons
                  ...List.generate(_deliveryOptions.length, (index) {
                    return RadioListTile<String>(
                      title: Text(_deliveryOptions[index]),
                      value: _deliveryOptions[index],
                      groupValue: _selectedDeliveryOption,
                      onChanged: (value) {
                        setState(() {
                          _selectedDeliveryOption = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  }),

                  // Delivery Address Field (show only for Cooperative Delivery)
                  if (_selectedDeliveryOption == 'Cooperative Delivery') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Delivery Address *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AddressSelector(
                      onAddressChanged: (address) {
                        setState(() {
                          _deliveryAddress = address;
                        });
                      },
                    ),
                  ],

                  // Pickup Location (show only for Pickup at Coop)
                  if (_selectedDeliveryOption == 'Pickup at Coop') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Pickup Location',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.green.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _isLoadingLocation
                                ? const Text(
                                    'Loading location...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                : Text(
                                    _coopPickupLocation ??
                                        'Pickup location not set',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Payment Options
                  const Text(
                    'Payment Options',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Payment Radio Buttons
                  ...List.generate(_paymentOptions.length, (index) {
                    return RadioListTile<String>(
                      title: Text(_paymentOptions[index]),
                      value: _paymentOptions[index],
                      groupValue: _selectedPaymentOption,
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentOption = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  }),

                  const Divider(height: 32),

                  // Order Summary
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Price:'),
                      Text('₱${price.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Quantity:'),
                      Text('$_quantity'),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '₱${_calculateTotal().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Place Order Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isLoading ? Colors.grey : Colors.green,
                        foregroundColor: Colors.white,
                        elevation: _isLoading ? 0 : 2,
                      ),
                      onPressed: _isLoading
                          ? null
                          : () {
                              print('DEBUG: Place Order button pressed');
                              _buyNow();
                            },
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Processing...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.shopping_bag, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Place Order',
                                  style: TextStyle(
                                    fontSize: 16,
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
          ],
        ),
      ),
    );
  }
}
