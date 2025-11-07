import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellerReviewScreen extends StatefulWidget {
  final String sellerId;
  final String userId;

  const SellerReviewScreen({
    Key? key,
    required this.sellerId,
    required this.userId,
  }) : super(key: key);

  @override
  State<SellerReviewScreen> createState() => _SellerReviewScreenState();
}

class _SellerReviewScreenState extends State<SellerReviewScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  Map<String, dynamic>? _sellerData;
  String _currentStatus = 'pending';
  bool _isProcessing = false;
  String? _actualSellerId; // Store the actual seller document ID

  @override
  void initState() {
    super.initState();
    _loadSellerData();
  }

  Future<void> _loadSellerData() async {
    try {
      print('🔍 Loading seller data...');
      print('   sellerId parameter: ${widget.sellerId}');
      print('   userId parameter: ${widget.userId}');

      // Load seller details from sellers collection using sellerId
      final sellerDoc =
          await _firestore.collection('sellers').doc(widget.sellerId).get();

      print('   Seller doc exists: ${sellerDoc.exists}');

      if (!sellerDoc.exists) {
        print('   ⚠️ Seller document not found in sellers collection');
        print('   Attempting fallback query...');

        // Fallback: Try to find seller by userId
        final fallbackQuery = await _firestore
            .collection('sellers')
            .where('userId', isEqualTo: widget.userId)
            .limit(1)
            .get();

        if (fallbackQuery.docs.isNotEmpty) {
          print('   ✅ Found seller via fallback query');
          final sellerDocFromQuery = fallbackQuery.docs.first;
          setState(() {
            _sellerData = sellerDocFromQuery.data();
            _actualSellerId = sellerDocFromQuery.id; // Store the actual document ID
            _currentStatus = _sellerData?['status'] ?? 'pending';
            _isLoading = false;
          });
          return;
        }
      }

      setState(() {
        _sellerData = sellerDoc.data();
        _actualSellerId = widget.sellerId; // Store the actual document ID
        _currentStatus = _sellerData?['status'] ?? 'pending';
        _isLoading = false;
      });

      print('   ✅ Seller data loaded successfully');
    } catch (e) {
      print('❌ Error loading seller data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSellerStatus(String newStatus) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Use the actual seller document ID (from fallback query if needed)
      final sellerDocId = _actualSellerId ?? widget.sellerId;
      
      print('🔄 Updating seller status to: $newStatus');
      print('   Using seller document ID: $sellerDocId');
      
      // Update sellers collection
      await _firestore.collection('sellers').doc(sellerDocId).update({
        'status': newStatus,
        'verified': newStatus == 'approved',
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': _auth.currentUser?.uid,
      });

      print('   ✅ Seller document updated successfully');

      // Update users collection
      await _firestore.collection('users').doc(widget.userId).update({
        'status': newStatus,
        'verified': newStatus == 'approved',
      });

      print('   ✅ User document updated successfully');

      setState(() {
        _currentStatus = newStatus;
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Seller ${newStatus == 'approved' ? 'approved' : 'rejected'} successfully'),
            backgroundColor:
                newStatus == 'approved' ? Colors.green : Colors.red,
          ),
        );
        Navigator.pop(context, newStatus);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating seller: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Review Seller Application'),
          backgroundColor: Colors.green,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_sellerData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Review Seller Application'),
          backgroundColor: Colors.green,
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Seller data not found'),
            ],
          ),
        ),
      );
    }

    final fullName = _sellerData?['fullName'] ?? 'Unknown';
    final email = _sellerData?['email'] ?? 'N/A';
    final contactNumber = _sellerData?['contactNumber'] ?? 'N/A';
    final vegetableList = _sellerData?['vegetableList'] ?? 'Not specified';
    final governmentIdUrl = _sellerData?['governmentIdUrl'] ?? '';
    final address = _sellerData?['address'] as Map<String, dynamic>? ?? {};
    final createdAt = _sellerData?['createdAt'] as Timestamp?;
    final cooperativeName = _sellerData?['cooperativeName'] ?? 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Application'),
        backgroundColor: Colors.green,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Premium Header Section
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade700, Colors.green.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(_currentStatus),
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _currentStatus.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  // Email preview
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Metadata row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (createdAt != null) ...[
                        Icon(Icons.calendar_today,
                            size: 14, color: Colors.white.withOpacity(0.8)),
                        const SizedBox(width: 4),
                        Text(
                          createdAt.toDate().toString().split(' ')[0],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                      const SizedBox(width: 16),
                      Icon(Icons.business,
                          size: 14, color: Colors.white.withOpacity(0.8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          cooperativeName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content Section - Organized Cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact Information Card
                  _buildCard(
                    icon: Icons.phone_in_talk,
                    title: 'Contact Information',
                    children: [
                      _buildDataRow('Name', fullName),
                      _buildDivider(),
                      _buildDataRow('Email', email),
                      _buildDivider(),
                      _buildDataRow('Phone', contactNumber),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Address Information Card
                  _buildCard(
                    icon: Icons.location_on,
                    title: 'Address',
                    children: [
                      if (address['fullAddress'] != null &&
                          address['fullAddress'].toString().isNotEmpty)
                        _buildDataRow('Address', address['fullAddress'] ?? ''),
                      if (address['province'] != null &&
                          address['province'].toString().isNotEmpty) ...[
                        _buildDivider(),
                        _buildDataRow('Province', address['province'] ?? ''),
                      ],
                      if (address['city'] != null &&
                          address['city'].toString().isNotEmpty) ...[
                        _buildDivider(),
                        _buildDataRow('City', address['city'] ?? ''),
                      ],
                      if (address['barangay'] != null &&
                          address['barangay'].toString().isNotEmpty) ...[
                        _buildDivider(),
                        _buildDataRow('Barangay', address['barangay'] ?? ''),
                      ],
                      if (address['sitio'] != null &&
                          address['sitio'].toString().isNotEmpty) ...[
                        _buildDivider(),
                        _buildDataRow('Sitio', address['sitio'] ?? ''),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Products Card
                  _buildCard(
                    icon: Icons.shopping_basket,
                    title: 'Products to Sell',
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          vegetableList,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Government ID Card
                  _buildCard(
                    icon: Icons.badge,
                    title: 'Government ID',
                    children: [
                      const SizedBox(height: 12),
                      if (governmentIdUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            governmentIdUrl,
                            fit: BoxFit.cover,
                            height: 250,
                            width: double.infinity,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 250,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 250,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(Icons.error, size: 40),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text('No government ID provided'),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  if (_currentStatus == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing
                                ? null
                                : () => _updateSellerStatus('rejected'),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Reject'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing
                                ? null
                                : () => _updateSellerStatus('approved'),
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(_currentStatus).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _getStatusColor(_currentStatus),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Status: ${_currentStatus.toUpperCase()}',
                          style: TextStyle(
                            color: _getStatusColor(_currentStatus),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.green.shade700, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          // Card Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(color: Colors.grey.shade200, height: 0),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
        return Icons.hourglass_empty;
      default:
        return Icons.help;
    }
  }
}
