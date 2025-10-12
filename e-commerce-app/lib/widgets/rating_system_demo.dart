import 'package:flutter/material.dart';
import '../models/rating_model.dart';
import '../services/rating_service.dart';
import '../widgets/rating_widgets.dart';
import '../widgets/rating_dialog.dart';

/// Example widget demonstrating how to use the rating system
class RatingSystemDemo extends StatefulWidget {
  const RatingSystemDemo({Key? key}) : super(key: key);

  @override
  State<RatingSystemDemo> createState() => _RatingSystemDemoState();
}

class _RatingSystemDemoState extends State<RatingSystemDemo> {
  final RatingService _ratingService = RatingService();
  final String _demoSellerId = 'demo_seller_123'; // Replace with actual seller ID
  SellerRatingStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRatingStats();
  }

  Future<void> _loadRatingStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stats = await _ratingService.getSellerRatingStats(_demoSellerId);
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading rating stats: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rating System Demo'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Basic Rating Display
                  _buildSection(
                    'Basic Rating Display',
                    Column(
                      children: [
                        const Text('5 Star Rating:'),
                        const SizedBox(height: 8),
                        const RatingWidget(rating: 5.0, size: 24),
                        const SizedBox(height: 16),
                        const Text('3.5 Star Rating:'),
                        const SizedBox(height: 8),
                        const RatingWidget(rating: 3.5, size: 24),
                        const SizedBox(height: 16),
                        const Text('With Text:'),
                        const SizedBox(height: 8),
                        const RatingWidget(
                          rating: 4.2,
                          size: 20,
                          showText: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section 2: Interactive Rating
                  _buildSection(
                    'Interactive Rating',
                    Column(
                      children: [
                        const Text('Tap stars to rate:'),
                        const SizedBox(height: 8),
                        InteractiveRatingWidget(
                          onRatingChanged: (rating) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Rating: ${rating.toStringAsFixed(1)} stars'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section 3: Rating Statistics
                  _buildSection(
                    'Rating Statistics',
                    _stats != null
                        ? RatingDistributionWidget(stats: _stats!)
                        : const Text('No rating data available'),
                  ),

                  const SizedBox(height: 24),

                  // Section 4: Sample Review Cards
                  _buildSection(
                    'Sample Review Cards',
                    Column(
                      children: [
                        ReviewCard(
                          rating: _createSampleRating(1),
                          showProductInfo: true,
                        ),
                        const SizedBox(height: 8),
                        ReviewCard(
                          rating: _createSampleRating(2),
                          showProductInfo: false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section 5: Live Rating Stream
                  _buildSection(
                    'Live Rating Stream',
                    SizedBox(
                      height: 300,
                      child: StreamBuilder<List<Rating>>(
                        stream: _ratingService.getSellerRatings(_demoSellerId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }

                          final ratings = snapshot.data ?? [];
                          
                          if (ratings.isEmpty) {
                            return const Center(
                              child: Text('No ratings yet'),
                            );
                          }

                          return ListView.builder(
                            itemCount: ratings.length,
                            itemBuilder: (context, index) {
                              return ReviewCard(rating: ratings[index]);
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section 6: Rating Dialog Button
                  _buildSection(
                    'Rating Dialog',
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _showRatingDialog,
                        icon: const Icon(Icons.star),
                        label: const Text('Rate Seller'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section 7: Action Buttons
                  _buildSection(
                    'Actions',
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _loadRatingStats,
                            child: const Text('Refresh Stats'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _showTopRatedSellers,
                            child: const Text('Top Sellers'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Rating _createSampleRating(int index) {
    return Rating(
      id: 'sample_$index',
      sellerId: _demoSellerId,
      buyerId: 'buyer_$index',
      buyerName: index == 1 ? 'John Doe' : 'Jane Smith',
      rating: index == 1 ? 5.0 : 4.0,
      review: index == 1 
          ? 'Excellent seller! Fast shipping and great communication.'
          : 'Good product quality. Would buy again.',
      createdAt: DateTime.now().subtract(Duration(days: index)),
      updatedAt: DateTime.now().subtract(Duration(days: index)),
      isVerifiedPurchase: index == 1,
      productName: index == 1 ? 'Sample Product A' : null,
    );
  }

  void _showRatingDialog() {
    showRatingDialog(
      context: context,
      sellerId: _demoSellerId,
      sellerName: 'Demo Seller',
    ).then((updated) {
      if (updated == true) {
        _loadRatingStats();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _showTopRatedSellers() async {
    try {
      final topSellers = await _ratingService.getTopRatedSellers(limit: 5);
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Top Rated Sellers'),
          content: SizedBox(
            width: double.maxFinite,
            child: topSellers.isEmpty
                ? const Text('No sellers found')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: topSellers.length,
                    itemBuilder: (context, index) {
                      final seller = topSellers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('${index + 1}'),
                        ),
                        title: Text(seller['name'] ?? 'Unknown Seller'),
                        subtitle: RatingWidget(
                          rating: (seller['rating'] ?? 0.0).toDouble(),
                          size: 16,
                          showText: true,
                        ),
                        trailing: Text('${seller['totalReviews']} reviews'),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading top sellers: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}