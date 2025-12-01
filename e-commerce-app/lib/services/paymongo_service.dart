import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

/// PayMongo Payment Service
///
/// This service integrates with PayMongo API for GCash payments.
/// PayMongo is a Philippine payment gateway that supports GCash, credit cards, etc.
///
/// Setup Instructions:
/// 1. Sign up at https://paymongo.com
/// 2. Get your API keys from the Dashboard
/// 3. Replace the API keys below with your actual keys
/// 4. Install http package: flutter pub add http
class PayMongoService {
  // ⚠️ IMPORTANT: Replace with your actual PayMongo API keys
  // Get these from: https://dashboard.paymongo.com/developers/api-keys
  // For testing, use TEST keys (starts with pk_test_ and sk_test_)
  // For production, use LIVE keys (starts with pk_live_ and sk_live_)
  // TODO: Move these to environment variables or secure storage
  static const String _publicKey = 'pk_test_4tUiAUKKHASyG6h6VWMLjJhH';
  static const String _secretKey = 'sk_test_KiH6sokR7sk8UnqoMzUHRmHb';

  static const String _baseUrl = 'https://api.paymongo.com/v1';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get authorization header for PayMongo API
  String get _authHeader {
    final credentials = base64Encode(utf8.encode('$_secretKey:'));
    return 'Basic $credentials';
  }

