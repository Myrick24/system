import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current user
  static User? get currentUser => _auth.currentUser;

  /// Check if user is logged in
  static bool get isLoggedIn => _auth.currentUser != null;

  /// Get current user's role from Firestore
  static Future<String?> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['role'] as String?;
      }
    } catch (e) {
      print('Error getting user role: $e');
    }
    return null;
  }

  /// Check if current user is a seller and if they're approved
  static Future<Map<String, dynamic>> getSellerStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'isSeller': false, 'isApproved': false};
    }

    try {
      // Check if user is registered as a seller
      final sellerQuery = await _firestore
          .collection('sellers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (sellerQuery.docs.isNotEmpty) {
        final sellerData = sellerQuery.docs.first.data();
        String status = sellerData['status'] ?? 'approved';

        return {
          'isSeller': true,
          'isApproved': status == 'active' || status == 'approved',
          'status': status,
          'sellerData': sellerData
        };
      }
    } catch (e) {
      print('Error checking seller status: $e');
    }

    return {'isSeller': false, 'isApproved': false};
  }

  /// Get the appropriate home screen based on user role
  static Future<String> getHomeRoute() async {
    if (!isLoggedIn) {
      return '/guest'; // Guest screen
    }

    final userRole = await getCurrentUserRole();

    switch (userRole) {
      case 'admin':
        return '/admin';
      case 'seller':
        // Check seller approval status
        final sellerStatus = await getSellerStatus();
        if (sellerStatus['isSeller'] == true) {
          return '/unified'; // Unified dashboard for sellers
        }
        return '/unified'; // Default to unified dashboard
      case 'buyer':
      case 'cooperative':
      default:
        return '/unified'; // Unified dashboard for buyers, cooperatives, and default
    }
  }

  /// Check if user should be redirected based on authentication status
  static Future<bool> shouldRedirect() async {
    return isLoggedIn;
  }

  /// Get user display information
  static Future<Map<String, dynamic>?> getUserInfo() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return {
          'uid': user.uid,
          'email': user.email,
          'name': userData['name'] ?? user.displayName ?? 'User',
          'role': userData['role'] ?? 'buyer',
          'createdAt': userData['createdAt'],
        };
      }
    } catch (e) {
      print('Error getting user info: $e');
    }
    return null;
  }

  /// Sign out current user
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      throw e;
    }
  }

  /// Listen to authentication state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
}
