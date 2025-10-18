import 'package:cloud_firestore/cloud_firestore.dart';

class GCashPaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // GCash merchant details (Replace with your actual GCash details)
  static const String merchantName = 'Cooperative E-Commerce';
  static const String gcashNumber = '09123456789'; // Replace with actual number
  static const String gcashAccountName = 'Cooperative Store'; // Replace with actual name

  /// Create a payment record in Firestore
  Future<String> createPayment({
    required String orderId,
    required String userId,
    required double amount,
    required Map<String, dynamic> orderDetails,
  }) async {
    try {
      final paymentId = 'gcash_${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.collection('gcash_payments').doc(paymentId).set({
        'id': paymentId,
        'orderId': orderId,
        'userId': userId,
        'amount': amount,
        'status': 'pending', // pending, verified, failed
        'merchantName': merchantName,
        'gcashNumber': gcashNumber,
        'gcashAccountName': gcashAccountName,
        'createdAt': FieldValue.serverTimestamp(),
        'orderDetails': orderDetails,
        'referenceNumber': null,
        'proofOfPayment': null,
        'verifiedAt': null,
        'verifiedBy': null,
      });

      return paymentId;
    } catch (e) {
      print('Error creating GCash payment: $e');
      rethrow;
    }
  }

  /// Update payment with reference number
  Future<void> updatePaymentReference({
    required String paymentId,
    required String referenceNumber,
    String? proofOfPayment,
  }) async {
    try {
      await _firestore.collection('gcash_payments').doc(paymentId).update({
        'referenceNumber': referenceNumber,
        'proofOfPayment': proofOfPayment,
        'status': 'pending_verification',
        'submittedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating payment reference: $e');
      rethrow;
    }
  }

  /// Verify payment (Admin/Seller function)
  Future<void> verifyPayment({
    required String paymentId,
    required String verifiedBy,
    required bool isVerified,
  }) async {
    try {
      await _firestore.collection('gcash_payments').doc(paymentId).update({
        'status': isVerified ? 'verified' : 'failed',
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': verifiedBy,
      });

      // Update corresponding order status
      final paymentDoc =
          await _firestore.collection('gcash_payments').doc(paymentId).get();
      if (paymentDoc.exists) {
        final orderId = paymentDoc.data()?['orderId'];
        if (orderId != null) {
          await _firestore.collection('orders').doc(orderId).update({
            'paymentStatus': isVerified ? 'paid' : 'payment_failed',
            'paymentVerifiedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error verifying payment: $e');
      rethrow;
    }
  }

  /// Get payment details
  Future<Map<String, dynamic>?> getPayment(String paymentId) async {
    try {
      final doc =
          await _firestore.collection('gcash_payments').doc(paymentId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting payment: $e');
      return null;
    }
  }

  /// Get payments by order ID
  Future<List<Map<String, dynamic>>> getPaymentsByOrderId(
      String orderId) async {
    try {
      final snapshot = await _firestore
          .collection('gcash_payments')
          .where('orderId', isEqualTo: orderId)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting payments by order: $e');
      return [];
    }
  }

  /// Get payments by user ID
  Future<List<Map<String, dynamic>>> getPaymentsByUserId(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('gcash_payments')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting payments by user: $e');
      return [];
    }
  }
}
