import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/cart_service.dart';
import 'cart_checkout_screen.dart';
import 'buyer/product_details_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  // Selection state
  Set<String> _selectedItems = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    if (_auth.currentUser != null) {
      setState(() {
        _isLoading = true;
      });

      final cartService = Provider.of<CartService>(context, listen: false);
      await cartService.loadCartFromDatabase(_auth.currentUser!.uid);

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToProductDetails(String productId) async {
    try {
      // Fetch product details from Firestore
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      if (!productDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product not found'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final productData = productDoc.data()!;
      productData['id'] = productDoc.id;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(
              product: productData,
              productId: productId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading product: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Text(
              'Shopping Cart',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Consumer<CartService>(
              builder: (context, cartService, child) {
                return cartService.cartItems.isNotEmpty
                    ? Text(
                        ' (${cartService.cartItems.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      )
                    : const SizedBox.shrink();
              },
            ),
          ],
        ),
        actions: [
          Consumer<CartService>(
            builder: (context, cartService, child) {
              return cartService.cartItems.isNotEmpty
                  ? TextButton(
                      onPressed: () {
                        setState(() {
                          _selectAll = !_selectAll;
                          if (_selectAll) {
                            _selectedItems = cartService.cartItems
                                .map((item) => item.id)
                                .toSet();
                          } else {
                            _selectedItems.clear();
                          }
                        });
                      },
                      child: Text(
                        _selectAll ? 'Deselect All' : 'Select All',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<CartService>(
        builder: (context, cartService, child) {
          return _isLoading
              ? const Center(child: CircularProgressIndicator())
              : cartService.cartItems.isEmpty
                  ? _buildEmptyCart()
                  : _buildCartWithItems(cartService);
        },
      ),
      bottomNavigationBar: Consumer<CartService>(
        builder: (context, cartService, child) {
          return cartService.cartItems.isEmpty
              ? const SizedBox.shrink()
              : _buildCheckoutBar();
        },
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/buyer-browse');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Start Shopping',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartWithItems(CartService cartService) {
    final regularItems =
        cartService.cartItems.where((item) => !item.isReservation).toList();
    final reservationItems =
        cartService.cartItems.where((item) => item.isReservation).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          if (regularItems.isNotEmpty) ...[
            Container(
              color: Colors.white,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.store, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Regular Purchase',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              child: Column(
                children: regularItems
                    .map((item) => _buildCartItemTile(item, cartService))
                    .toList(),
              ),
            ),
          ],

          if (reservationItems.isNotEmpty) ...[
            Container(
              color: Colors.white,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.event_available, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Reservations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              child: Column(
                children: reservationItems
                    .map((item) => _buildCartItemTile(item, cartService))
                    .toList(),
              ),
            ),
          ],

          const SizedBox(height: 120), // Space for bottom bar
        ],
      ),
    );
  }

  Widget _buildCartItemTile(CartItem item, CartService cartService) {
    final bool isSelected = _selectedItems.contains(item.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox for selection
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedItems.remove(item.id);
                      _selectAll = false;
                    } else {
                      _selectedItems.add(item.id);
                      if (_selectedItems.length ==
                          cartService.cartItems.length) {
                        _selectAll = true;
                      }
                    }
                  });
                },
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange : Colors.white,
                    border: Border.all(
                      color: isSelected ? Colors.orange : Colors.grey.shade400,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            ),

            // Product image - clickable
            GestureDetector(
              onTap: () => _navigateToProductDetails(item.productId),
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Colors.orange),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 30,
                                color: Colors.grey[400],
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.shopping_basket,
                          size: 35,
                          color: Colors.grey[400],
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Product details - clickable
            Expanded(
              child: GestureDetector(
                onTap: () => _navigateToProductDetails(item.productId),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name and delete button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.productName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () => _showRemoveItemDialog(item, cartService),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Fetch and display seller name
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(item.sellerId)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final sellerData =
                              snapshot.data!.data() as Map<String, dynamic>;

                          // Get seller name - prioritize full name, then first name
                          String sellerName = 'Unknown Seller';

                          if (sellerData['firstName'] != null &&
                              sellerData['lastName'] != null) {
                            sellerName =
                                '${sellerData['firstName']} ${sellerData['lastName']}';
                          } else if (sellerData['firstName'] != null) {
                            sellerName = sellerData['firstName'];
                          } else if (sellerData['name'] != null) {
                            sellerName = sellerData['name'];
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(Icons.store,
                                    size: 12, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Seller: $sellerName',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    // Fetch and display category
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('products')
                          .doc(item.productId)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final productData =
                              snapshot.data!.data() as Map<String, dynamic>;
                          final category = productData['category'] ?? '';
                          final currentStock = productData['currentStock'] ?? 0;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category badge
                              if (category.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                        color: Colors.green.shade200, width: 1),
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),

                              // Stock availability
                              Row(
                                children: [
                                  Icon(
                                    currentStock > 10
                                        ? Icons.check_circle
                                        : currentStock > 0
                                            ? Icons.warning
                                            : Icons.cancel,
                                    size: 12,
                                    color: currentStock > 10
                                        ? Colors.green
                                        : currentStock > 0
                                            ? Colors.orange
                                            : Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    currentStock > 10
                                        ? 'In Stock'
                                        : currentStock > 0
                                            ? 'Low Stock ($currentStock left)'
                                            : 'Out of Stock',
                                    style: TextStyle(
                                      color: currentStock > 10
                                          ? Colors.green.shade700
                                          : currentStock > 0
                                              ? Colors.orange.shade700
                                              : Colors.red.shade700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    const SizedBox(height: 6),

                    // Reservation badge if applicable
                    if (item.isReservation && item.pickupDate != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border:
                              Border.all(color: Colors.blue.shade200, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_available,
                                size: 12, color: Colors.blue.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'Pickup: ${DateFormat('MMM dd').format(item.pickupDate!)}',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Price with unit info
                    Row(
                      children: [
                        Text(
                          '₱${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange,
                          ),
                        ),
                        Text(
                          ' / ${item.unit}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Quantity selector and total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Quantity selector
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () {
                                  if (item.quantity > 1) {
                                    cartService.updateQuantity(
                                        item.id, item.quantity - 1);
                                    setState(() {});
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: item.quantity > 1
                                        ? Colors.grey.shade100
                                        : Colors.grey.shade50,
                                  ),
                                  child: Icon(
                                    Icons.remove,
                                    size: 16,
                                    color: item.quantity > 1
                                        ? Colors.black87
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              Container(
                                constraints: const BoxConstraints(minWidth: 32),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  '${item.quantity}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  cartService.updateQuantity(
                                      item.id, item.quantity + 1);
                                  setState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    size: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Item subtotal
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Subtotal',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '₱${(item.price * item.quantity).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
  }

  // Show a confirmation dialog when removing an item from cart
  Future<void> _showRemoveItemDialog(
      CartItem item, CartService cartService) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap a button to close dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Item'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'Are you sure you want to remove ${item.productName} from your cart?'),
                const SizedBox(height: 8),
                Text(
                  'Quantity to return to stock: ${item.quantity} ${item.unit}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Remove'),
              onPressed: () async {
                await cartService.removeItem(item.id);
                Navigator.of(context).pop();
                setState(() {}); // Refresh UI

                // Show a snackbar confirmation
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Removed ${item.productName} from cart. Stock has been restored.',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildCheckoutBar() {
    return Consumer<CartService>(
      builder: (context, cartService, child) {
        // Calculate selected items total
        double selectedTotal = 0;
        int selectedCount = 0;
        for (var item in cartService.cartItems) {
          if (_selectedItems.contains(item.id)) {
            selectedTotal += item.price * item.quantity;
            selectedCount++;
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                spreadRadius: 0,
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  // Select All checkbox
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectAll = !_selectAll;
                        if (_selectAll) {
                          _selectedItems = cartService.cartItems
                              .map((item) => item.id)
                              .toSet();
                        } else {
                          _selectedItems.clear();
                        }
                      });
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _selectAll ? Colors.orange : Colors.white,
                            border: Border.all(
                              color: _selectAll
                                  ? Colors.orange
                                  : Colors.grey.shade400,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: _selectAll
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'All',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Total section
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '₱',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            Text(
                              selectedTotal.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        if (selectedCount > 0)
                          Text(
                            '$selectedCount item${selectedCount > 1 ? 's' : ''} selected',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Checkout button
                  ElevatedButton(
                    onPressed: _selectedItems.isEmpty
                        ? null
                        : () => _processCheckout(cartService),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade500,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Checkout${_selectedItems.isNotEmpty ? ' ($selectedCount)' : ''}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _processCheckout(CartService cartService) async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to continue with checkout'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    // Check if any items are selected
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select items to checkout'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Navigate to cart checkout screen where delivery and payment options will be handled
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartCheckoutScreen(
          selectedItemIds: _selectedItems,
        ),
      ),
    );
  }
}
