import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../widgets/philippine_address_form.dart';
import '../theme/app_theme.dart';

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
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  // Form controllers
  final _fullNameController = TextEditingController();

  final _gcashNumberController = TextEditingController();
  File? _governmentIdImage;
  bool _isLoading = false;
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
    _contactNumberController.dispose();
    _vegetableListController.dispose();
    _gcashNumberController.dispose();
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

      print('📊 Found ${coopsSnapshot.docs.length} users with role=cooperative');

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
          });
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    }
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

    // Check if government ID is uploaded
    if (_governmentIdImage == null) {
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
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Generate a unique seller ID
      String sellerId = _firestore.collection('sellers').doc().id;
      String userEmail = currentUser.email ?? '';

      // Upload government ID
      String? governmentIdUrl = await _uploadGovernmentId(sellerId);

      if (governmentIdUrl == null) {
        throw Exception('Failed to upload government ID');
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
      if (_selectedAddress['region'] != null &&
          _selectedAddress['region']!.isNotEmpty) {
        addressParts.add(_selectedAddress['region']!);
      }
      String fullAddress = addressParts.join(', ');

      // Create a seller document in Firestore with detailed information
      await _firestore.collection('sellers').doc(sellerId).set({
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
        'payoutInfo': {
          'gcashNumber': _gcashNumberController.text.trim(),
          'method': 'GCash',
        },
        'email': userEmail,
        'governmentIdUrl': governmentIdUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending', // Changed to pending for cooperative verification
        'verified': false,
        'userId': currentUser.uid,
        'documentsVerified': false,
        'termsAccepted': true,
        'privacyAccepted': true,
        'cooperativeId': _selectedCoopId, // Link to selected cooperative
        'cooperativeName':
            _selectedCoopName, // Store cooperative name for display
      });

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

      // Send notification to selected cooperative about new seller application
      await _firestore.collection('cooperative_notifications').add({
        'title': 'New Seller Application',
        'message':
            'A new seller application from ${_fullNameController.text.trim()} requires your approval.',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'seller_application',
        'read': false,
        'userId': currentUser.uid,
        'sellerId': sellerId,
        'priority': 'high',
        'cooperativeId': _selectedCoopId, // Target specific cooperative
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Application submitted successfully to $_selectedCoopName! Please wait for cooperative approval. Check your account screen for status updates.'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
        // Return to previous screen with a result
        Navigator.pop(context,
            {'success': true, 'sellerId': sellerId, 'status': 'pending'});
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
                const SizedBox(height: 24),

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
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: DropdownButtonFormField<String>(
                      value: _selectedCoopId,
                      decoration: InputDecoration(
                        labelText: 'Choose Cooperative*',
                        prefixIcon:
                            Icon(Icons.business, color: Colors.grey.shade600),
                        border: InputBorder.none,
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                      ),
                      items: _cooperatives.map((coop) {
                        return DropdownMenuItem<String>(
                          value: coop['id'] as String,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                coop['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                coop['email'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
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

                // Payout Information Section
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.payment,
                        color: Colors.purple.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Payout Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.purple.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // GCash Number
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextFormField(
                    controller: _gcashNumberController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'GCash Number*',
                      hintText: '09XXXXXXXXX',
                      prefixIcon: Icon(Icons.account_balance_wallet,
                          color: Colors.grey.shade600),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      labelStyle: TextStyle(color: Colors.grey.shade700),
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your GCash number';
                      }
                      if (!RegExp(r'^09\d{9}$').hasMatch(value)) {
                        return 'Please enter a valid GCash number (09XXXXXXXXX)';
                      }
                      return null;
                    },
                  ),
                ),
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
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _governmentIdImage!,
                                      width: double.infinity,
                                      height: 120,
                                      fit: BoxFit.cover,
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
                                ],
                              )
                            : InkWell(
                                onTap: _pickGovernmentId,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.gavel,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Terms and Conditions',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.orange.shade800,
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
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: CheckboxListTile(
                          title: const Text(
                            'I agree to the Terms and Conditions*',
                            style: TextStyle(fontSize: 14),
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
                          activeColor: Colors.orange.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Privacy Policy Checkbox
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: CheckboxListTile(
                          title: const Text(
                            'I agree to the Data Privacy Policy*',
                            style: TextStyle(fontSize: 14),
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
                          activeColor: Colors.orange.shade600,
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
