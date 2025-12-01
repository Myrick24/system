import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_manager.dart';

class CartItem {
  final String id;
  final String productId;
  final String sellerId;
  final String productName;
  final double price;
  final int quantity;
  final String unit;
  final bool isReservation;
  final DateTime? pickupDate;
  final String? imageUrl;

  CartItem({
    required this.id,
    required this.productId,
    required this.sellerId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.unit,
    required this.isReservation,
    this.pickupDate,
    this.imageUrl,
  });
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'sellerId': sellerId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'unit': unit,
      'isReservation': isReservation,
      'pickupDate': pickupDate?.toIso8601String(),
      'addedAt': DateTime.now().toIso8601String(),
      'imageUrl': imageUrl,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    DateTime? pickupDate;
    if (map['pickupDate'] != null) {
      try {
        pickupDate = DateTime.parse(map['pickupDate']);
      } catch (_) {}
    }

    return CartItem(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      sellerId: map['sellerId'] ?? '',
      productName: map['productName'] ?? '',
      price: (map['price'] is int)
          ? (map['price'] as int).toDouble()
          : (map['price'] as double),
      quantity: map['quantity'] ?? 1,
      unit: map['unit'] ?? '',
      isReservation: map['isReservation'] ?? false,
      pickupDate: pickupDate,
      imageUrl: map['imageUrl'],
    );
  }
}

class CartService extends ChangeNotifier {
  // Singleton pattern
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<CartItem> _cartItems = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CartItem> get cartItems => _cartItems;
  int get itemCount => _cartItems.length;

  double get totalPrice {
    double total = 0;
    for (var item in _cartItems) {
      total += item.price * item.quantity;
    }
    return total;
  }

  // Check if adding the item would exceed available stock
  Future<bool> checkStock(String productId, int quantity) async {
    try {
      final productDoc =
          await _firestore.collection('products').doc(productId).get();
      if (!productDoc.exists) return false;

      final productData = productDoc.data()!;
      double currentStock = productData['currentStock'] is int
          ? (productData['currentStock'] as int).toDouble()
          : productData['currentStock'] as double;

      // Check if existing cart items already contain this product
      int existingQuantity = 0;
      for (var item in _cartItems) {
        if (item.productId == productId && !item.isReservation) {
          existingQuantity += item.quantity;
        }
      }

      // Return true if there's enough stock (current stock ≥ requested quantity + existing quantity)
      return currentStock >= (quantity + existingQuantity);
    } catch (e) {
      print('Error checking stock: $e');
      return false;
    }
  }

