import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../widgets/philippine_address_form.dart';
import '../theme/app_theme.dart';
import 'buyer/buyer_main_dashboard.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  bool _agreeToPrivacy = false;
  // Agreement checkboxes
  bool _agreeToTerms = false;

  final _auth = FirebaseAuth.instance;
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  // Form controllers
  final _fullNameController = TextEditingController();

  File? _governmentIdImage;
  String?
      _existingGovernmentIdUrl; // Store existing government ID URL for editing
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  // Image handling
  final ImagePicker _picker = ImagePicker();

  // Address information using the new Philippine address form
  Map<String, String> _selectedAddress = {};

  final _sitioController = TextEditingController();
  final _vegetableListController = TextEditingController();

  // Cooperative selection
  List<Map<String, dynamic>> _cooperatives = [];
  String? _selectedCoopId;
  String? _selectedCoopName;
  bool _loadingCoops = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _contactNumberController.dispose();
    _vegetableListController.dispose();
    _sitioController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fillCurrentUserInfo();
    // Load cooperatives with a small delay to ensure widget is mounted
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _loadCooperatives();
      }
    });
  }

  // Load available cooperatives
  Future<void> _loadCooperatives() async {
    if (!mounted) return;

    setState(() {
      _loadingCoops = true;
    });

    try {
      print('🔍 Loading cooperatives from Firestore...');
      print('📱 Current user: ${_auth.currentUser?.email ?? "NOT LOGGED IN"}');

      // Query for users with role='cooperative' (single where to avoid composite index)
      final coopsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'cooperative')
          .get();

      print(
          '📊 Found ${coopsSnapshot.docs.length} users with role=cooperative');

      if (coopsSnapshot.docs.isEmpty) {
        print('⚠️  No users found with role="cooperative"');
        print('   Possible issues:');
        print('   1. No cooperatives created in Firestore');
        print('   2. Cooperatives have different role value');
        print('   3. Firestore security rules blocking query');
      }

      // Filter for active cooperatives in-memory
      final activeCoops = coopsSnapshot.docs.where((doc) {
        final data = doc.data();
        final status = data['status'] as String?;
        final name = data['name'] ?? 'Unknown';
        print('   • Cooperative: $name | Status: "$status" | ID: ${doc.id}');
        return status == 'active' || status == null || status.isEmpty;
      }).toList();

      print('✅ ${activeCoops.length} active cooperatives ready to use');

      if (mounted) {
        setState(() {
          _cooperatives = activeCoops.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Unnamed Cooperative',
              'email': data['email'] ?? '',
            };
          }).toList();
          _loadingCoops = false;
        });
      }
    } catch (e) {
      print('❌ Error loading cooperatives: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _loadingCoops = false;
        });
      }
    }
  }

  Future<void> _fillCurrentUserInfo() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      // Get user info from Firestore
      try {
        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _fullNameController.text = userData['name'] ?? '';
            _emailController.text =
                userData['email'] ?? currentUser.email ?? '';
          });

          // Load seller data if user is a registered seller
          if (userData['role'] == 'seller' ||
              userData.containsKey('sellerId')) {
            await _loadSellerApplicationData(currentUser.uid);
          }
        } else {
          // If no user document exists, use Firebase Auth email
          setState(() {
            _emailController.text = currentUser.email ?? '';
          });
        }
      } catch (e) {
        print('Error fetching user data: $e');
        // Fallback to Firebase Auth email
        setState(() {
          _emailController.text = currentUser.email ?? '';
        });
      }
    }
  }

  // Load existing seller application data for editing
  Future<void> _loadSellerApplicationData(String userId) async {
    try {
      print('📋 Loading seller application data for editing...');

      // Query sellers collection by userId
      final sellerDocs = await _firestore
          .collection('sellers')
          .where('userId', isEqualTo: userId)
          .get();

      if (sellerDocs.docs.isNotEmpty) {
        final sellerData = sellerDocs.docs.first.data();
        print('✅ Found seller data: ${sellerData['fullName']}');

        setState(() {
          // Fill personal information
          _fullNameController.text = sellerData['fullName'] ?? '';
          _contactNumberController.text = sellerData['contactNumber'] ?? '';
          _vegetableListController.text = sellerData['vegetableList'] ?? '';
          _sitioController.text = sellerData['sitio'] ?? '';

          // Fill address information (including barangay)
          if (sellerData['address'] != null) {
            final address = sellerData['address'] as Map<String, dynamic>;
            _selectedAddress = {
              'region': address['region'] ?? '',
              'province': address['province'] ?? '',
              'city': address['city'] ?? '',
              'barangay': address['barangay'] ?? '',
            };
            print('📍 Address loaded: $_selectedAddress');
          }

          // Store existing government ID URL
          if (sellerData['governmentIdUrl'] != null) {
            _existingGovernmentIdUrl = sellerData['governmentIdUrl'];
            print('🆔 Government ID URL stored: $_existingGovernmentIdUrl');
          }

          // Set cooperative selection
          if (sellerData['cooperativeId'] != null) {
            _selectedCoopId = sellerData['cooperativeId'];
            print('🏢 Cooperative ID: $_selectedCoopId');
          }

          // Set agreement checkboxes to true (already accepted in previous submission)
          _agreeToTerms = true;
          _agreeToPrivacy = true;
        });
      } else {
        print('⚠️  No seller application found for this user');
      }
    } catch (e) {
      print('Error loading seller application data: $e');
    }
  }

  // Helper method to build section title
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: AppTheme.primaryGreen,
      ),
    );
  }

  // Helper method to build section content
  Widget _buildSectionContent(String content) {
    return Text(
      content,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade700,
        height: 1.6,
      ),
    );
  }

  // Show Terms and Conditions Dialog
  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    '🌾',
                    style: TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Terms and Conditions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last Updated: October 2025',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade100,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to HARVEST, a mobile platform that connects farmers, cooperatives, and buyers for easier and fair agricultural trading. By using this app, you agree to follow the rules and responsibilities written below. Please read them carefully.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle('1. Account Registration and Approval'),
                    _buildSectionContent(
                        'Farmers who want to sell their products must apply as a seller and be approved by their cooperative. Cooperatives are responsible for verifying the identity and details of each farmer or seller. Users must provide true and complete information during registration. Any false data may result in account suspension.'),
                    const SizedBox(height: 12),
                    _buildSectionTitle('2. Product Listing and Sales'),
                    _buildSectionContent(
                        'Sellers must post accurate information about their products (name, price, quantity, date of harvest, etc.). HARVEST and the cooperative have the right to review, edit, or remove any product listing that violates platform policies. Prices and stock availability are managed by the seller, under cooperative supervision.'),
                    const SizedBox(height: 12),
                    _buildSectionTitle('3. Orders and Deliveries'),
                    _buildSectionContent(
                        'Buyers can place orders through the app. Cooperatives handle order coordination and delivery to ensure products are delivered properly. Sellers must prepare the products on time based on the order and delivery schedule. Delivery information (buyer name, address, contact) is shared only with the assigned cooperative and delivery personnel.'),
                    const SizedBox(height: 12),
                    _buildSectionTitle('4. Payments'),
                    _buildSectionContent(
                        'Payments will be processed based on the cooperative\'s chosen method (cash, bank transfer, e-wallet, etc.). HARVEST is not responsible for any payment dispute between sellers, buyers, and cooperatives. Sellers must confirm receipt of payment before marking an order as completed.'),
                    const SizedBox(height: 12),
                    _buildSectionTitle('5. Account Suspension or Termination'),
                    _buildSectionContent(
                        'The cooperative or admin may suspend or deactivate any account that violates the app\'s policies, provides false information, or misuses the platform. Repeated violations may result in permanent account termination.'),
                    const SizedBox(height: 12),
                    _buildSectionTitle('6. Responsibility of Users'),
                    _buildSectionContent(
                        'All users must use the app honestly and respectfully. Users must not post inappropriate, illegal, or misleading content. HARVEST has the right to update these terms without prior notice.'),
                    const SizedBox(height: 12),
                    _buildSectionTitle('7. Limitation of Liability'),
                    _buildSectionContent(
                        'HARVEST serves as a platform only and is not directly involved in the sale or delivery of products. The cooperative and sellers are responsible for ensuring product quality and delivery accuracy.'),
                  ],
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'I Understand',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show Data Privacy Policy Dialog
  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    '🔒',
                    style: TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Data Privacy Policy',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last Updated: October 2025',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade100,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HARVEST respects your privacy and is committed to protecting your personal information in line with the Data Privacy Act of 2012 (RA 10173) of the Philippines.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle('1. Information We Collect'),
                    _buildSectionContent(
                        'We may collect the following data: Full name, contact number, and address; Farm and cooperative details; Product listings and transaction records; Uploaded IDs or verification documents; Payment and delivery information.'),
                    const SizedBox(height: 12),
                    _buildSectionTitle('2. How We Use Your Information'),
                    _buildSectionContent(
                        'Your data will only be used for the following purposes: Account registration and verification; Cooperative approval and coordination; Order processing and delivery; Communication between farmers, buyers, and cooperatives; Improving app services and security.'),
                    const SizedBox(height: 12),
                    _buildSectionTitle('3. Data Sharing'),
                    _buildSectionContent(
                        'Your information will only be shared with your cooperative and authorized delivery partners for transaction purposes. HARVEST does not sell or share your data with any third-party company without your consent.'),
                    const SizedBox(height: 12),
                    _buildSectionTitle('4. Data Protection'),
                    _buildSectionContent(
                        'We apply security measures to protect your data from unauthorized access, loss, or misuse. Only authorized personnel and cooperative representatives can view your account details.'),
                    const SizedBox(height: 12),
                    _buildSectionTitle('5. User Rights'),
                    _buildSectionContent(
                        'You have the right to: Access and review your personal information; Request correction of inaccurate data; Withdraw your consent or request account deletion.'),
                    const SizedBox(height: 12),
                    _buildSectionTitle('6. Policy Updates'),
                    _buildSectionContent(
                        'We may update this policy to improve our services. Any changes will be posted in the app.'),
                    const SizedBox(height: 12),
                    _buildSectionTitle('7. Contact Us'),
                    _buildSectionContent(
                        'If you have questions or concerns about your data, you can contact your cooperative representative or the HARVEST support team.'),
                  ],
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'I Understand',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Function to pick government ID image
  Future<void> _pickGovernmentId() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        setState(() {
          _governmentIdImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Function to upload image to Firebase Storage
  Future<String?> _uploadGovernmentId(String sellerId) async {
    if (_governmentIdImage == null) return null;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('seller_documents')
          .child(sellerId)
          .child('government_id.jpg');

      await ref.putFile(_governmentIdImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading government ID: $e');
      return null;
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if address is selected using the new structure
    if (_selectedAddress['region'] == null ||
        _selectedAddress['region']!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your complete address'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    // Check if cooperative is selected
    if (_selectedCoopId == null || _selectedCoopId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please select a cooperative to handle your application'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    // Check agreements
    if (!_agreeToTerms || !_agreeToPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please agree to terms and conditions and data privacy policy')),
      );
      return;
    }

    // Check if government ID is uploaded (optional if already has existing ID for editing)
    if (_governmentIdImage == null && _existingGovernmentIdUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please upload your government-issued ID')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      User? currentUser = _auth.currentUser;

      // If no user is logged in, create a new account
      if (currentUser == null) {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        // Validate password fields
        if (password.isEmpty) {
          throw Exception('Please enter a password');
        }
        if (password != _confirmPasswordController.text.trim()) {
          throw Exception('Passwords do not match');
        }

        // Create new user account
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        currentUser = userCredential.user;

        if (currentUser == null) {
          throw Exception('Failed to create account');
        }

        // Create user document in Firestore
        await _firestore.collection('users').doc(currentUser.uid).set({
          'name': _fullNameController.text.trim(),
          'email': email,
          'role':
              'buyer', // Initially set as buyer, will be updated when seller approved
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Generate a unique seller ID (or use existing one for editing)
      String sellerId;
      bool isEditing = false;

      // Check if this is an edit (user already has a seller application)
      if (_existingGovernmentIdUrl != null || _governmentIdImage != null) {
        // Try to find existing seller document
        final existingDocs = await _firestore
            .collection('sellers')
            .where('userId', isEqualTo: currentUser.uid)
            .get();

        if (existingDocs.docs.isNotEmpty) {
          sellerId = existingDocs.docs.first.id;
          isEditing = true;
          print('📝 Editing existing seller application with ID: $sellerId');
        } else {
          sellerId = _firestore.collection('sellers').doc().id;
          print('📝 Creating new seller application with ID: $sellerId');
        }
      } else {
        sellerId = _firestore.collection('sellers').doc().id;
        print('📝 Creating new seller application with ID: $sellerId');
      }

      String userEmail = _emailController.text.trim();

      // Upload government ID (or use existing one)
      String? governmentIdUrl;
      if (_governmentIdImage != null) {
        // New image selected, upload it
        governmentIdUrl = await _uploadGovernmentId(sellerId);
      } else if (_existingGovernmentIdUrl != null) {
        // Use existing image URL
        governmentIdUrl = _existingGovernmentIdUrl;
      }

      if (governmentIdUrl == null) {
        throw Exception('Failed to process government ID');
      }

      // Build full address string from the new structure
      List<String> addressParts = [];
      if (_sitioController.text.trim().isNotEmpty) {
        addressParts.add(_sitioController.text.trim());
      }
      if (_selectedAddress['barangay'] != null &&
          _selectedAddress['barangay']!.isNotEmpty) {
        addressParts.add(_selectedAddress['barangay']!);
      }
      if (_selectedAddress['city'] != null &&
          _selectedAddress['city']!.isNotEmpty) {
        addressParts.add(_selectedAddress['city']!);
      }
      if (_selectedAddress['province'] != null &&
          _selectedAddress['province']!.isNotEmpty) {
        addressParts.add(_selectedAddress['province']!);
      }
      String fullAddress = addressParts.join(', ');

      // Prepare seller data for create
      final sellerDataForCreate = {
        'id': sellerId,
        'fullName': _fullNameController.text.trim(),
        'contactNumber': _contactNumberController.text.trim(),
        'address': {
          'region': _selectedAddress['region'] ?? '',
          'province': _selectedAddress['province'] ?? '',
          'city': _selectedAddress['city'] ?? '',
          'barangay': _selectedAddress['barangay'] ?? '',
          'sitio': _sitioController.text.trim(),
          'fullAddress': fullAddress,
        },
        'vegetableList': _vegetableListController.text.trim(),
        'email': userEmail,
        'governmentIdUrl': governmentIdUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'verified': false,
        'userId': currentUser.uid,
        'documentsVerified': false,
        'termsAccepted': true,
        'privacyAccepted': true,
        'cooperativeId': _selectedCoopId,
        'cooperativeName': _selectedCoopName,
      };

      // For editing, only update fields that can be changed
      final sellerDataForUpdate = {
        'fullName': _fullNameController.text.trim(),
        'contactNumber': _contactNumberController.text.trim(),
        'address': {
          'region': _selectedAddress['region'] ?? '',
          'province': _selectedAddress['province'] ?? '',
          'city': _selectedAddress['city'] ?? '',
          'barangay': _selectedAddress['barangay'] ?? '',
          'sitio': _sitioController.text.trim(),
          'fullAddress': fullAddress,
        },
        'vegetableList': _vegetableListController.text.trim(),
        'email': userEmail,
        'governmentIdUrl': governmentIdUrl,
        'termsAccepted': true,
        'privacyAccepted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Create or update seller document
      if (isEditing) {
        // Update existing seller application (only changeable fields)
        await _firestore
            .collection('sellers')
            .doc(sellerId)
            .update(sellerDataForUpdate);
        print('✅ Seller application updated successfully');
      } else {
        // Create new seller document
        await _firestore
            .collection('sellers')
            .doc(sellerId)
            .set(sellerDataForCreate);
        print('✅ New seller application created successfully');
      }

      // Update the user's role to seller in the users collection
      // Use set with merge to handle case where user document might not exist
      await _firestore.collection('users').doc(currentUser.uid).set({
        'name': _fullNameController.text
            .trim(), // Use the name from the form instead of displayName
        'email': currentUser.email ?? '',
        'role': 'seller',
        'status': 'pending', // Set to pending until verification
        'sellerApplicationDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'cooperativeId': _selectedCoopId, // Link seller to cooperative
      }, SetOptions(merge: true));

      // Send notification to selected cooperative only for new applications
      if (!isEditing) {
        await _sendSellerApplicationNotification(
          _selectedCoopId!,
          _fullNameController.text.trim(),
          userEmail,
          sellerId,
        );
      } else {
        print('📝 Application edit - notification not sent');
      }

      if (mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  Text(
                    isEditing
                        ? 'Application Updated!'
                        : 'Application Submitted!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Message
                  Text(
                    isEditing
                        ? '✅ Your application has been updated successfully.\n\nThe cooperative will review your changes.'
                        : '✅ Your application has been sent to $_selectedCoopName for approval.\n\nYou can still browse the marketplace while waiting.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext); // Close dialog
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BuyerMainDashboard(),
                          ),
                          (route) => false, // Remove all previous routes
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      print('Error during registration: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            duration: const Duration(seconds: 5),
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

  // Send notification to cooperative about new seller application
  Future<void> _sendSellerApplicationNotification(
    String cooperativeUserId,
    String applicantName,
    String applicantEmail,
    String sellerId,
  ) async {
    try {
      print(
          '📤 Sending seller application notification to cooperative: $cooperativeUserId');

      // Get the cooperative user document to verify it exists
      final coopUserDoc =
          await _firestore.collection('users').doc(cooperativeUserId).get();

      if (!coopUserDoc.exists) {
        print(
            '⚠️  Warning: Cooperative user not found with ID: $cooperativeUserId');
        return;
      }

      final coopUserData = coopUserDoc.data() as Map<String, dynamic>;
      final cooperativeName = coopUserData['name'] ?? 'Cooperative';
      final userRole = coopUserData['role'] ?? '';

      if (userRole != 'cooperative' && userRole != 'admin') {
        print(
            '⚠️  Warning: User $cooperativeUserId is not a cooperative (role: $userRole)');
        return;
      }

      print(
          '✅ Creating notification for cooperative: $cooperativeName ($cooperativeUserId)');

      // Create notification record for the cooperative user using 'notifications' collection
      // This matches the product notification pattern
      final notificationData = {
        'userId': cooperativeUserId,
        'title': 'New Seller Application',
        'body': '$applicantName has submitted a new seller application.',
        'payload': 'seller_application',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'seller_application',
        'cooperativeId': cooperativeUserId,
        'priority': 'high',
        'applicantName': applicantName,
        'applicantEmail': applicantEmail,
        'sellerId': sellerId,
      };

      // Add notification to 'notifications' collection (same as products)
      await _firestore.collection('notifications').add(notificationData);

      print(
          '✅ Successfully created notification for cooperative: $cooperativeName');

      // Also notify staff members linked to this cooperative
      final staffQuery = await _firestore
          .collection('users')
          .where('cooperativeId', isEqualTo: cooperativeUserId)
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
                '📤 Creating notification for staff member: $staffName ($staffUserId)');

            final staffNotificationData = {
              'userId': staffUserId,
              'title': 'New Seller Application',
              'body': '$applicantName has submitted a new seller application.',
              'payload': 'seller_application',
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
              'type': 'seller_application',
              'cooperativeId': cooperativeUserId,
              'priority': 'high',
              'applicantName': applicantName,
              'applicantEmail': applicantEmail,
              'sellerId': sellerId,
            };

            await _firestore
                .collection('notifications')
                .add(staffNotificationData);

            print('✅ Successfully created notification for staff: $staffName');
          } catch (e) {
            print('❌ Error creating notification for staff ${staffDoc.id}: $e');
          }
        }
      } else {
        print('ℹ️  No additional staff members found for this cooperative');
      }

      print(
          '✅ Seller application notification process complete for cooperative $cooperativeUserId');
    } catch (e) {
      print('❌ Error sending seller application notification: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  // Function to build a nicely formatted address display
  String _buildSelectedAddressDisplay() {
    List<String> addressParts = [];

    if (_selectedAddress['barangay'] != null &&
        _selectedAddress['barangay']!.isNotEmpty) {
      addressParts.add('Brgy. ${_selectedAddress['barangay']}');
    }
    if (_selectedAddress['city'] != null &&
        _selectedAddress['city']!.isNotEmpty) {
      addressParts.add(_selectedAddress['city']!);
    }
    if (_selectedAddress['province'] != null &&
        _selectedAddress['province']!.isNotEmpty) {
      addressParts.add(_selectedAddress['province']!);
    }
    if (_selectedAddress['region'] != null &&
        _selectedAddress['region']!.isNotEmpty) {
      addressParts.add(_selectedAddress['region']!);
    }

    return addressParts.isNotEmpty
        ? addressParts.join(', ')
        : 'No address selected';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Registration'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join our community of farmers and sell your products directly to buyers.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),

                // Personal Information Section
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.primaryGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        color: AppTheme.primaryGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Personal Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.primaryGreenDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Full Name
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name*',
                      prefixIcon:
                          Icon(Icons.person, color: Colors.grey.shade600),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      labelStyle: TextStyle(color: Colors.grey.shade700),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Email Address
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address*',
                      prefixIcon:
                          Icon(Icons.email, color: Colors.grey.shade600),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      labelStyle: TextStyle(color: Colors.grey.shade700),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email address';
                      }
                      // Basic email validation
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Password fields - only show if no user is logged in
                if (_auth.currentUser == null) ...[
                  // Password
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password*',
                        prefixIcon:
                            Icon(Icons.lock, color: Colors.grey.shade600),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () {
                            setState(() {
                              _passwordVisible = !_passwordVisible;
                            });
                          },
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: !_confirmPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password*',
                        prefixIcon:
                            Icon(Icons.lock, color: Colors.grey.shade600),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _confirmPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () {
                            setState(() {
                              _confirmPasswordVisible =
                                  !_confirmPasswordVisible;
                            });
                          },
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Contact Number
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextFormField(
                    controller: _contactNumberController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Contact Number*',
                      prefixIcon:
                          Icon(Icons.phone, color: Colors.grey.shade600),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      labelStyle: TextStyle(color: Colors.grey.shade700),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your contact number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Philippine Address Form Widget (with integrated styling)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Address Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      PhilippineAddressForm(
                        initialAddress: _selectedAddress.isNotEmpty
                            ? _selectedAddress
                            : null,
                        onAddressSelected: (Map<String, String> address) {
                          setState(() {
                            _selectedAddress = address;
                          });
                        },
                      ),
                      if (_selectedAddress.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade600,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Selected Address:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _buildSelectedAddressDisplay(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Sitio/Purok (Optional) - styled to match the address form
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextFormField(
                    controller: _sitioController,
                    decoration: InputDecoration(
                      labelText: 'Sitio/Purok (Optional)',
                      prefixIcon: Icon(Icons.home, color: Colors.grey.shade600),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      labelStyle: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Vegetables to Sell Section
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.eco,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Vegetables to Sell',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Vegetables to Sell
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextFormField(
                    controller: _vegetableListController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'List of Vegetables*',
                      hintText: 'e.g., Tomatoes, Carrots, Lettuce, Onions...',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: Icon(Icons.eco, color: Colors.grey.shade600),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      labelStyle: TextStyle(color: Colors.grey.shade700),
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please list the vegetables you plan to sell';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Cooperative Selection Section
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.primaryGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.group,
                        color: AppTheme.primaryGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Select Cooperative',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.primaryGreenDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Cooperative Dropdown
                if (_loadingCoops)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Loading cooperatives...'),
                        ],
                      ),
                    ),
                  )
                else if (_cooperatives.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber,
                                color: Colors.orange.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No active cooperatives available. Contact admin to create one.',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadCooperatives,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          child: const Text(
                            'Retry Loading',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 64,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCoopId,
                        decoration: InputDecoration(
                          labelText: 'Choose Cooperative*',
                          prefixIcon:
                              Icon(Icons.business, color: Colors.grey.shade600),
                          border: InputBorder.none,
                          labelStyle: TextStyle(color: Colors.grey.shade700),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                        ),
                        items: _cooperatives.map((coop) {
                          return DropdownMenuItem<String>(
                            value: coop['id'] as String,
                            child: Text(
                              coop['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCoopId = value;
                            // Find the selected cooperative name
                            final selectedCoop = _cooperatives.firstWhere(
                              (coop) => coop['id'] == value,
                              orElse: () => {'name': ''},
                            );
                            _selectedCoopName = selectedCoop['name'] as String?;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a cooperative to handle your application';
                          }
                          return null;
                        },
                        hint: const Text(
                            'Select a cooperative that will handle your products'),
                        isExpanded: true,
                      ),
                    ),
                  ),
                if (_selectedCoopName != null && _selectedCoopName!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.green.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your application will be reviewed by $_selectedCoopName. They will handle your product deliveries and approvals.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                const SizedBox(height: 24),

                // Government ID Upload Section
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.badge,
                            color: Colors.grey.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Government-issued ID',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload a clear photo of your government-issued ID (required for verification)',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Government ID upload button
                      Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.grey.shade400,
                              style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: _governmentIdImage != null
                            ? Stack(
                                children: [
                                  GestureDetector(
                                    onTap: _pickGovernmentId,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _governmentIdImage!,
                                        width: double.infinity,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _governmentIdImage = null;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Tap to change',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : _existingGovernmentIdUrl != null
                                ? Stack(
                                    children: [
                                      GestureDetector(
                                        onTap: _pickGovernmentId,
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            _existingGovernmentIdUrl!,
                                            width: double.infinity,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                width: double.infinity,
                                                height: 120,
                                                color: Colors.grey.shade200,
                                                child: const Center(
                                                  child: Icon(Icons.error),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _existingGovernmentIdUrl = null;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.6),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Current',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.8),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Tap to change',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : InkWell(
                                    onTap: _pickGovernmentId,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.cloud_upload,
                                          size: 40,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap to upload Government ID*',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Terms and Conditions Section
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.primaryGreen.withOpacity(0.3)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.gavel,
                            color: AppTheme.primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Terms and Conditions',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Terms and Conditions Checkbox
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.primaryGreen.withOpacity(0.4),
                              width: 1.5),
                        ),
                        child: CheckboxListTile(
                          title: GestureDetector(
                            onTap: _showTermsDialog,
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms and Conditions',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const TextSpan(text: '*'),
                                ],
                              ),
                            ),
                          ),
                          value: _agreeToTerms,
                          onChanged: (value) {
                            setState(() {
                              _agreeToTerms = value ?? false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          dense: true,
                          activeColor: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Privacy Policy Checkbox
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.primaryGreen.withOpacity(0.4),
                              width: 1.5),
                        ),
                        child: CheckboxListTile(
                          title: GestureDetector(
                            onTap: _showPrivacyDialog,
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Data Privacy Policy',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const TextSpan(text: '*'),
                                ],
                              ),
                            ),
                          ),
                          value: _agreeToPrivacy,
                          onChanged: (value) {
                            setState(() {
                              _agreeToPrivacy = value ?? false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          dense: true,
                          activeColor: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Register Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