  /// Create a PayMongo Source for GCash payment with deep linking
  ///
  /// This will create a payment source that opens the GCash app directly
  /// (like Shopee, Lazada, etc.)
  ///
  /// Returns a Map containing:
  /// - sourceId: The PayMongo source ID
  /// - checkoutUrl: URL that opens GCash app
  /// - status: Payment status
  Future<Map<String, dynamic>> createGCashSource({
    required double amount,
    required String orderId,
    required String userId,
    required Map<String, dynamic> orderDetails,
  }) async {
    try {
      print('Creating PayMongo GCash source for amount: ₱$amount');
      print('This will open the GCash app on the user\'s phone');

      // Convert amount to centavos (PayMongo uses smallest currency unit)
      final int amountInCentavos = (amount * 100).toInt();

      final response = await http.post(
        Uri.parse('$_baseUrl/sources'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _authHeader,
        },
        body: jsonEncode({
          'data': {
            'attributes': {
              'amount': amountInCentavos,
              'redirect': {
                'success': 'https://your-app.com/payment/success',
                'failed': 'https://your-app.com/payment/failed',
              },
              'type': 'gcash',
              'currency': 'PHP',
              'metadata': {
                'order_id': orderId,
                'user_id': userId,
                'product_name': orderDetails['productName'] ?? '',
                'quantity': orderDetails['quantity']?.toString() ?? '1',
              }
            }
          }
        }),
      );

      print('PayMongo API Response Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final sourceData = data['data'];

        final sourceId = sourceData['id'];
        final checkoutUrl =
            sourceData['attributes']['redirect']['checkout_url'];
        final status = sourceData['attributes']['status'];

        print('GCash source created successfully: $sourceId');

        // Save payment record to Firestore
        await _savePaymentRecord(
          sourceId: sourceId,
          orderId: orderId,
          userId: userId,
          amount: amount,
          checkoutUrl: checkoutUrl,
          status: status,
          orderDetails: orderDetails,
        );

        return {
          'success': true,
          'sourceId': sourceId,
          'checkoutUrl': checkoutUrl,
          'status': status,
          'message': 'GCash payment source created successfully',
        };
      } else {
        print('PayMongo API Error: ${response.body}');
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['errors']?[0]?['detail'] ??
              'Failed to create payment source',
        };
      }
    } catch (e) {
      print('Error creating GCash source: $e');
      return {
        'success': false,
        'error': 'Connection error: ${e.toString()}',
      };
    }
  }

  /// Save payment record to Firestore
  Future<void> _savePaymentRecord({
    required String sourceId,
    required String orderId,
    required String userId,
    required double amount,
    required String checkoutUrl,
    required String status,
    required Map<String, dynamic> orderDetails,
  }) async {
    await _firestore.collection('paymongo_payments').doc(sourceId).set({
      'sourceId': sourceId,
      'orderId': orderId,
      'userId': userId,
      'amount': amount,
      'checkoutUrl': checkoutUrl,
      'status': status,
      'paymentMethod': 'gcash',
      'orderDetails': orderDetails,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Check payment status by source ID
  Future<Map<String, dynamic>> checkPaymentStatus(String sourceId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/sources/$sourceId'),
        headers: {
          'Authorization': _authHeader,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['data']['attributes']['status'];
        final amount = data['data']['attributes']['amount'];

        // Update Firestore record
        await _firestore.collection('paymongo_payments').doc(sourceId).update({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 🔥 CRITICAL FIX: If source is chargeable, create a Payment to record in PayMongo dashboard
        if (status == 'chargeable') {
          print(
              '🔥 Source is chargeable - creating Payment to record transaction');
          print('📊 Amount in centavos: $amount');

          final paymentResult = await createPaymentFromSource(
            sourceId: sourceId,
            amountInCentavos: amount, // Already in centavos from API
          );

          if (paymentResult['success'] == true) {
            print('✅ Payment created successfully in PayMongo dashboard');
            print('💳 Payment ID: ${paymentResult['paymentId']}');
            // Update status to 'paid' after successful payment creation
            await _firestore
                .collection('paymongo_payments')
                .doc(sourceId)
                .update({
              'status': 'paid',
              'paymentId': paymentResult['paymentId'],
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            print('❌ Failed to create payment: ${paymentResult['error']}');
          }
        }

        return {
          'success': true,
          'status': status,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to check payment status',
        };
      }
    } catch (e) {
      print('Error checking payment status: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Create a Payment from a chargeable Source
  /// THIS is what makes the transaction appear in PayMongo dashboard!
  Future<Map<String, dynamic>> createPaymentFromSource({
    required String sourceId,
    required int
        amountInCentavos, // Amount already in centavos from PayMongo API
  }) async {
    try {
      print('💰 Creating Payment from source: $sourceId');
      print(
          '💵 Amount: $amountInCentavos centavos (₱${amountInCentavos / 100})');

      final requestBody = {
        'data': {
          'attributes': {
            'amount': amountInCentavos,
            'source': {
              'id': sourceId,
              'type': 'source',
            },
            'currency': 'PHP',
            'description': 'GCash Payment',
          }
        }
      };

      print('📤 Payment request: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('$_baseUrl/payments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _authHeader,
        },
        body: jsonEncode(requestBody),
      );

      print('📥 Payment creation response: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final paymentId = data['data']['id'];
        final status = data['data']['attributes']['status'];

        print('✅ SUCCESS! Payment created in PayMongo dashboard');
        print('🆔 Payment ID: $paymentId');
        print('📊 Status: $status');

        return {
          'success': true,
          'paymentId': paymentId,
          'status': status,
          'data': data['data'],
        };
      } else {
        print('❌ Payment creation FAILED with status: ${response.statusCode}');
        print('❌ Error response: ${response.body}');

        try {
          final errorData = jsonDecode(response.body);
          final errorMessage =
              errorData['errors']?[0]?['detail'] ?? 'Failed to create payment';
          print('❌ Error detail: $errorMessage');
          return {
            'success': false,
            'error': errorMessage,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to create payment: ${response.body}',
          };
        }
      }
    } catch (e) {
      print('❌ EXCEPTION creating payment from source: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get payment record from Firestore
  Future<Map<String, dynamic>?> getPaymentRecord(String sourceId) async {
    try {
      final doc =
          await _firestore.collection('paymongo_payments').doc(sourceId).get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting payment record: $e');
      return null;
    }
  }

  /// Get payments by order ID
  Future<List<Map<String, dynamic>>> getPaymentsByOrderId(
      String orderId) async {
    try {
      final querySnapshot = await _firestore
          .collection('paymongo_payments')
          .where('orderId', isEqualTo: orderId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error getting payments by order: $e');
      return [];
    }
  }

  /// Get user's payment history
  Future<List<Map<String, dynamic>>> getUserPayments(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('paymongo_payments')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error getting user payments: $e');
      return [];
    }
  }

  /// Create a Payment Intent (for card payments)
  /// This is an alternative method for card payments if needed
  Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    required String orderId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final int amountInCentavos = (amount * 100).toInt();

      final response = await http.post(
        Uri.parse('$_baseUrl/payment_intents'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _authHeader,
        },
        body: jsonEncode({
          'data': {
            'attributes': {
              'amount': amountInCentavos,
              'payment_method_allowed': ['card', 'gcash'],
              'payment_method_options': {
                'card': {'request_three_d_secure': 'any'}
              },
              'currency': 'PHP',
              'description': 'Order #$orderId',
              'statement_descriptor': 'E-commerce App',
              'metadata': metadata ?? {},
            }
          }
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'paymentIntent': data['data'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['errors']?[0]?['detail'] ??
              'Failed to create payment intent',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Attach payment method to payment intent
  Future<Map<String, dynamic>> attachPaymentMethod({
    required String paymentIntentId,
    required String paymentMethodId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/payment_intents/$paymentIntentId/attach'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _authHeader,
        },
        body: jsonEncode({
          'data': {
            'attributes': {
              'payment_method': paymentMethodId,
            }
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'paymentIntent': data['data'],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to attach payment method',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Verify webhook signature (for webhook integration)
  bool verifyWebhookSignature({
    required String payload,
    required String signature,
    required String timestamp,
  }) {
    try {
      // PayMongo webhook verification
      final signatureData = '$timestamp.$payload';
      final expectedSignature = base64Encode(
        utf8.encode(_secretKey + signatureData),
      );

      return signature == expectedSignature;
    } catch (e) {
      print('Error verifying webhook: $e');
      return false;
    }
  }
}
