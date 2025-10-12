import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/rating_model.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference for ratings
  CollectionReference get _ratingsCollection => _firestore.collection('seller_ratings');
  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Add or update a rating for a seller
  Future<bool> addOrUpdateRating({
    required String sellerId,
    required double rating,
    String? review,
    String? productId,
    String? productName,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to rate');
      }

      // Get buyer information
      final buyerDoc = await _usersCollection.doc(currentUser.uid).get();
      final buyerData = buyerDoc.data() as Map<String, dynamic>?;
      final buyerName = buyerData?['name'] ?? 'Anonymous User';
      final buyerProfileImage = buyerData?['profileImage'];

      // Check if user has already rated this seller
      final existingRatingQuery = await _ratingsCollection
          .where('sellerId', isEqualTo: sellerId)
          .where('buyerId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      // Check if this is a verified purchase
      bool isVerifiedPurchase = await _checkVerifiedPurchase(currentUser.uid, sellerId, productId);

      final now = DateTime.now();
      
      final ratingData = Rating(
        id: '', // Will be set by Firestore
        sellerId: sellerId,
        buyerId: currentUser.uid,
        buyerName: buyerName,
        buyerProfileImage: buyerProfileImage,
        rating: rating,
        review: review,
        createdAt: now,
        updatedAt: now,
        isVerifiedPurchase: isVerifiedPurchase,
        productId: productId,
        productName: productName,
      );

      if (existingRatingQuery.docs.isNotEmpty) {
        // Update existing rating
        final existingDoc = existingRatingQuery.docs.first;
        await _ratingsCollection.doc(existingDoc.id).update({
          ...ratingData.toMap(),
          'id': existingDoc.id,
          'createdAt': (existingDoc.data() as Map<String, dynamic>)['createdAt'], // Keep original creation date
        });
      } else {
        // Add new rating
        final docRef = await _ratingsCollection.add(ratingData.toMap());
        await _ratingsCollection.doc(docRef.id).update({'id': docRef.id});
      }

      // Update seller's overall rating
      await _updateSellerRating(sellerId);

      return true;
    } catch (e) {
      print('Error adding/updating rating: $e');
      return false;
    }
  }

  /// Get all ratings for a seller
  Stream<List<Rating>> getSellerRatings(String sellerId) {
    return _ratingsCollection
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Rating.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  /// Get rating statistics for a seller
  Future<SellerRatingStats> getSellerRatingStats(String sellerId) async {
    try {
      final ratingsSnapshot = await _ratingsCollection
          .where('sellerId', isEqualTo: sellerId)
          .get();

      final ratings = ratingsSnapshot.docs
          .map((doc) => Rating.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      return SellerRatingStats.fromRatings(ratings);
    } catch (e) {
      print('Error getting seller rating stats: $e');
      return SellerRatingStats.empty();
    }
  }

  /// Check if current user has rated a seller
  Future<Rating?> getUserRatingForSeller(String sellerId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      // First try with new buyerId field
      var ratingQuery = await _ratingsCollection
          .where('sellerId', isEqualTo: sellerId)
          .where('buyerId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      // If not found, try with old reviewerId field for backward compatibility
      if (ratingQuery.docs.isEmpty) {
        ratingQuery = await _ratingsCollection
            .where('sellerId', isEqualTo: sellerId)
            .where('reviewerId', isEqualTo: currentUser.uid)
            .limit(1)
            .get();
      }

      if (ratingQuery.docs.isNotEmpty) {
        return Rating.fromMap(
          ratingQuery.docs.first.data() as Map<String, dynamic>,
          ratingQuery.docs.first.id,
        );
      }

      return null;
    } catch (e) {
      print('Error getting user rating: $e');
      return null;
    }
  }

  /// Delete a rating
  Future<bool> deleteRating(String ratingId, String sellerId) async {
    try {
      await _ratingsCollection.doc(ratingId).delete();
      await _updateSellerRating(sellerId);
      return true;
    } catch (e) {
      print('Error deleting rating: $e');
      return false;
    }
  }

  /// Update seller's overall rating in users collection
  Future<void> _updateSellerRating(String sellerId) async {
    try {
      final stats = await getSellerRatingStats(sellerId);
      
      await _usersCollection.doc(sellerId).update({
        'rating': stats.averageRating,
        'totalReviews': stats.totalReviews,
        'ratingDistribution': stats.ratingDistribution.map((key, value) => MapEntry(key.toString(), value)),
        'verifiedPurchasesCount': stats.verifiedPurchasesCount,
        'lastRatingUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating seller rating: $e');
    }
  }

  /// Check if purchase is verified
  Future<bool> _checkVerifiedPurchase(String buyerId, String sellerId, String? productId) async {
    try {
      // Check in transactions collection for completed purchases
      Query query = _firestore
          .collection('transactions')
          .where('buyerId', isEqualTo: buyerId)
          .where('sellerId', isEqualTo: sellerId)
          .where('status', isEqualTo: 'completed');

      if (productId != null) {
        query = query.where('productId', isEqualTo: productId);
      }

      final transactionSnapshot = await query.limit(1).get();
      return transactionSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking verified purchase: $e');
      return false;
    }
  }

  /// Get ratings with pagination
  Future<List<Rating>> getSellerRatingsPaginated({
    required String sellerId,
    DocumentSnapshot? lastDocument,
    int limit = 10,
  }) async {
    try {
      Query query = _ratingsCollection
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Rating.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Error getting paginated ratings: $e');
      return [];
    }
  }

  /// Get top rated sellers
  Future<List<Map<String, dynamic>>> getTopRatedSellers({int limit = 10}) async {
    try {
      final sellersSnapshot = await _usersCollection
          .where('role', isEqualTo: 'seller')
          .where('status', isEqualTo: 'approved')
          .where('totalReviews', isGreaterThan: 0)
          .orderBy('rating', descending: true)
          .orderBy('totalReviews', descending: true)
          .limit(limit)
          .get();

      return sellersSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
    } catch (e) {
      print('Error getting top rated sellers: $e');
      return [];
    }
  }

  /// Report a review as inappropriate
  Future<bool> reportReview({
    required String ratingId,
    required String reason,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      await _firestore.collection('review_reports').add({
        'ratingId': ratingId,
        'reportedBy': currentUser.uid,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      return true;
    } catch (e) {
      print('Error reporting review: $e');
      return false;
    }
  }

  /// Migrate old rating data to new format
  Future<void> migrateOldRatings() async {
    try {
      print('Starting rating migration...');
      
      // Get all ratings that have reviewerId but not buyerId
      final oldRatingsQuery = await _ratingsCollection
          .where('reviewerId', isGreaterThan: '')
          .get();

      int migratedCount = 0;
      
      for (var doc in oldRatingsQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Skip if already has buyerId
        if (data.containsKey('buyerId') && data['buyerId'] != null && data['buyerId'] != '') {
          continue;
        }

        // Get reviewer information
        String reviewerId = data['reviewerId'] ?? '';
        if (reviewerId.isEmpty) continue;

        try {
          final reviewerDoc = await _usersCollection.doc(reviewerId).get();
          String buyerName = 'Anonymous User';
          String? buyerProfileImage;

          if (reviewerDoc.exists) {
            final reviewerData = reviewerDoc.data() as Map<String, dynamic>?;
            buyerName = reviewerData?['name'] ?? 
                       reviewerData?['firstName'] ?? 
                       reviewerData?['fullName'] ?? 
                       'Anonymous User';
            buyerProfileImage = reviewerData?['profileImage'];
          }

          // Update the document with new fields
          await doc.reference.update({
            'buyerId': reviewerId,
            'buyerName': buyerName,
            'buyerProfileImage': buyerProfileImage,
            'isVerifiedPurchase': false, // Default for old ratings
            'migrated': true,
            'migratedAt': FieldValue.serverTimestamp(),
          });

          migratedCount++;
          print('Migrated rating ${doc.id}');

        } catch (e) {
          print('Error migrating rating ${doc.id}: $e');
        }
      }

      print('Migration completed. Migrated $migratedCount ratings.');

      // Update all seller rating statistics after migration
      await _updateAllSellerRatings();

    } catch (e) {
      print('Error during migration: $e');
    }
  }

  /// Update all seller ratings statistics
  Future<void> _updateAllSellerRatings() async {
    try {
      // Get all sellers
      final sellersQuery = await _usersCollection
          .where('role', isEqualTo: 'seller')
          .get();

      for (var sellerDoc in sellersQuery.docs) {
        await _updateSellerRating(sellerDoc.id);
      }

      print('Updated all seller ratings');
    } catch (e) {
      print('Error updating all seller ratings: $e');
    }
  }
}