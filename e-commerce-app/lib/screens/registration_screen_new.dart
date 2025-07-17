import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Form controllers
  final _fullNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _barangayController = TextEditingController();
  final _municipalityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _vegetableListController = TextEditingController();
  final _gcashNumberController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _farmDescriptionController = TextEditingController();

  // Product types
  bool _fruits = false;
  bool _vegetables = false;
  bool _grains = false;
  bool _dairy = false;
  bool _other = false;

  // Agreement checkboxes
  bool _agreeToTerms = false;
  bool _agreeToPrivacy = false;

  // Image handling
  final ImagePicker _picker = ImagePicker();
  File? _governmentIdImage;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fillCurrentUserInfo();
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

  @override
  void dispose() {
    _fullNameController.dispose();
    _contactNumberController.dispose();
    _barangayController.dispose();
    _municipalityController.dispose();
    _provinceController.dispose();
    _vegetableListController.dispose();
    _gcashNumberController.dispose();
    _businessNameController.dispose();
    _farmDescriptionController.dispose();
    super.dispose();
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
        SnackBar(content: Text('Error picking image: $e')),
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

    // Check if at least one product type is selected
    if (!_fruits && !_vegetables && !_grains && !_dairy && !_other) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one product type')),
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

      // Collect product types
      List<String> productTypes = [];
      if (_fruits) productTypes.add('Fruits');
      if (_vegetables) productTypes.add('Vegetables');
      if (_grains) productTypes.add('Grains');
      if (_dairy) productTypes.add('Dairy');
      if (_other) productTypes.add('Other');

      // Upload government ID
      String? governmentIdUrl = await _uploadGovernmentId(sellerId);

      if (governmentIdUrl == null) {
        throw Exception('Failed to upload government ID');
      }

      // Create a seller document in Firestore with detailed information
      await _firestore.collection('sellers').doc(sellerId).set({
        'id': sellerId,
        'fullName': _fullNameController.text.trim(),
        'contactNumber': _contactNumberController.text.trim(),
        'address': {
          'barangay': _barangayController.text.trim(),
          'municipality': _municipalityController.text.trim(),
          'province': _provinceController.text.trim(),
          'fullAddress':
              '${_barangayController.text.trim()}, ${_municipalityController.text.trim()}, ${_provinceController.text.trim()}',
        },
        'vegetableList': _vegetableListController.text.trim(),
        'payoutInfo': {
          'gcashNumber': _gcashNumberController.text.trim(),
          'method': 'GCash',
        },
        'businessName': _businessNameController.text.trim(),
        'email': userEmail,
        'farmDescription': _farmDescriptionController.text.trim(),
        'productTypes': productTypes,
        'governmentIdUrl': governmentIdUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending', // Changed to pending for verification
        'verified': false,
        'userId': currentUser.uid,
        'documentsVerified': false,
        'termsAccepted': true,
        'privacyAccepted': true,
      });

      // Update the user's role to seller in the users collection
      await _firestore.collection('users').doc(currentUser.uid).update({
        'role': 'seller',
        'status': 'pending', // Set to pending until verification
        'sellerApplicationDate': FieldValue.serverTimestamp(),
      });

      // Send notification to admin about new seller application
      await _firestore.collection('admin_notifications').add({
        'title': 'New Seller Application',
        'message':
            'A new seller application from ${_fullNameController.text.trim()} requires verification.',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'seller_application',
        'read': false,
        'userId': currentUser.uid,
        'sellerId': sellerId,
        'priority': 'high',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Application submitted successfully! Please wait for admin verification.'),
            duration: Duration(seconds: 3),
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
          SnackBar(content: Text('An error occurred: ${e.toString()}')),
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
        title: const Text('Seller Registration'),
        backgroundColor: Colors.green,
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
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),

                // Full Name
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name*',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Business Name
                TextFormField(
                  controller: _businessNameController,
                  decoration: const InputDecoration(
                    labelText: 'Farm/Business Name*',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your farm/business name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Contact Number
                TextFormField(
                  controller: _contactNumberController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact Number*',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your contact number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Address Section
                const Text(
                  'Address Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),

                // Barangay
                TextFormField(
                  controller: _barangayController,
                  decoration: const InputDecoration(
                    labelText: 'Barangay*',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your barangay';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Municipality
                TextFormField(
                  controller: _municipalityController,
                  decoration: const InputDecoration(
                    labelText: 'Municipality*',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your municipality';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Province
                TextFormField(
                  controller: _provinceController,
                  decoration: const InputDecoration(
                    labelText: 'Province*',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your province';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Vegetables to Sell Section
                const Text(
                  'Vegetables to Sell',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _vegetableListController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'List of Vegetables*',
                    hintText: 'e.g., Tomatoes, Carrots, Lettuce, Onions...',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please list the vegetables you plan to sell';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Payout Information Section
                const Text(
                  'Payout Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),

                // GCash Number
                TextFormField(
                  controller: _gcashNumberController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'GCash Number*',
                    hintText: '09XXXXXXXXX',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                const SizedBox(height: 24),

                // Product Types Section
                const Text(
                  'Product Types',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select all that apply:',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),

                // Checkboxes for product types
                CheckboxListTile(
                  title: const Text('Fruits'),
                  value: _fruits,
                  onChanged: (value) {
                    setState(() {
                      _fruits = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  title: const Text('Vegetables'),
                  value: _vegetables,
                  onChanged: (value) {
                    setState(() {
                      _vegetables = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  title: const Text('Grains'),
                  value: _grains,
                  onChanged: (value) {
                    setState(() {
                      _grains = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  title: const Text('Dairy'),
                  value: _dairy,
                  onChanged: (value) {
                    setState(() {
                      _dairy = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  title: const Text('Other'),
                  value: _other,
                  onChanged: (value) {
                    setState(() {
                      _other = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 24),

                // Government ID Upload Section
                const Text(
                  'Government-issued ID',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload a clear photo of your government-issued ID (required for verification)',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),

                // Government ID upload button
                Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
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
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                size: 40,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tap to upload Government ID*',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 24),

                // Farm Description
                const Text(
                  'Farm Description',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _farmDescriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Tell us about your farm and products (optional)',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),

                // Terms and Conditions Section
                const Text(
                  'Terms and Conditions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),

                // Terms and Conditions Checkbox
                CheckboxListTile(
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
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),

                // Privacy Policy Checkbox
                CheckboxListTile(
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
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 32),

                // Register Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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
