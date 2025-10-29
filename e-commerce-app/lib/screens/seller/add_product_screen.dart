import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../services/notification_manager.dart';
import '../../theme/app_theme.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({Key? key}) : super(key: key);

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _estimatedDateController = TextEditingController();

  String _selectedOrderType = 'Available Now';
  String _selectedUnit = 'Kilo (kg)';
  String _selectedCategory = 'Vegetables';
  List<File> _selectedImages = [];
  DateTime? _harvestDate;
  DateTime? _estimatedAvailabilityDate;
  bool _isLoading = false;

  // Cooperative selection
  List<Map<String, dynamic>> _cooperatives = [];
  String? _selectedCoopId;
  String? _selectedCoopName;
  String? _selectedCoopLocation;
  bool _loadingCoops = false;

  // Multiple delivery options - only 2 choices
  final List<String> _deliveryOptions = ['Cooperative Delivery', 'Pick Up'];

  // Track which delivery options are selected
  Map<String, bool> _selectedDeliveryOptions = {
    'Cooperative Delivery': false,
    'Pick Up': true, // Default to Pick Up
  };

  final List<String> _orderTypes = ['Available Now', 'Pre Order'];

  final List<String> _units = [
    'Kilo (kg)',
    'Bunch (Tali)',
    'Piece (Per Piece / Piraso)',
    'Sack (Sako)',
  ];

  final List<String> _categories = ['Vegetables', 'Fruits', 'Grains', 'Others'];

  @override
  void initState() {
    super.initState();
    _loadSellerCooperative();
  }

  // Load the seller's assigned cooperative
  Future<void> _loadSellerCooperative() async {
    setState(() {
      _loadingCoops = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Get seller's assigned cooperative from users or sellers collection
        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final cooperativeId = userData['cooperativeId'] as String?;

          if (cooperativeId != null) {
            // Load the specific cooperative
            final coopDoc =
                await _firestore.collection('users').doc(cooperativeId).get();

            if (coopDoc.exists) {
              final coopData = coopDoc.data() as Map<String, dynamic>;
              setState(() {
                _selectedCoopId = cooperativeId;
                _selectedCoopName = coopData['name'] ?? 'Unnamed Cooperative';
                _selectedCoopLocation = coopData['location'] as String?;
                // Set pickup location if available
                if (_selectedCoopLocation != null &&
                    _selectedCoopLocation!.isNotEmpty) {
                  _pickupLocationController.text = _selectedCoopLocation!;
                }
                _cooperatives = [
                  {
                    'id': cooperativeId,
                    'name': coopData['name'] ?? 'Unnamed Cooperative',
                    'email': coopData['email'] ?? '',
                    'location': coopData['location'] ?? '',
                  }
                ];
              });
            }
          } else {
            // If no cooperative assigned, load all active cooperatives
            final coopsSnapshot = await _firestore
                .collection('users')
                .where('role', isEqualTo: 'cooperative')
                .where('status', isEqualTo: 'active')
                .get();

            setState(() {
              _cooperatives = coopsSnapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'name': data['name'] ?? 'Unnamed Cooperative',
                  'email': data['email'] ?? '',
                  'location': data['location'] ?? '',
                };
              }).toList();
            });
          }
        }
      }
    } catch (e) {
      print('Error loading cooperatives: $e');
    } finally {
      setState(() {
        _loadingCoops = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _pickupLocationController.dispose();
    _estimatedDateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (images.isNotEmpty) {
        setState(() {
          // Limit to maximum 5 images
          if (_selectedImages.length + images.length <= 5) {
            _selectedImages.addAll(images.map((xfile) => File(xfile.path)));
          } else {
            // Add only up to the limit
            int remaining = 5 - _selectedImages.length;
            _selectedImages.addAll(
                images.take(remaining).map((xfile) => File(xfile.path)));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Maximum 5 images allowed'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking images: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Upload images to Firebase Storage
  Future<List<String>> _uploadProductImages(String productId) async {
    if (_selectedImages.isEmpty) return [];

    try {
      List<String> imageUrls = [];

      for (int i = 0; i < _selectedImages.length; i++) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('product_images')
            .child(productId)
            .child('product_image_$i.jpg');

        final uploadTask = ref.putFile(_selectedImages[i]);

        // Wait for the upload to complete
        final snapshot = await uploadTask;

        // Get the download URL
        final downloadUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);

        print('Image $i uploaded successfully. URL: $downloadUrl');
      }

      return imageUrls;
    } catch (e) {
      print('Error uploading product images: $e');

      // Show more specific error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return [];
    }
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if cooperative is selected
    if (_selectedCoopId == null || _selectedCoopId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a cooperative to handle this product'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    // Check if at least one delivery option is selected
    if (_selectedDeliveryOptions.values.every((selected) => !selected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one delivery method'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to add products'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get seller information
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      String sellerName = 'Unknown Seller';
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        sellerName = userData['name'] ??
            userData['fullName'] ??
            currentUser.displayName ??
            'Unknown Seller';
      }

      // Generate a unique product ID first
      String productId = _firestore.collection('products').doc().id;

      // Upload product images if selected
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        // Show uploading feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('Uploading ${_selectedImages.length} image(s)...'),
                ],
              ),
              duration: const Duration(seconds: 10),
            ),
          );
        }
        imageUrls = await _uploadProductImages(productId);
        if (imageUrls.isEmpty) {
          throw Exception('Failed to upload product images. Please try again.');
        } else {
          // Hide the uploading message and show success
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${imageUrls.length} image(s) uploaded successfully! ✅'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }

      // Create product data
      final productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'quantity': int.parse(_quantityController.text.trim()),
        'currentStock': int.parse(_quantityController.text.trim()),
        'unit': _selectedUnit,
        'category': _selectedCategory,
        'pickupLocation': _pickupLocationController.text.trim(),
        'deliveryOptions': _selectedDeliveryOptions.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList(),
        'orderType': _selectedOrderType,
        'harvestDate': _harvestDate,
        'estimatedAvailabilityDate': _estimatedAvailabilityDate,
        'sellerId': currentUser.uid,
        'sellerName': sellerName,
        'sellerEmail': currentUser.email,
        'status': 'pending', // Requires cooperative approval
        'createdAt': FieldValue.serverTimestamp(),
        'reserved': 0,
        'sold': 0,
        'imageUrl': imageUrls.isNotEmpty
            ? imageUrls[0]
            : null, // First image as primary
        'imageUrls': imageUrls, // All images
        'cooperativeId': _selectedCoopId, // Link to cooperative
        'cooperativeName':
            _selectedCoopName, // Store cooperative name for display
      };

      // Add product to Firestore with the specific ID
      await _firestore.collection('products').doc(productId).set(productData);

      // Notify seller that product was submitted for approval
      await NotificationManager.sendDirectTestNotification(
        title: '📋 Product Submitted',
        body:
            'Your product "${_nameController.text.trim()}" has been submitted for cooperative review. You\'ll be notified once it\'s approved.',
        payload: 'product_submitted|$productId',
      );

      // Notify cooperative about new product submission
      if (_selectedCoopId != null) {
        try {
          await _firestore.collection('cooperative_notifications').add({
            'title': 'New Product Pending Approval',
            'message':
                'New product "${_nameController.text.trim()}" by $sellerName requires your approval.',
            'createdAt': FieldValue.serverTimestamp(),
            'type': 'product_approval',
            'read': false,
            'sellerId': currentUser.uid,
            'productId': productId,
            'priority': 'medium',
            'cooperativeId': _selectedCoopId, // Target specific cooperative
          });
        } catch (e) {
          print('Failed to notify cooperative: $e');
          // Don't fail the whole operation if cooperative notification fails
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Product submitted successfully to ${_selectedCoopName ?? "cooperative"}! It will be available once approved.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      print('Error adding product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding product: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Product'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Images Section (Multiple)
                    const Text(
                      'Product Images (Max 5)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Display selected images
                    if (_selectedImages.isNotEmpty)
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _selectedImages.length) {
                              // Add more button
                              if (_selectedImages.length < 5) {
                                return GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    width: 120,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate,
                                            size: 40, color: Colors.grey[400]),
                                        const SizedBox(height: 4),
                                        Text('Add More',
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                );
                              } else {
                                return const SizedBox.shrink();
                              }
                            }

                            // Display image
                            return Container(
                              width: 120,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      _selectedImages[index],
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  // Remove button
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedImages.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.8),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ),
                                  // Primary badge for first image
                                  if (index == 0)
                                    Positioned(
                                      bottom: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.8),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Main',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    // Add photos button (when no images)
                    if (_selectedImages.isEmpty)
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate,
                                    size: 50, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text('Add Product Photos',
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('Tap to select from gallery',
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('You can add up to 5 images',
                                    style: TextStyle(
                                        color: Colors.grey[400], fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),
                    // Image count indicator
                    if (_selectedImages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${_selectedImages.length}/5 photos selected',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Product Name
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Product Name*',
                          hintText: 'e.g., Fresh Organic Tomatoes',
                          prefixIcon: Icon(Icons.shopping_bag,
                              color: Colors.grey.shade600),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          labelStyle: TextStyle(color: Colors.grey.shade700),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter product name';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Price per unit
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Price per Unit*',
                          hintText: '0.00',
                          prefixIcon: Icon(Icons.attach_money,
                              color: Colors.grey.shade600),
                          prefixText: '₱',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          labelStyle: TextStyle(color: Colors.grey.shade700),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter price';
                          }
                          if (double.tryParse(value) == null ||
                              double.parse(value) <= 0) {
                            return 'Please enter valid price';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Available quantity/stocks
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Available Quantity/Stocks*',
                          hintText: '0',
                          prefixIcon: Icon(Icons.inventory,
                              color: Colors.grey.shade600),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          labelStyle: TextStyle(color: Colors.grey.shade700),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter quantity';
                          }
                          if (int.tryParse(value) == null ||
                              int.parse(value) <= 0) {
                            return 'Please enter valid quantity';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Unit Selection
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: InputDecoration(
                          labelText: 'Unit*',
                          prefixIcon: Icon(Icons.straighten,
                              color: Colors.grey.shade600),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          labelStyle: TextStyle(color: Colors.grey.shade700),
                        ),
                        items: _units.map((unit) {
                          return DropdownMenuItem<String>(
                            value: unit,
                            child: Text(unit),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedUnit = value!;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Product Description
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Product Description*',
                          hintText:
                              'Describe your product, quality, growing method, etc...',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(bottom: 40),
                            child: Icon(Icons.description,
                                color: Colors.grey.shade600),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          labelStyle: TextStyle(color: Colors.grey.shade700),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter product description';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Category Selection
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category*',
                          prefixIcon:
                              Icon(Icons.category, color: Colors.grey.shade600),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          labelStyle: TextStyle(color: Colors.grey.shade700),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Cooperative Selection
                    if (_loadingCoops)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
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
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber,
                                color: Colors.orange.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No cooperative assigned. Please contact support.',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_cooperatives.length == 1)
                      // Show assigned cooperative (read-only)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.business,
                                color: Colors.green.shade700, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Cooperative',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _selectedCoopName ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.green.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'This product will be handled by your assigned cooperative',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      // Show dropdown if multiple cooperatives available
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: DropdownButtonFormField<String>(
                          value: _selectedCoopId,
                          decoration: InputDecoration(
                            labelText: 'Select Cooperative*',
                            prefixIcon: Icon(Icons.business,
                                color: Colors.grey.shade600),
                            border: InputBorder.none,
                            labelStyle: TextStyle(color: Colors.grey.shade700),
                          ),
                          items: _cooperatives.map((coop) {
                            return DropdownMenuItem<String>(
                              value: coop['id'] as String,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      coop['name'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCoopId = value;
                              final selectedCoop = _cooperatives.firstWhere(
                                (coop) => coop['id'] == value,
                                orElse: () => {'name': '', 'location': ''},
                              );
                              _selectedCoopName =
                                  selectedCoop['name'] as String?;
                              _selectedCoopLocation =
                                  selectedCoop['location'] as String?;

                              // Automatically set pickup location if available
                              if (_selectedCoopLocation != null &&
                                  _selectedCoopLocation!.isNotEmpty) {
                                _pickupLocationController.text =
                                    _selectedCoopLocation!;
                              }
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a cooperative';
                            }
                            return null;
                          },
                          isExpanded: true,
                        ),
                      ),

                    // Show cooperative location info if available
                    if (_selectedCoopLocation != null &&
                        _selectedCoopLocation!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 16),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: Colors.blue.shade600),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Pickup location: $_selectedCoopLocation',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Pick-up Location
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextFormField(
                        controller: _pickupLocationController,
                        decoration: InputDecoration(
                          labelText: 'Pick-up Location*',
                          hintText: _selectedCoopLocation != null &&
                                  _selectedCoopLocation!.isNotEmpty
                              ? 'Auto-filled from cooperative'
                              : 'e.g., Green Valley Farm, Barangay San Jose',
                          prefixIcon: Icon(Icons.location_on,
                              color: _selectedCoopLocation != null &&
                                      _selectedCoopLocation!.isNotEmpty
                                  ? Colors.green.shade600
                                  : Colors.grey.shade600),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          labelStyle: TextStyle(color: Colors.grey.shade700),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter pick-up location';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Delivery Method Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue.shade700, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Choose the delivery method you can provide to buyers',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Available Delivery Methods
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping,
                                  color: Colors.grey.shade600, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Available Delivery Methods*',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select all delivery methods you can provide:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._deliveryOptions.map((option) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: _selectedDeliveryOptions[option]!
                                    ? Colors.green.shade50
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _selectedDeliveryOptions[option]!
                                      ? Colors.green.shade300
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: CheckboxListTile(
                                title: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight:
                                        _selectedDeliveryOptions[option]!
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                    color: _selectedDeliveryOptions[option]!
                                        ? Colors.green.shade800
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                value: _selectedDeliveryOptions[option],
                                onChanged: (bool? value) {
                                  setState(() {
                                    _selectedDeliveryOptions[option] =
                                        value ?? false;
                                  });
                                },
                                activeColor: Colors.green.shade600,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            );
                          }),
                          if (_selectedDeliveryOptions.values
                              .every((selected) => !selected))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Please select at least one delivery method',
                                style: TextStyle(
                                  color: Colors.red.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Date of Harvest (Optional)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.calendar_today,
                            color: Colors.grey.shade600),
                        title: Text(
                          _harvestDate == null
                              ? 'Date of Harvest (Optional)'
                              : 'Harvest Date: ${_harvestDate!.day}/${_harvestDate!.month}/${_harvestDate!.year}',
                          style: TextStyle(
                            color: _harvestDate == null
                                ? Colors.grey.shade700
                                : Colors.black87,
                          ),
                        ),
                        trailing: _harvestDate != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _harvestDate = null;
                                  });
                                },
                              )
                            : null,
                        onTap: () async {
                          final DateTime now = DateTime.now();
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _harvestDate ?? now,
                            firstDate:
                                DateTime(now.year - 1, now.month, now.day),
                            lastDate:
                                DateTime(now.year + 1, now.month, now.day),
                            helpText: 'Select Harvest Date',
                            errorFormatText: 'Enter valid date',
                            errorInvalidText: 'Please select a valid date',
                          );
                          if (picked != null) {
                            setState(() {
                              _harvestDate = picked;
                            });
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Order Type
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedOrderType,
                        decoration: InputDecoration(
                          labelText: 'Order Type*',
                          prefixIcon: Icon(Icons.shopping_cart,
                              color: Colors.grey.shade600),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          labelStyle: TextStyle(color: Colors.grey.shade700),
                        ),
                        items: _orderTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedOrderType = value!;
                            if (_selectedOrderType == 'Available Now') {
                              _estimatedAvailabilityDate = null;
                            }
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Submit Product for Approval',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Info Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.primaryGreen.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: AppTheme.primaryGreen),
                              const SizedBox(width: 8),
                              Text(
                                'Product Approval Process',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your product will be reviewed by our admin team before it goes live. This ensures quality and compliance with our marketplace standards. You\'ll receive a notification once your product is approved or if any changes are needed.',
                            style: TextStyle(color: AppTheme.primaryGreen),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
