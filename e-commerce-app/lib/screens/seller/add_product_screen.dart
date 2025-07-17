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
  final _pickupLocationController = TextEditingController();
  final _estimatedDateController = TextEditingController();

  String _selectedOrderType = 'Available Now';
  File? _selectedImage;
  DateTime? _harvestDate;
  DateTime? _estimatedAvailabilityDate;
  bool _isLoading = false;

  // Multiple delivery options - simplified to 3 choices
  final List<String> _deliveryOptions = ['Delivery', 'Pick Up', 'Meet up'];

  // Track which delivery options are selected
  Map<String, bool> _selectedDeliveryOptions = {
    'Delivery': false,
    'Pick Up': true, // Default to Pick Up
    'Meet up': false,
  };

  final List<String> _orderTypes = ['Available Now', 'Pre Order'];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _pickupLocationController.dispose();
    _estimatedDateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Upload image to Firebase Storage
  Future<String?> _uploadProductImage(String productId) async {
    if (_selectedImage == null) return null;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('product_images')
          .child(productId)
          .child('product_image.jpg');

      final uploadTask = ref.putFile(_selectedImage!);

      // Wait for the upload to complete
      final snapshot = await uploadTask;

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print('Image uploaded successfully. URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading product image: $e');

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
      return null;
    }
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if at least one delivery option is selected
    if (_selectedDeliveryOptions.values.every((selected) => !selected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one delivery method'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Additional validation for Pre Order type
    if (_selectedOrderType == 'Pre Order' &&
        _estimatedAvailabilityDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please select an estimated availability date for pre-order products'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add products')),
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

      // Upload product image if selected
      String? imageUrl;
      if (_selectedImage != null) {
        // Show uploading feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Uploading product image...'),
                ],
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        imageUrl = await _uploadProductImage(productId);
        if (imageUrl == null) {
          throw Exception('Failed to upload product image. Please try again.');
        } else {
          // Hide the uploading message and show success
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image uploaded successfully! ✅'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
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
        'status': 'pending', // Requires admin approval
        'createdAt': FieldValue.serverTimestamp(),
        'reserved': 0,
        'sold': 0,
        'imageUrl': imageUrl, // Now properly set with uploaded image URL
      };

      // Add product to Firestore with the specific ID
      await _firestore.collection('products').doc(productId).set(productData);

      // Notify seller that product was submitted for approval
      await NotificationManager.sendDirectTestNotification(
        title: '📋 Product Submitted',
        body:
            'Your product "${_nameController.text.trim()}" has been submitted for admin review. You\'ll be notified once it\'s approved.',
        payload: 'product_submitted|$productId',
      );

      // Notify admins about new product submission
      try {
        await NotificationManager.sendDirectTestNotification(
          title: '🛍️ New Product Pending',
          body:
              'New product "${_nameController.text.trim()}" by $sellerName requires approval.',
          payload: 'admin_product_approval|$productId',
        );
      } catch (e) {
        print('Failed to notify admins: $e');
        // Don't fail the whole operation if admin notification fails
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Product submitted successfully! It will be available once approved by admin.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      print('Error adding product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding product: $e')),
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
                    // Product Image Section
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
                          child: _selectedImage != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        _selectedImage!,
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedImage = null;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.8),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 18,
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
                                          color: Colors.green.withOpacity(0.8),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.check_circle,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            const Text(
                                              'Image Selected',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 50,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add Product Photo',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap to select from gallery',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
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
                          hintText:
                              'e.g., Green Valley Farm, Barangay San Jose',
                          prefixIcon: Icon(Icons.location_on,
                              color: Colors.grey.shade600),
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
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 365)),
                            lastDate: DateTime.now(),
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

                    // Estimated Availability Date (only show if Pre Order is selected)
                    if (_selectedOrderType == 'Pre Order')
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.schedule,
                              color: Colors.orange.shade700),
                          title: Text(
                            _estimatedAvailabilityDate == null
                                ? 'Estimated Availability Date*'
                                : 'Available: ${_estimatedAvailabilityDate!.day}/${_estimatedAvailabilityDate!.month}/${_estimatedAvailabilityDate!.year}',
                            style: TextStyle(
                              color: _estimatedAvailabilityDate == null
                                  ? Colors.orange.shade700
                                  : Colors.orange.shade800,
                            ),
                          ),
                          trailing: _estimatedAvailabilityDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _estimatedAvailabilityDate = null;
                                    });
                                  },
                                )
                              : null,
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  DateTime.now().add(const Duration(days: 1)),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() {
                                _estimatedAvailabilityDate = picked;
                              });
                            }
                          },
                        ),
                      ),

                    if (_selectedOrderType == 'Pre Order')
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
