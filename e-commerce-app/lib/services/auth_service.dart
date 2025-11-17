import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'realtime_notification_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for home route to avoid repeated queries
  static String? _cachedHomeRoute;
  static String? _cachedUserId;

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
      _cachedHomeRoute = null;
      _cachedUserId = null;
      return '/guest'; // Guest screen
    }

    final currentUserId = currentUser?.uid;

    // Return cached route if user hasn't changed
    if (_cachedHomeRoute != null && _cachedUserId == currentUserId) {
      return _cachedHomeRoute!;
    }

    // User changed or no cache, fetch fresh data
    final userRole = await getCurrentUserRole();

    String route;
    switch (userRole) {
      case 'admin':
        route = '/admin';
        break;
      case 'seller':
        route = '/unified';
        break;
      case 'buyer':
      case 'cooperative':
      default:
        route =
            '/unified'; // Unified dashboard for buyers, cooperatives, and default
    }

    // Cache the route
    _cachedHomeRoute = route;
    _cachedUserId = currentUserId;

    return route;
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
      // Clear FCM token from Firestore before signing out
      final user = _auth.currentUser;
      if (user != null) {
        try {
          // Delete FCM token from device
          await RealtimeNotificationService.clearFCMToken();

          // Remove FCM token from Firestore
          await _firestore.collection('users').doc(user.uid).set({
            'fcmToken': FieldValue.delete(),
          }, SetOptions(merge: true));
          print('🗑️ FCM token removed from Firestore for user: ${user.uid}');
        } catch (tokenError) {
          print(
              '⚠️ Error removing FCM token (continuing with logout): $tokenError');
          // Continue with logout even if token removal fails
        }
      }

      // Clear cached route
      _cachedHomeRoute = null;
      _cachedUserId = null;
      await _auth.signOut();
      print('✅ User signed out successfully');
    } catch (e) {
      print('Error signing out: $e');
      throw e;
    }
  }

  /// Listen to authentication state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
}
