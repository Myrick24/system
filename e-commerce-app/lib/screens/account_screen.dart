import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'registration_screen.dart';
import 'notifications/account_notifications.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart'; // Import our notification service
import '../theme/app_theme.dart'; // Import the app theme
import 'cooperative/coop_dashboard.dart'; // Import Coop Dashboard
import 'buyer/buyer_main_dashboard.dart'; // Import BuyerOrdersScreen
import 'seller/seller_profile_management.dart'; // Import Seller Profile Management
import 'help_support/help_support_screen.dart'; // Import Help & Support
import 'profile_settings_screen.dart'; // Import Profile Settings Screen

class AccountScreen extends StatefulWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with AutomaticKeepAliveClientMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  String? _userName;
  String? _userPhone;
  String? _userAddress;
  String? _userProfileImage;
  bool _isLoading = true;
  bool _isRegisteredSeller = false;
  bool _isSellerApproved = false; // Flag to track if seller is approved
  bool _isCooperative = false; // Flag to track if user is a cooperative

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Defer heavy operations to prevent blocking UI
    Future.microtask(() {
      _loadNotificationState();
      _getCurrentUser();
    });
  }

  // Load notification state using NotificationService
  // We don't need this method anymore since we're using specific notification keys
  // This is kept as a stub for backward compatibility
  Future<void> _loadNotificationState() async {
    // No implementation needed - we're using specific notification keys now
  }

  Future<void> _getCurrentUser() async {
    setState(() {
      _isLoading = true;
    });

    // Reset notification flag if user changes
    final oldUser = _currentUser;
    _currentUser = _auth.currentUser;

    // If the user changed, reset the notification flag
    if (_currentUser != null &&
        (oldUser == null || oldUser.uid != _currentUser!.uid)) {
      _loadNotificationState(); // Load notification state for the new user
    }

    if (_currentUser != null) {
      try {
        // Force refresh the Firebase Auth token to ensure we have latest permissions
        await _currentUser!.getIdToken(true);

        print('=== DEBUG: Current User Info ===');
        print('User ID: ${_currentUser!.uid}');
        print('User Email: ${_currentUser!.email}');

        // Try to get user data from Firestore
        final userDocRef =
            _firestore.collection('users').doc(_currentUser!.uid);

        try {
          final userDoc = await userDocRef.get();
          if (userDoc.exists) {
            // Get the user data from Firestore
            final userData = userDoc.data();
            if (userData != null) {
              setState(() {
                if (userData.containsKey('name') && userData['name'] != null) {
                  _userName = userData['name'];
                  print(
                      'User name set from users collection: ${userData['name']}');
                }
                // Check both 'phone' and 'mobile' fields
                if (userData.containsKey('phone') &&
                    userData['phone'] != null) {
                  _userPhone = userData['phone'];
                  print('User phone loaded: ${userData['phone']}');
                } else if (userData.containsKey('mobile') &&
                    userData['mobile'] != null) {
                  _userPhone = userData['mobile'];
                  print('User mobile loaded: ${userData['mobile']}');
                }
                // Load address
                if (userData.containsKey('address') &&
                    userData['address'] != null) {
                  // Handle both string and map formats
                  final address = userData['address'];
                  if (address is String) {
                    _userAddress = address;
                  } else if (address is Map) {
                    // If address is stored as a map with fullAddress field
                    _userAddress = address['fullAddress'] ?? address.toString();
                  }
                  print('User address loaded: $_userAddress');
                }
                if (userData.containsKey('profileImage') &&
                    userData['profileImage'] != null) {
                  _userProfileImage = userData['profileImage'];
                }
              });
            } else {
              print('No data found in users collection');
            }

            // Check if user is a cooperative
            if (userData != null && userData['role'] == 'cooperative') {
              setState(() {
                _isCooperative = true;
              });
              print('User is a cooperative member');
            }

            // Check if user is registered as seller from users collection first
            if (userData != null && userData['role'] == 'seller') {
              String userStatus = userData['status'] ?? 'pending';
              bool isApproved = userStatus == 'approved';

              print('User is registered as seller from users collection');
              print('User Status: $userStatus');

              setState(() {
                _isRegisteredSeller = true;
                _isSellerApproved = isApproved;
              });

              // Show status update message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Seller status: ${userStatus.toUpperCase()}'),
                    backgroundColor: isApproved ? Colors.green : Colors.orange,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } else {
              // Check if user is already registered as a seller (fallback to sellers collection)
              try {
                print('=== DEBUG: Searching for seller ===');
                final sellerQuery = await _firestore
                    .collection('sellers')
                    .where('email', isEqualTo: _currentUser!.email)
                    .limit(1)
                    .get();

                print('Seller query result count: ${sellerQuery.docs.length}');

                if (sellerQuery.docs.isNotEmpty) {
                  final sellerDoc = sellerQuery.docs.first;
                  final sellerData = sellerDoc.data();
                  String status = sellerData['status'] ?? 'pending';
                  bool isApproved = status == 'approved';

                  print('Seller found - Email: ${_currentUser!.email}');
                  print('Seller ID: ${sellerDoc.id}');
                  print('Seller Status: $status');
                  print('Is Approved: $isApproved');
                  print('Full seller data: $sellerData');

                  // Set user name from seller data if not already set
                  if (_userName == null &&
                      sellerData.containsKey('name') &&
                      sellerData['name'] != null) {
                    setState(() {
                      _userName = sellerData['name'];
                    });
                    print(
                        'User name set from sellers collection: ${sellerData['name']}');
                  }

                  setState(() {
                    _isRegisteredSeller = true;
                    _isSellerApproved = isApproved;
                  });

                  // Show status update message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Seller status: ${status.toUpperCase()}'),
                        backgroundColor:
                            isApproved ? Colors.green : Colors.orange,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  print('No seller found for email: ${_currentUser!.email}');

                  // Let's also try to search by user ID as a fallback
                  print('=== DEBUG: Trying search by user ID ===');
                  final sellerByUidQuery = await _firestore
                      .collection('sellers')
                      .where('userId', isEqualTo: _currentUser!.uid)
                      .limit(1)
                      .get();

                  print(
                      'Seller by UID query result count: ${sellerByUidQuery.docs.length}');

                  if (sellerByUidQuery.docs.isNotEmpty) {
                    final sellerDoc = sellerByUidQuery.docs.first;
                    final sellerData = sellerDoc.data();
                    String status = sellerData['status'] ?? 'pending';
                    bool isApproved = status == 'approved';

                    print(
                        'Seller found by UID - User ID: ${_currentUser!.uid}');
                    print('Seller ID: ${sellerDoc.id}');
                    print('Seller Status: $status');
                    print('Is Approved: $isApproved');
                    print('Full seller data: $sellerData');

                    // Set user name from seller data if not already set
                    if (_userName == null &&
                        sellerData.containsKey('name') &&
                        sellerData['name'] != null) {
                      setState(() {
                        _userName = sellerData['name'];
                      });
                      print(
                          'User name set from sellers collection (by UID): ${sellerData['name']}');
                    }

                    setState(() {
                      _isRegisteredSeller = true;
                      _isSellerApproved = isApproved;
                    });

                    // Show status update message
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Seller status: ${status.toUpperCase()}'),
                          backgroundColor:
                              isApproved ? Colors.green : Colors.orange,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } else {
                    print('No seller found by email OR user ID');
                    setState(() {
                      _isRegisteredSeller = false;
                      _isSellerApproved = false;
                    });
                  }
                }
              } catch (sellerQueryError) {
                print('Firestore seller query error: $sellerQueryError');
              }
            }
          }
        } catch (error) {
          print('Firestore error: $error');
          // Handle the Firestore permission error based on the memory
        }

        // Final fallback: if no name was found anywhere, try to use Firebase Auth displayName
        if (_userName == null && _currentUser?.displayName != null) {
          setState(() {
            _userName = _currentUser!.displayName;
          });
          print(
              'User name set from Firebase Auth displayName: ${_currentUser!.displayName}');
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Method to show status change notification
  Future<void> _logout() async {
    try {
      await NotificationService.resetNotificationState();
      await AuthService.signOut();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  // Helper method to reset all seller status notification flags
  Future<void> resetAllSellerNotificationFlags() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final userId = _auth.currentUser?.uid;

    if (userId != null) {
      // Remove all specific notification flags for seller status
      await prefs
          .remove('seller_notification_shown_${userId}_seller_status_approved');
      await prefs
          .remove('seller_notification_shown_${userId}_seller_status_changed');
      await prefs
          .remove('seller_notification_shown_${userId}_seller_status_pending');
    }
  }

  // Helper method to send seller application cancellation notification to cooperative
  Future<void> _sendSellerApplicationCancellationNotification(
    String cooperativeId,
    String sellerName,
    String sellerId,
  ) async {
    try {
      print(
          '📤 Sending seller application cancellation notification to cooperative: $cooperativeId');

      // Get the cooperative user document
      final coopUserDoc =
          await _firestore.collection('users').doc(cooperativeId).get();

      if (!coopUserDoc.exists) {
        print(
            '⚠️  Warning: Cooperative user not found with ID: $cooperativeId');
        return;
      }

      final coopUserData = coopUserDoc.data() as Map<String, dynamic>;
      final cooperativeName = coopUserData['name'] ?? 'Cooperative';
      final userRole = coopUserData['role'] ?? '';

      if (userRole != 'cooperative' && userRole != 'admin') {
        print(
            '⚠️  Warning: User $cooperativeId is not a cooperative (role: $userRole)');
        return;
      }

      print(
          '✅ Creating cancellation notification for cooperative: $cooperativeName ($cooperativeId)');

      // Create cancellation notification
      final notificationData = {
        'userId': cooperativeId,
        'title': 'Seller Application Cancelled',
        'body': '$sellerName has cancelled their seller application.',
        'payload': 'seller_application_cancelled',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'seller_application_cancelled',
        'cooperativeId': cooperativeId,
        'priority': 'medium',
        'sellerName': sellerName,
        'sellerId': sellerId,
      };

      // Add notification to 'notifications' collection
      await _firestore.collection('notifications').add(notificationData);

      print(
          '✅ Successfully created cancellation notification for cooperative: $cooperativeName');

      // Also notify staff members linked to this cooperative
      final staffQuery = await _firestore
          .collection('users')
          .where('cooperativeId', isEqualTo: cooperativeId)
          .where('role', isEqualTo: 'cooperative')
          .get();

      if (staffQuery.docs.isNotEmpty) {
        print(
            '👥 Found ${staffQuery.docs.length} staff members linked to this cooperative');

        for (var staffDoc in staffQuery.docs) {
          try {
            String staffUserId = staffDoc.id;
            Map<String, dynamic> staffData = staffDoc.data();
            String staffName = staffData['name'] ?? 'Staff Member';

            print(
                '📤 Creating cancellation notification for staff member: $staffName ($staffUserId)');

            final staffNotificationData = {
              'userId': staffUserId,
              'title': 'Seller Application Cancelled',
              'body': '$sellerName has cancelled their seller application.',
              'payload': 'seller_application_cancelled',
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
              'type': 'seller_application_cancelled',
              'cooperativeId': cooperativeId,
              'priority': 'medium',
              'sellerName': sellerName,
              'sellerId': sellerId,
            };

            await _firestore
                .collection('notifications')
                .add(staffNotificationData);

            print(
                '✅ Successfully created cancellation notification for staff: $staffName');
          } catch (e) {
            print(
                '❌ Error creating cancellation notification for staff ${staffDoc.id}: $e');
          }
        }
      } else {
        print('ℹ️  No additional staff members found for this cooperative');
      }

      print(
          '✅ Seller application cancellation notification process complete for cooperative $cooperativeId');
    } catch (e) {
      print('❌ Error sending seller application cancellation notification: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      );
    }

    // If user is not logged in, show login prompt
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Account'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Please login to view your account',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
    }

    // User is logged in, show account info
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account header with name and email
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.green,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    backgroundImage: _userProfileImage != null
                        ? NetworkImage(_userProfileImage!)
                        : null,
                    child: _userProfileImage == null
                        ? const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.green,
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _userName ?? 'Account Name',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _currentUser?.email ?? 'example@email.com',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Coop Dashboard section for cooperative users
            if (_isCooperative)
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.shade400,
                      Colors.green.shade600,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CoopDashboard(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.business,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Cooperative Dashboard',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Manage deliveries, pickups, and payments for your cooperative',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Become a Seller section (Shopee/Lazada style) - Hidden for cooperative users
            if (!_isRegisteredSeller && !_isCooperative)
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.shade400,
                      Colors.green.shade600,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.store,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Become a Seller',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Start selling your fresh produce and earn money!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Benefits list
                      _buildBenefitItem('📈', 'Reach thousands of customers'),
                      const SizedBox(height: 8),
                      _buildBenefitItem(
                          '💰', 'Earn extra income from your harvest'),
                      const SizedBox(height: 8),
                      _buildBenefitItem(
                          '🚀', 'Easy setup and management tools'),
                      const SizedBox(height: 8),
                      _buildBenefitItem('🛡️', 'Secure payments and support'),
                      const SizedBox(height: 20),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RegistrationScreen(),
                                  ),
                                ).then((result) {
                                  if (result != null &&
                                      result is Map<String, dynamic> &&
                                      result['success'] == true) {
                                    // Refresh user data to get the actual status
                                    _getCurrentUser();
                                  }
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.green.shade600,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.rocket_launch, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Start Selling',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () {
                              _showSellerInfoDialog();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline, size: 18),
                                SizedBox(width: 4),
                                Text('Learn More'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Seller Pending Approval section (for registered but not approved sellers)
            if (_isRegisteredSeller && !_isSellerApproved)
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryGreen,
                      AppTheme.primaryGreen.withOpacity(0.8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.pending_actions,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Seller Application Pending',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'PENDING',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Review by Cooperative',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Status information
                      _buildStatusItem(
                          '📄', 'Application submitted successfully'),
                      const SizedBox(height: 8),
                      _buildStatusItem('🔍', 'Documents under verification'),
                      const SizedBox(height: 8),
                      _buildStatusItem('⏳', 'Waiting for admin approval'),
                      const SizedBox(height: 8),
                      _buildStatusItem('📧', 'We\'ll notify you once approved'),
                      const SizedBox(height: 20),
                      // Info container
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Approval typically takes 1-3 business days. You can continue shopping while waiting.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Action buttons for refreshing status, editing, and canceling
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Refresh the seller status
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Checking application status...'),
                                duration: Duration(seconds: 1),
                              ),
                            );

                            // Clear current status first
                            setState(() {
                              _isLoading = true;
                            });

                            await _getCurrentUser();

                            // Show completion message
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Status check completed'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Check Status'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Edit and Cancel buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                // Navigate to registration screen to edit application
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RegistrationScreen(),
                                  ),
                                );
                                // Refresh status after editing
                                if (result == true && mounted) {
                                  setState(() {
                                    _isLoading = true;
                                  });
                                  await _getCurrentUser();
                                }
                              },
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Edit'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // Show confirmation dialog before canceling
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Cancel Application?'),
                                    content: const Text(
                                      'Are you sure you want to cancel your seller application? This action cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Keep It'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          // Delete seller application
                                          try {
                                            final userId = _currentUser?.uid;
                                            if (userId != null) {
                                              // Get seller data BEFORE deletion to extract cooperativeId
                                              final sellerDocs =
                                                  await _firestore
                                                      .collection('sellers')
                                                      .where('userId',
                                                          isEqualTo: userId)
                                                      .get();

                                              // Extract seller info before deletion
                                              String? cooperativeId;
                                              String? sellerName;

                                              for (var doc in sellerDocs.docs) {
                                                final sellerData = doc.data();
                                                cooperativeId =
                                                    sellerData['cooperativeId'];
                                                sellerName =
                                                    sellerData['storeName'] ??
                                                        'Seller';
                                                String sellerId = doc.id;

                                                // Send cancellation notification to cooperative
                                                if (cooperativeId != null &&
                                                    sellerName != null) {
                                                  await _sendSellerApplicationCancellationNotification(
                                                    cooperativeId,
                                                    sellerName,
                                                    sellerId,
                                                  );
                                                }

                                                // Now delete the seller document
                                                await doc.reference.delete();
                                              }

                                              // Update users collection to remove seller role
                                              await _firestore
                                                  .collection('users')
                                                  .doc(userId)
                                                  .update({
                                                'role': 'customer',
                                                'sellerId': FieldValue.delete(),
                                              });

                                              setState(() {
                                                _isRegisteredSeller = false;
                                                _isSellerApproved = false;
                                              });

                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Application cancelled successfully',
                                                    ),
                                                    duration:
                                                        Duration(seconds: 2),
                                                  ),
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            print(
                                                'Error canceling application: $e');
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Error: ${e.toString()}',
                                                  ),
                                                  duration: const Duration(
                                                      seconds: 2),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        child: const Text(
                                          'Yes, Cancel',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Cancel'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Colors.red,
                                  width: 1.5,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Consolidated Seller Dashboard (for registered sellers)
            if (_isRegisteredSeller && _isSellerApproved)
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryGreenLight,
                      AppTheme.primaryGreenDark,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.store,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Seller Dashboard',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Manage your products, orders, and business',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Quick action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(
                                    context, '/seller-main-dashboard');
                              },
                              icon: const Icon(Icons.dashboard, size: 18),
                              label: const Text('Dashboard'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primaryGreenDark,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/add-product');
                              },
                              icon: const Icon(Icons.add_box, size: 18),
                              label: const Text('Add Product'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primaryGreenDark,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // My Orders banner
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Orders',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track your purchases and order history',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            // Navigate to buyer orders screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BuyerOrdersScreen(
                                    showBackButton: true),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          child: const Text('View Orders'),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      size: 40,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            // Browse Products banner (for buyers)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isRegisteredSeller
                              ? 'Browse & Shop'
                              : 'Browse Products',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRegisteredSeller
                              ? 'Shop from other sellers'
                              : 'Fresh vegetables directly from farmers',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/buyer-browse');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          child: Text(_isRegisteredSeller
                              ? 'Browse Products'
                              : 'Shop Now'),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shopping_bag,
                      size: 40,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),

            // Account Settings section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'ACCOUNT SETTINGS',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Settings options
            _buildSettingsItem(
              icon: Icons.person_outline,
              title: 'Profile Settings',
              onTap: () {
                // Navigate to profile settings - different screens for seller vs buyer
                if (_isRegisteredSeller && _isSellerApproved) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SellerProfileManagement(),
                    ),
                  );
                } else {
                  // For buyers, show a profile editing screen
                  _showProfileDialog();
                }
              },
            ),
            _buildNotificationsSettingsItem(),

            // Only show status update check for registered sellers
            if (_isRegisteredSeller)
              _buildSettingsItem(
                icon: Icons.update,
                title: _isSellerApproved
                    ? 'Seller Status: Approved'
                    : 'Seller Status: Pending',
                onTap: () async {
                  // Reset notification flags to force check
                  await NotificationService.resetNotificationState();

                  // Reset specific notification flags for all status types
                  await resetAllSellerNotificationFlags();

                  // Show loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Checking for status updates...'),
                      duration: Duration(seconds: 1),
                    ),
                  );

                  // Clear current status first to force refresh, but preserve username
                  String? currentUserName =
                      _userName; // Preserve current username
                  setState(() {
                    _isLoading = true;
                    _isRegisteredSeller = false;
                    _isSellerApproved = false;
                    // Don't clear _userName here to preserve it
                  });

                  // Re-fetch user data which will trigger notification checks
                  await _getCurrentUser();

                  // Restore username if it was cleared during refresh
                  if (_userName == null && currentUserName != null) {
                    setState(() {
                      _userName = currentUserName;
                    });
                  }

                  // Notify user with current status
                  if (mounted) {
                    String statusMessage = _isRegisteredSeller
                        ? (_isSellerApproved
                            ? 'Status: APPROVED - You can now access the seller dashboard!'
                            : 'Status: PENDING - Still waiting for admin approval')
                        : 'No seller application found';

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(statusMessage),
                        duration: const Duration(seconds: 3),
                        backgroundColor:
                            _isSellerApproved ? Colors.green : Colors.orange,
                      ),
                    );
                  }
                },
                trailing: _isSellerApproved
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.pending, color: Colors.orange),
              ),
            _buildSettingsItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpSupportScreen(),
                  ),
                );
              },
            ),

            // Logout button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildNotificationsSettingsItem() {
    final user = _auth.currentUser;
    if (user == null) {
      return _buildSettingsItem(
        icon: Icons.notifications,
        title: 'Notifications',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AccountNotifications(),
            ),
          );
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;

        if (snapshot.hasData) {
          unreadCount = snapshot.data?.docs.length ?? 0;
        }

        return ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications, color: Colors.grey),
              if (unreadCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          title: const Text('Notifications'),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AccountNotifications(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBenefitItem(String emoji, String text) {
    return Row(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem(String emoji, String text) {
    return Row(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  void _showProfileDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSettingsScreen(
          userName: _userName,
          userEmail: _currentUser?.email,
          userPhone: _userPhone,
          userAddress: _userAddress,
          userProfileImage: _userProfileImage,
          userId: _currentUser!.uid,
        ),
      ),
    );

    // Update state if profile was updated
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _userName = result['name'];
        _userPhone = result['phone'];
        _userAddress = result['address'];
        _userProfileImage = result['profileImage'];
      });

      // Reload user data to ensure everything is synced
      _getCurrentUser();
    }
  }

  void _showSellerInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.store, color: Colors.green.shade600),
              const SizedBox(width: 8),
              const Text('Become a Seller'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Join our community of verified farmers and start selling your fresh produce directly to customers!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'What you\'ll get:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoBenefitItem('✅', 'Free to start - no setup fees'),
                _buildInfoBenefitItem(
                    '✅', 'Reach customers across the Philippines'),
                _buildInfoBenefitItem(
                    '✅', 'Easy product listing and management'),
                _buildInfoBenefitItem('✅', 'Secure GCash payment processing'),
                _buildInfoBenefitItem('✅', 'Real-time order notifications'),
                _buildInfoBenefitItem('✅', 'Document verification for trust'),
                const SizedBox(height: 16),
                Container(
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
                          Icon(Icons.info_outline,
                              color: Colors.green.shade600, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Requirements:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Valid government-issued ID for verification\n'
                        '• Complete Philippine address (Region, Province, City, Barangay)\n'
                        '• Active GCash account for payments\n'
                        '• Contact number for communication\n'
                        '• List of vegetables you plan to sell\n'
                        '• Admin approval required after document verification',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegistrationScreen(),
                  ),
                ).then((result) {
                  if (result != null &&
                      result is Map<String, dynamic> &&
                      result['success'] == true) {
                    // Refresh user data to get the actual status
                    _getCurrentUser();
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Get Started'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoBenefitItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
