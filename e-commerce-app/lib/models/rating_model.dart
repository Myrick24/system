import 'package:cloud_firestore/cloud_firestore.dart';

class Rating {
  final String id;
  final String sellerId;
  final String buyerId;
  final String buyerName;
  final String? buyerProfileImage;
  final double rating; // 1-5 stars
  final String? review;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isVerifiedPurchase;
  final String? productId; // Optional: if rating is for a specific product
  final String? productName;

  Rating({
    required this.id,
    required this.sellerId,
    required this.buyerId,
    required this.buyerName,
    this.buyerProfileImage,
    required this.rating,
    this.review,
    required this.createdAt,
    required this.updatedAt,
    this.isVerifiedPurchase = false,
    this.productId,
    this.productName,
  });

  // Convert Rating to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sellerId': sellerId,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'buyerProfileImage': buyerProfileImage,
      'rating': rating,
      'review': review,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isVerifiedPurchase': isVerifiedPurchase,
      'productId': productId,
      'productName': productName,
    };
  }

  // Create Rating from Firestore document
  factory Rating.fromMap(Map<String, dynamic> map, String documentId) {
    return Rating(
      id: documentId,
      sellerId: map['sellerId'] ?? '',
      buyerId: map['buyerId'] ?? map['reviewerId'] ?? '', // Handle old reviewerId field
      buyerName: map['buyerName'] ?? map['reviewerName'] ?? '', // Handle old reviewerName field
      buyerProfileImage: map['buyerProfileImage'],
      rating: (map['rating'] ?? 0.0).toDouble(),
      review: map['review'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isVerifiedPurchase: map['isVerifiedPurchase'] ?? false,
      productId: map['productId'],
      productName: map['productName'],
    );
  }

  // Create a copy with updated fields
  Rating copyWith({
    String? id,
    String? sellerId,
    String? buyerId,
    String? buyerName,
    String? buyerProfileImage,
    double? rating,
    String? review,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isVerifiedPurchase,
    String? productId,
    String? productName,
  }) {
    return Rating(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      buyerProfileImage: buyerProfileImage ?? this.buyerProfileImage,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isVerifiedPurchase: isVerifiedPurchase ?? this.isVerifiedPurchase,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
    );
  }
}

// Class to hold seller rating statistics
class SellerRatingStats {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution; // {1: count, 2: count, ...}
  final int verifiedPurchasesCount;

  SellerRatingStats({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
    required this.verifiedPurchasesCount,
  });

  factory SellerRatingStats.empty() {
    return SellerRatingStats(
      averageRating: 0.0,
      totalReviews: 0,
      ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      verifiedPurchasesCount: 0,
    );
  }

  // Calculate stats from a list of ratings
  factory SellerRatingStats.fromRatings(List<Rating> ratings) {
    if (ratings.isEmpty) {
      return SellerRatingStats.empty();
    }

    double totalRating = 0;
    Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    int verifiedCount = 0;

    for (Rating rating in ratings) {
      totalRating += rating.rating;
      int ratingInt = rating.rating.round().clamp(1, 5);
      distribution[ratingInt] = (distribution[ratingInt] ?? 0) + 1;
      
      if (rating.isVerifiedPurchase) {
        verifiedCount++;
      }
    }

    return SellerRatingStats(
      averageRating: totalRating / ratings.length,
      totalReviews: ratings.length,
      ratingDistribution: distribution,
      verifiedPurchasesCount: verifiedCount,
    );
  }
}