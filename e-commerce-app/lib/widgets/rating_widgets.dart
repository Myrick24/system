import 'package:flutter/material.dart';
import '../models/rating_model.dart';

class RatingWidget extends StatelessWidget {
  final double rating;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool showText;
  final String? customText;

  const RatingWidget({
    Key? key,
    required this.rating,
    this.size = 16.0,
    this.activeColor,
    this.inactiveColor,
    this.showText = false,
    this.customText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeStarColor = activeColor ?? Colors.amber;
    final inactiveStarColor = inactiveColor ?? Colors.grey[300]!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            double starValue = index + 1.0;
            IconData iconData;
            Color starColor;

            if (rating >= starValue) {
              iconData = Icons.star;
              starColor = activeStarColor;
            } else if (rating >= starValue - 0.5) {
              iconData = Icons.star_half;
              starColor = activeStarColor;
            } else {
              iconData = Icons.star_border;
              starColor = inactiveStarColor;
            }

            return Icon(
              iconData,
              color: starColor,
              size: size,
            );
          }),
        ),
        if (showText) ...[
          SizedBox(width: 4),
          Text(
            customText ?? rating.toStringAsFixed(1),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ],
    );
  }
}

class InteractiveRatingWidget extends StatefulWidget {
  final double initialRating;
  final Function(double) onRatingChanged;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const InteractiveRatingWidget({
    Key? key,
    this.initialRating = 0.0,
    required this.onRatingChanged,
    this.size = 24.0,
    this.activeColor,
    this.inactiveColor,
  }) : super(key: key);

  @override
  State<InteractiveRatingWidget> createState() => _InteractiveRatingWidgetState();
}

class _InteractiveRatingWidgetState extends State<InteractiveRatingWidget> {
  late double _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    final activeStarColor = widget.activeColor ?? Colors.amber;
    final inactiveStarColor = widget.inactiveColor ?? Colors.grey[300]!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        double starValue = index + 1.0;
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _currentRating = starValue;
            });
            widget.onRatingChanged(_currentRating);
          },
          child: Icon(
            _currentRating >= starValue ? Icons.star : Icons.star_border,
            color: _currentRating >= starValue ? activeStarColor : inactiveStarColor,
            size: widget.size,
          ),
        );
      }),
    );
  }
}

class RatingDistributionWidget extends StatelessWidget {
  final SellerRatingStats stats;

  const RatingDistributionWidget({
    Key? key,
    required this.stats,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            RatingWidget(
              rating: stats.averageRating,
              size: 20,
              showText: true,
            ),
            SizedBox(width: 8),
            Text(
              '(${stats.totalReviews} reviews)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        ...List.generate(5, (index) {
          int starNumber = 5 - index;
          int count = stats.ratingDistribution[starNumber] ?? 0;
          double percentage = stats.totalReviews > 0 ? count / stats.totalReviews : 0.0;

          return Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text(
                  '$starNumber',
                  style: theme.textTheme.bodySmall,
                ),
                SizedBox(width: 4),
                Icon(Icons.star, size: 12, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 30,
                  child: Text(
                    '$count',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          );
        }),
        if (stats.verifiedPurchasesCount > 0) ...[
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.verified, size: 16, color: Colors.green),
              SizedBox(width: 4),
              Text(
                '${stats.verifiedPurchasesCount} verified purchases',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class ReviewCard extends StatelessWidget {
  final Rating rating;
  final bool showProductInfo;
  final VoidCallback? onReport;

  const ReviewCard({
    Key? key,
    required this.rating,
    this.showProductInfo = false,
    this.onReport,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // User Avatar
                CircleAvatar(
                  radius: 16,
                  backgroundImage: rating.buyerProfileImage != null
                      ? NetworkImage(rating.buyerProfileImage!)
                      : null,
                  child: rating.buyerProfileImage == null
                      ? Text(
                          rating.buyerName.isNotEmpty 
                              ? rating.buyerName[0].toUpperCase() 
                              : 'U',
                          style: TextStyle(fontSize: 12),
                        )
                      : null,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            rating.buyerName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (rating.isVerifiedPurchase) ...[
                            SizedBox(width: 4),
                            Icon(
                              Icons.verified,
                              size: 14,
                              color: Colors.green,
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          RatingWidget(
                            rating: rating.rating,
                            size: 14,
                          ),
                          SizedBox(width: 8),
                          Text(
                            _formatDate(rating.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onReport != null)
                  IconButton(
                    icon: Icon(Icons.more_vert, size: 16),
                    onPressed: () => _showReportDialog(context),
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints(),
                  ),
              ],
            ),
            if (showProductInfo && rating.productName != null) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Product: ${rating.productName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            if (rating.review != null && rating.review!.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                rating.review!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report Review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Why are you reporting this review?'),
            SizedBox(height: 16),
            ...['Inappropriate content', 'Spam', 'Fake review', 'Other'].map(
              (reason) => ListTile(
                title: Text(reason),
                onTap: () {
                  Navigator.pop(context);
                  onReport?.call();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Review reported. Thank you for your feedback.')),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
}