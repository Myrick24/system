import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/cart_service.dart';
import '../widgets/address_selector.dart';
import 'buyer/buyer_main_dashboard.dart';
import 'paymongo_gcash_screen.dart';

class CartCheckoutScreen extends StatefulWidget {
  final Set<String> selectedItemIds;

  const CartCheckoutScreen({
    Key? key,
    required this.selectedItemIds,
  }) : super(key: key);

  @override
  State<CartCheckoutScreen> createState() => _CartCheckoutScreenState();
}

class _CartCheckoutScreenState extends State<CartCheckoutScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  String? _selectedDeliveryOption = 'Pickup at Coop';
  String? _selectedPaymentOption = 'Cash';
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
    _loadCooperativeLocationFromCart();
  }

  Future<void> _loadCooperativeLocationFromCart() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Get the cart items to find their products
      final cartService = Provider.of<CartService>(context, listen: false);
      final selectedItems = cartService.cartItems
          .where((item) => widget.selectedItemIds.contains(item.id))
          .toList();

      // Try to get pickup location from the first product's seller's cooperative
      if (selectedItems.isNotEmpty) {
        final firstProductId = selectedItems.first.productId;
        final productDoc =
            await _firestore.collection('products').doc(firstProductId).get();

        if (productDoc.exists) {
          final productData = productDoc.data() as Map<String, dynamic>;
          final sellerId = productData['sellerId'] as String?;

          if (sellerId != null) {
            // Get the seller document to find their cooperative ID
            final sellerDoc =
                await _firestore.collection('users').doc(sellerId).get();

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
                  final location = coopData['location'] as String?;
                  setState(() {
                    _coopPickupLocation = location;
                  });
                  print('Found cooperative location from seller: $location');
                  return;
                }
              }
            }
          }
        }
      }

      // Last resort: Query for any cooperative
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

  double _calculateSubtotal(List<CartItem> selectedItems) {
    double subtotal = 0;
    for (var item in selectedItems) {
      subtotal += item.price * item.quantity;
    }
    return subtotal;
  }

  double _getDeliveryFee() {
    // Delivery fee only applies to Cooperative Delivery
    return _selectedDeliveryOption == 'Cooperative Delivery' ? 50.0 : 0.0;
  }

  double _calculateTotal(List<CartItem> selectedItems) {
    return _calculateSubtotal(selectedItems) + _getDeliveryFee();
  }

  Future<void> _placeOrder(
      CartService cartService, List<CartItem> selectedItems) async {
    // Validate delivery address if Cooperative Delivery is selected
    if (_selectedDeliveryOption == 'Cooperative Delivery') {
      if (_deliveryAddress.isEmpty ||
          _deliveryAddress['fullAddress'] == null ||
          _deliveryAddress['fullAddress']!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your delivery address'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('DEBUG: Starting cart checkout...');
      print('DEBUG: Selected delivery option: $_selectedDeliveryOption');
      print('DEBUG: Selected payment option: $_selectedPaymentOption');

      // Process the cart with selected items
      final success = await cartService.processCart(
        _auth.currentUser!.uid,
        paymentMethod: _selectedPaymentOption ?? 'Cash',
        deliveryMethod: _selectedDeliveryOption ?? 'Pickup at Coop',
        meetupLocation: null,
        deliveryAddress: _selectedDeliveryOption == 'Cooperative Delivery'
            ? _deliveryAddress['fullAddress']
            : null,
      );

      if (success) {
        print('DEBUG: Order placed successfully!');

        // If GCash payment is selected
        if (_selectedPaymentOption == 'GCash') {
          if (mounted) {
            final orderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
            final subtotal = _calculateSubtotal(selectedItems);
            final deliveryFee = _getDeliveryFee();
            final totalAmount = _calculateTotal(selectedItems);

            final paymentCompleted = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PayMongoGCashScreen(
                  amount: totalAmount,
                  orderId: orderId,
                  userId: _auth.currentUser!.uid,
                  orderDetails: {
                    'itemCount': selectedItems.length,
                    'subtotal': subtotal,
                    'deliveryFee': deliveryFee,
                    'deliveryMethod': _selectedDeliveryOption,
                    'deliveryAddress':
                        _selectedDeliveryOption == 'Cooperative Delivery'
                            ? _deliveryAddress['fullAddress']
                            : null,
                  },
                ),
              ),
            );

            if (paymentCompleted == true && mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const BuyerOrdersScreen(showBackButton: true),
                ),
              );
            }
          }
        } else {
          // For Cash payment, navigate directly to orders screen
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Order placed successfully!',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const BuyerOrdersScreen(showBackButton: true),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to place order. Please try again.'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('ERROR placing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Consumer<CartService>(
        builder: (context, cartService, child) {
          // Filter selected items
          final selectedItems = cartService.cartItems
              .where((item) => widget.selectedItemIds.contains(item.id))
              .toList();

          if (selectedItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No items selected',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final totalAmount = _calculateTotal(selectedItems);

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selected Items Summary
                  const Text(
                    'Order Items',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: selectedItems.length,
                      separatorBuilder: (context, index) => Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = selectedItems[index];
                        return ListTile(
                          leading:
                              item.imageUrl != null && item.imageUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        item.imageUrl!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Icon(Icons.image_not_supported),
                                      ),
                                    )
                                  : Icon(Icons.shopping_basket),
                          title: Text(
                            item.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${item.quantity} ${item.unit} × ₱${item.price.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            '₱${(item.price * item.quantity).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Delivery Options
                  const Text(
                    'Delivery Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

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

                  // Delivery Address Field
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

                  // Pickup Location
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
                                ? const Text('Loading location...')
                                : Text(
                                    _coopPickupLocation ??
                                        'Cooperative Location',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green.shade900,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Payment Options
                  const Text(
                    'Payment Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Items:'),
                      Text('${selectedItems.length}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Delivery:'),
                      Text(_selectedDeliveryOption ?? ''),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment:'),
                      Text(_selectedPaymentOption ?? ''),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:'),
                      Text(
                          '₱${_calculateSubtotal(selectedItems).toStringAsFixed(2)}'),
                    ],
                  ),
                  if (_selectedDeliveryOption == 'Cooperative Delivery') ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Delivery Fee:'),
                        Text(
                          '₱${_getDeliveryFee().toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '₱${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
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
                          : () => _placeOrder(cartService, selectedItems),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Processing...'),
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
                                    fontWeight: FontWeight.w600,
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
        },
      ),
    );
  }
}
