import 'package:flutter/material.dart';
import '../models/rating_model.dart';
import '../services/rating_service.dart';
import '../widgets/rating_widgets.dart';

class RatingDialog extends StatefulWidget {
  final String sellerId;
  final String sellerName;
  final Rating? existingRating;
  final String? productId;
  final String? productName;

  const RatingDialog({
    Key? key,
    required this.sellerId,
    required this.sellerName,
    this.existingRating,
    this.productId,
    this.productName,
  }) : super(key: key);

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  final RatingService _ratingService = RatingService();
  final TextEditingController _reviewController = TextEditingController();
  
  double _rating = 0.0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingRating != null) {
      _rating = widget.existingRating!.rating;
      _reviewController.text = widget.existingRating!.review ?? '';
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingRating != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Review' : 'Rate Seller'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seller info
            Row(
              children: [
                Icon(Icons.store, color: theme.primaryColor),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.sellerName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            // Product info (if applicable)
            if (widget.productName != null) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shopping_bag, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.productName!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            SizedBox(height: 20),
            
            // Rating section
            Text(
              'Your Rating',
              style: theme.textTheme.titleSmall,
            ),
            SizedBox(height: 8),
            Center(
              child: InteractiveRatingWidget(
                initialRating: _rating,
                onRatingChanged: (rating) {
                  setState(() {
                    _rating = rating;
                  });
                },
                size: 32,
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                _getRatingText(_rating),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: _getRatingColor(_rating),
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Review section
            Text(
              'Your Review (Optional)',
              style: theme.textTheme.titleSmall,
            ),
            SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Share your experience with this seller...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        if (isEditing)
          TextButton(
            onPressed: _isSubmitting ? null : _deleteRating,
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ElevatedButton(
          onPressed: _isSubmitting || _rating == 0 ? null : _submitRating,
          child: _isSubmitting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Update' : 'Submit'),
        ),
      ],
    );
  }

  String _getRatingText(double rating) {
    if (rating == 0) return 'Tap to rate';
    if (rating <= 1) return 'Poor';
    if (rating <= 2) return 'Fair';
    if (rating <= 3) return 'Good';
    if (rating <= 4) return 'Very Good';
    return 'Excellent';
  }

  Color _getRatingColor(double rating) {
    if (rating == 0) return Colors.grey;
    if (rating <= 2) return Colors.red;
    if (rating <= 3) return Colors.orange;
    if (rating <= 4) return Colors.yellow[700]!;
    return Colors.green;
  }

  Future<void> _submitRating() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await _ratingService.addOrUpdateRating(
        sellerId: widget.sellerId,
        rating: _rating,
        review: _reviewController.text.trim().isEmpty ? null : _reviewController.text.trim(),
        productId: widget.productId,
        productName: widget.productName,
      );

      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingRating != null 
                ? 'Review updated successfully!' 
                : 'Review submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showErrorSnackBar('Failed to submit review. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _deleteRating() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Review'),
        content: Text('Are you sure you want to delete your review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        final success = await _ratingService.deleteRating(
          widget.existingRating!.id,
          widget.sellerId,
        );

        if (success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Review deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          _showErrorSnackBar('Failed to delete review. Please try again.');
        }
      } catch (e) {
        _showErrorSnackBar('An error occurred. Please try again.');
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Helper function to show rating dialog
Future<bool?> showRatingDialog({
  required BuildContext context,
  required String sellerId,
  required String sellerName,
  Rating? existingRating,
  String? productId,
  String? productName,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => RatingDialog(
      sellerId: sellerId,
      sellerName: sellerName,
      existingRating: existingRating,
      productId: productId,
      productName: productName,
    ),
  );
}