  // Add item to cart and temporarily hold the stock
  Future<bool> addItem(CartItem item) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not authenticated');
        return false;
      }

      // Skip stock check for reservation items
      if (!item.isReservation) {
        // Check if there's enough stock
        bool hasStock = await checkStock(item.productId, item.quantity);
        if (!hasStock) {
          return false;
        }

        // Update the stock in database temporarily (this will be reflected in UI)
        await _firestore.collection('products').doc(item.productId).update({
          'currentStock': FieldValue.increment(-item.quantity),
        });
      }

      // Check if the item already exists in cart
      final existingIndex = _cartItems.indexWhere((cartItem) =>
          cartItem.productId == item.productId &&
          cartItem.isReservation == item.isReservation);

      if (existingIndex >= 0) {
        // Update quantity of existing item
        final existingItem = _cartItems[existingIndex];
        final updatedItem = CartItem(
          id: existingItem.id,
          productId: existingItem.productId,
          sellerId: existingItem.sellerId,
          productName: existingItem.productName,
          price: existingItem.price,
          quantity: existingItem.quantity + item.quantity,
          unit: existingItem.unit,
          isReservation: existingItem.isReservation,
          pickupDate: item.isReservation ? item.pickupDate : null,
          imageUrl: existingItem.imageUrl,
        );
        _cartItems[existingIndex] = updatedItem;
      } else {
        // Add new item
        _cartItems.add(item);
      }

      // Save cart to database
      await saveCartToDatabase(user.uid);

      notifyListeners();
      return true;
    } catch (e) {
      print('Error adding item to cart: $e');
      return false;
    }
  }

  // Remove item from cart and return the stock to inventory
  Future<void> removeItem(String id) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not authenticated');
        return;
      }

      final index = _cartItems.indexWhere((item) => item.id == id);
      if (index >= 0) {
        final item = _cartItems[index];

        // Only update stock for regular purchases, not reservations
        if (!item.isReservation) {
          // Return the stock to the product
          await _firestore.collection('products').doc(item.productId).update({
            'currentStock': FieldValue.increment(item.quantity),
          });
        }

        _cartItems.removeAt(index);

        // Save cart to database
        await saveCartToDatabase(user.uid);

        notifyListeners();
      }
    } catch (e) {
      print('Error removing item from cart: $e');
    }
  }

  // Update item quantity and adjust stock accordingly
  Future<void> updateQuantity(String id, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeItem(id);
      return;
    }

    final index = _cartItems.indexWhere((item) => item.id == id);
    if (index >= 0) {
      final item = _cartItems[index];

      // Skip stock updates for reservations
      if (!item.isReservation) {
        // Calculate the difference in quantity
        final quantityDiff = newQuantity - item.quantity;

        if (quantityDiff != 0) {
          // Check if increasing and there's enough stock
          if (quantityDiff > 0) {
            final productDoc = await _firestore
                .collection('products')
                .doc(item.productId)
                .get();
            if (!productDoc.exists) return;

            final currentStock = productDoc.data()?['currentStock'] is int
                ? (productDoc.data()?['currentStock'] as int).toDouble()
                : productDoc.data()?['currentStock'] as double;

            if (currentStock < quantityDiff) {
              // Not enough stock to increase
              return;
            }
          }

          // Update the stock in database
          await _firestore.collection('products').doc(item.productId).update({
            'currentStock': FieldValue.increment(-quantityDiff),
          });
        }
      }

      // Update the item in the cart
      final updatedItem = CartItem(
        id: item.id,
        productId: item.productId,
        sellerId: item.sellerId,
        productName: item.productName,
        price: item.price,
        quantity: newQuantity,
        unit: item.unit,
        isReservation: item.isReservation,
        pickupDate: item.pickupDate,
        imageUrl: item.imageUrl,
      );

      _cartItems[index] = updatedItem;

      // Save cart to database
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await saveCartToDatabase(user.uid);
      }

      notifyListeners();
    }
  }

  // Clear cart and return all stock to inventory
  Future<void> clearCart() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not authenticated');
        return;
      }

      // Return all non-reservation items to inventory
      for (final item in _cartItems) {
        if (!item.isReservation) {
          await _firestore.collection('products').doc(item.productId).update({
            'currentStock': FieldValue.increment(item.quantity),
          });
        }
      }

      _cartItems.clear();

      // Save empty cart to database
      await saveCartToDatabase(user.uid);

      notifyListeners();
    } catch (e) {
      print('Error clearing cart: $e');
    }
  }

  // Method to save cart items to database for a specific user
  Future<void> saveCartToDatabase(String userId) async {
    try {
      // Delete existing cart items for the user
      await _firestore
          .collection('user_carts')
          .doc(userId)
          .collection('cart_items')
          .get()
          .then((snapshot) {
        for (DocumentSnapshot doc in snapshot.docs) {
          doc.reference.delete();
        }
      });

      // Add all current cart items
      for (CartItem item in _cartItems) {
        await _firestore
            .collection('user_carts')
            .doc(userId)
            .collection('cart_items')
            .doc(item.id)
            .set(item.toMap());
      }
    } catch (e) {
      print('Error saving cart to database: $e');
    }
  }

  // Load cart from database for a specific user
  Future<void> loadCartFromDatabase(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('user_carts')
          .doc(userId)
          .collection('cart_items')
          .get();

      _cartItems.clear();

      for (final doc in snapshot.docs) {
        _cartItems.add(CartItem.fromMap(doc.data()));
      }

      notifyListeners();
    } catch (e) {
      print('Error loading cart from database: $e');
    }
  }

  // Process all items in cart - either purchase or reserve
  Future<bool> processCart(
    String userId, {
    required String paymentMethod,
    required String deliveryMethod,
    String? meetupLocation,
    String? deliveryAddress,
  }) async {
    try {
      print('Starting checkout process for user: $userId');
      print('Cart items: ${_cartItems.length} items total');

      final batch = _firestore.batch();
      final orderTime = DateTime.now();

      // Fetch cooperative pickup location if delivery method is "Pickup at Coop"
      // We'll get the location from each product's seller's cooperative
      Map<String, String> productCoopLocations = {};
      if (deliveryMethod == 'Pickup at Coop') {
        try {
          // Get cooperative location for each product based on seller's cooperative
          for (final item in _cartItems) {
            if (!productCoopLocations.containsKey(item.productId)) {
              // Get the product to find its seller
              final productDoc = await _firestore
                  .collection('products')
                  .doc(item.productId)
                  .get();

              if (productDoc.exists) {
                final productData = productDoc.data() as Map<String, dynamic>;
                final sellerId = productData['sellerId'] as String?;

                if (sellerId != null) {
                  // Get the seller document to find their cooperative ID
                  final sellerDoc =
                      await _firestore.collection('users').doc(sellerId).get();

                  if (sellerDoc.exists) {
                    final sellerData = sellerDoc.data() as Map<String, dynamic>;
                    final cooperativeId =
                        sellerData['cooperativeId'] as String?;

                    if (cooperativeId != null) {
                      // Get the cooperative's location
                      final coopDoc = await _firestore
                          .collection('users')
                          .doc(cooperativeId)
                          .get();

                      if (coopDoc.exists) {
                        final coopData = coopDoc.data() as Map<String, dynamic>;
                        final location = coopData['location'] as String?;
                        if (location != null && location.isNotEmpty) {
                          productCoopLocations[item.productId] = location;
                          print(
                              'Found cooperative location from seller for ${item.productName}: $location');
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          print('Error fetching cooperative locations: $e');
        }
      }

      // Create separate transactions for purchases and reservations
      final purchaseItems =
          _cartItems.where((item) => !item.isReservation).toList();
      final reservationItems =
          _cartItems.where((item) => item.isReservation).toList();

      print(
          'Regular purchase items: ${purchaseItems.length}, Reservation items: ${reservationItems.length}');

      // Process regular purchases
      if (purchaseItems.isNotEmpty) {
        // Group items by seller to send one notification per seller
        Map<String, List<CartItem>> itemsBySeller = {};
        for (final item in purchaseItems) {
          if (!itemsBySeller.containsKey(item.sellerId)) {
            itemsBySeller[item.sellerId] = [];
          }
          itemsBySeller[item.sellerId]!.add(item);
        }

        // For each item, create an individual order for better tracking
        for (final item in purchaseItems) {
          final orderId =
              'order_${orderTime.millisecondsSinceEpoch}_${item.productId}';
          print(
              'Creating order with ID: $orderId for product: ${item.productName}');

          // First, get current user info
          User? currentUser = FirebaseAuth.instance.currentUser;
          Map<String, dynamic> userData = {};

          if (currentUser != null) {
            try {
              DocumentSnapshot userDoc = await _firestore
                  .collection('users')
                  .doc(currentUser.uid)
                  .get();
              if (userDoc.exists) {
                userData = userDoc.data() as Map<String, dynamic>;
              }
            } catch (e) {
              print('Error loading user data: $e');
            }
          }

          // Calculate delivery fee (50 pesos only for Cooperative Delivery)
          final double deliveryFee =
              deliveryMethod == 'Cooperative Delivery' ? 50.0 : 0.0;
          final double subtotal = item.price * item.quantity;
          final double totalWithDelivery = subtotal + deliveryFee;

          print('DEBUG: Delivery Method: $deliveryMethod');
          print('DEBUG: Delivery Fee: $deliveryFee');
          print('DEBUG: Subtotal: $subtotal');
          print('DEBUG: Total: $totalWithDelivery');

          final orderRef = _firestore.collection('orders').doc(orderId);
          final orderData = {
            'id': orderId,
            'buyerId': userId,
            'userId':
                userId, // Add userId for backward compatibility and rule matching
            'subtotal': subtotal,
            'deliveryFee': deliveryFee,
            'totalAmount': totalWithDelivery,
            'status': 'pending',
            'paymentMethod': paymentMethod,
            'deliveryMethod': deliveryMethod,
            'timestamp': FieldValue.serverTimestamp(),
            // Include product details directly in the order
            'productId': item.productId,
            'productName': item.productName,
            'price': item.price,
            'quantity': item.quantity,
            'unit': item.unit,
            'sellerId': item.sellerId,
            'productImage': item.imageUrl ?? '',
            // Add meet-up location if delivery method is Meet-up
            if (deliveryMethod == 'Meet-up' &&
                meetupLocation != null &&
                meetupLocation.isNotEmpty)
              'meetupLocation': meetupLocation,
            // Add delivery address if delivery method is Cooperative Delivery
            if (deliveryMethod == 'Cooperative Delivery' &&
                deliveryAddress != null &&
                deliveryAddress.isNotEmpty)
              'deliveryAddress': deliveryAddress,
            // Add pickup location if delivery method is Pickup at Coop
            if (deliveryMethod == 'Pickup at Coop' &&
                productCoopLocations.containsKey(item.productId))
              'pickupLocation': productCoopLocations[item.productId],
            // Add customer info
            'customerName': userData['name'] ??
                userData['fullName'] ??
                currentUser?.displayName ??
                'Customer',
            'userEmail': currentUser?.email,
            'customerContact': userData['phone'] ??
                userData['phoneNumber'] ??
                'No contact information',
          };

          print('Order data: $orderData');
          batch.set(orderRef, orderData);

          // Store order items details in subcollection for reference
          final orderItemRef = orderRef.collection('items').doc(item.id);
          batch.set(orderItemRef, item.toMap());

          // Add reference to the order document
          final productOrderRef = _firestore
              .collection('product_orders')
              .doc(item.productId)
              .collection('orders')
              .doc(orderId);

          batch.set(productOrderRef, {
            'orderId': orderId,
            'sellerId': item.sellerId,
            'productId': item.productId,
            'quantity': item.quantity,
            'timestamp': FieldValue.serverTimestamp(),
          });

          // Update the actual product quantity in the database
          // This permanently reduces the total product quantity, not just the currentStock
          final productRef =
              _firestore.collection('products').doc(item.productId);
          batch.update(productRef, {
            'quantity': FieldValue.increment(-item.quantity),
            // Ensure currentStock matches the new quantity
            'currentStock': FieldValue.increment(-item.quantity),
          });
        }

        // Create ONE notification per seller (grouped)
        for (final sellerId in itemsBySeller.keys) {
          final sellerItems = itemsBySeller[sellerId]!;
          final firstItem = sellerItems.first;

          // Get user info for the notification
          User? currentUser = FirebaseAuth.instance.currentUser;
          String customerName = 'Customer';

          if (currentUser != null) {
            try {
              DocumentSnapshot userDoc = await _firestore
                  .collection('users')
                  .doc(currentUser.uid)
                  .get();
              if (userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>;
                customerName =
                    userData['name'] ?? userData['fullName'] ?? 'Customer';
              }
            } catch (e) {
              print('Error loading user data for notification: $e');
            }
          }

          // Build notification message
          String notificationBody;
          if (sellerItems.length == 1) {
            final item = sellerItems.first;
            notificationBody =
                '$customerName ordered ${item.quantity} ${item.unit} of ${item.productName}';
          } else {
            notificationBody =
                '$customerName ordered ${sellerItems.length} items from you';
          }

          // Create notification for the seller (ONE per seller)
          final sellerNotificationRef =
              _firestore.collection('notifications').doc();
          batch.set(sellerNotificationRef, {
            'userId': sellerId,
            'title': '🛒 New Order Received',
            'body': notificationBody,
            'message': notificationBody,
            'type': 'new_order',
            'orderId':
                'order_${orderTime.millisecondsSinceEpoch}_${firstItem.productId}', // Reference first order
            'productId': firstItem.productId,
            'productName': sellerItems.length == 1
                ? firstItem.productName
                : '${sellerItems.length} products',
            'productImage': firstItem.imageUrl ?? '',
            'quantity': sellerItems.fold<double>(
                0, (total, item) => total + item.quantity),
            'itemCount': sellerItems.length,
            'totalAmount': sellerItems.fold<double>(
                0, (total, item) => total + (item.price * item.quantity)),
            'customerName': customerName,
            'paymentMethod': paymentMethod,
            'deliveryMethod': deliveryMethod,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });

          // Notify the cooperative where the seller is registered
          try {
            final sellerDoc =
                await _firestore.collection('users').doc(sellerId).get();
            if (sellerDoc.exists) {
              final sellerData = sellerDoc.data() as Map<String, dynamic>;
              final cooperativeId = sellerData['cooperativeId'] as String?;
              final sellerName =
                  sellerData['name'] ?? sellerData['fullName'] ?? 'Seller';

              if (cooperativeId != null && cooperativeId.isNotEmpty) {
                String coopNotificationBody;
                if (sellerItems.length == 1) {
                  coopNotificationBody =
                      '$customerName ordered ${sellerItems[0].quantity} ${sellerItems[0].unit} of ${sellerItems[0].productName} from $sellerName';
                } else {
                  coopNotificationBody =
                      '$customerName ordered ${sellerItems.length} items from $sellerName';
                }

                final coopNotificationRef =
                    _firestore.collection('cooperative_notifications').doc();
                batch.set(coopNotificationRef, {
                  'userId': cooperativeId,
                  'cooperativeId': cooperativeId,
                  'title': '📦 New Transaction Alert',
                  'body': coopNotificationBody,
                  'message': coopNotificationBody,
                  'type': 'cooperative_order',
                  'orderId':
                      'order_${orderTime.millisecondsSinceEpoch}_${firstItem.productId}',
                  'sellerId': sellerId,
                  'sellerName': sellerName,
                  'productId': firstItem.productId,
                  'productName': sellerItems.length == 1
                      ? firstItem.productName
                      : '${sellerItems.length} products',
                  'productImage': firstItem.imageUrl ?? '',
                  'quantity': sellerItems.fold<double>(
                      0, (total, item) => total + item.quantity),
                  'itemCount': sellerItems.length,
                  'totalAmount': sellerItems.fold<double>(
                      0, (total, item) => total + (item.price * item.quantity)),
                  'customerName': customerName,
                  'paymentMethod': paymentMethod,
                  'deliveryMethod': deliveryMethod,
                  'read': false,
                  'createdAt': FieldValue.serverTimestamp(),
                  'timestamp': FieldValue.serverTimestamp(),
                });
                print('✅ Cooperative notification created for: $cooperativeId');
              }
            }
          } catch (e) {
            print('⚠️ Error creating cooperative notification: $e');
            // Continue with order processing even if cooperative notification fails
          }
        }
      }

      // Process reservations
      if (reservationItems.isNotEmpty) {
        // For each item create an individual reservation
        for (final item in reservationItems) {
          final reservationId =
              'reservation_${orderTime.millisecondsSinceEpoch}_${item.productId}';
          print(
              'Creating reservation with ID: $reservationId for product: ${item.productName}');

          // Create reservation document with embedded product details
          final reservationRef =
              _firestore.collection('reservations').doc(reservationId);
          batch.set(reservationRef, {
            'id': reservationId,
            'userId': userId,
            'totalAmount': item.price * item.quantity,
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
            // Include product details directly in the reservation
            'productId': item.productId,
            'productName': item.productName,
            'price': item.price,
            'quantity': item.quantity,
            'unit': item.unit,
            'sellerId': item.sellerId,
            'pickupDate': item.pickupDate?.toIso8601String(),
          });

          // Store reservation items in subcollection for reference
          final reservationItemRef =
              reservationRef.collection('items').doc(item.id);
          batch.set(reservationItemRef, item.toMap());

          // Create notification for the seller
          final notificationId =
              'notification_${DateTime.now().millisecondsSinceEpoch}_${item.sellerId}';
          final notificationRef =
              _firestore.collection('seller_notifications').doc(notificationId);
          batch.set(notificationRef, {
            'id': notificationId,
            'sellerId': item.sellerId,
            'reservationId': reservationId,
            'productId': item.productId,
            'productName': item.productName,
            'quantity': item.quantity,
            'totalAmount': item.price * item.quantity,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'unread',
            'type': 'new_reservation',
            'pickupDate': item.pickupDate?.toIso8601String(),
            'message':
                'New reservation for ${item.productName} (${item.quantity} ${item.unit})',
          });

          // Update product reserved count
          final productRef =
              _firestore.collection('products').doc(item.productId);
          batch.update(productRef, {
            'reserved': FieldValue.increment(item.quantity),
          });
        }
      }

      // Execute the batch
      print('Committing batch write to Firestore...');
      await batch.commit();
      print('Batch committed successfully');

      // Send order confirmation notifications
      try {
        // Get current user info for buyer name
        User? currentUser = FirebaseAuth.instance.currentUser;
        String buyerName = 'Customer';

        if (currentUser != null) {
          try {
            DocumentSnapshot userDoc =
                await _firestore.collection('users').doc(currentUser.uid).get();
            if (userDoc.exists) {
              Map<String, dynamic> userData =
                  userDoc.data() as Map<String, dynamic>;
              buyerName =
                  userData['name'] ?? userData['fullName'] ?? 'Customer';
            }
          } catch (e) {
            print('Error loading user name: $e');
          }
        }

        // Buyer notifications removed - buyers don't need notifications for their own orders
        // Notification is already created in batch above with title "🛒 New Order Received" for sellers only

        // Send notifications for each reservation made
        for (final item in reservationItems) {
          final reservationId =
              'reservation_${orderTime.millisecondsSinceEpoch}_${item.productId}';

          // Notify buyer about reservation confirmation
          await NotificationManager.sendOrderUpdateNotification(
            userId: userId,
            orderId: reservationId,
            status: 'reservation confirmed',
            customerName: null,
          );

          // Notify seller about new reservation
          await NotificationManager.sendOrderUpdateNotification(
            userId: item.sellerId,
            orderId: reservationId,
            status: 'new reservation received',
            customerName: buyerName,
          );
        }
      } catch (e) {
        print('Error sending order notifications: $e');
      }

      // Clear the cart after successful processing
      await clearCart();

      return true;
    } catch (e) {
      print('Error processing cart: $e');
      return false;
    }
  }
}
