# Seller Rating and Review System Guide

This guide explains how to implement and use the comprehensive seller rating and review system in your e-commerce Flutter app.

## Overview

The rating system consists of:
- **Rating Model**: Structured data representation
- **Rating Service**: Business logic for rating operations
- **Rating Widgets**: Reusable UI components
- **Rating Dialog**: Interactive rating interface
- **Firestore Integration**: Real-time data synchronization

## Collection Structure

### 1. `seller_ratings` Collection

Each document contains:
```dart
{
  'id': String,                    // Document ID
  'sellerId': String,              // Seller's user ID
  'buyerId': String,               // Buyer's user ID
  'buyerName': String,             // Buyer's display name
  'buyerProfileImage': String?,    // Optional profile image URL
  'rating': double,                // Rating value (1-5)
  'review': String?,               // Optional review text
  'createdAt': Timestamp,          // Creation date
  'updatedAt': Timestamp,          // Last update date
  'isVerifiedPurchase': bool,      // Whether buyer purchased from seller
  'productId': String?,            // Optional: specific product rated
  'productName': String?,          // Optional: product name
}
```

### 2. `users` Collection Updates

Seller documents automatically get updated with:
```dart
{
  'rating': double,                    // Average rating
  'totalReviews': int,                 // Total number of reviews
  'ratingDistribution': Map<int, int>, // {1: count, 2: count, ...}
  'verifiedPurchasesCount': int,       // Number of verified purchase reviews
  'lastRatingUpdate': Timestamp,       // Last time ratings were updated
}
```

### 3. `review_reports` Collection

For reporting inappropriate reviews:
```dart
{
  'ratingId': String,              // ID of reported rating
  'reportedBy': String,            // Reporter's user ID
  'reason': String,                // Report reason
  'createdAt': Timestamp,          // Report creation date
  'status': String,                // 'pending', 'reviewed', 'resolved'
}
```

## Implementation Steps

### 1. File Structure

```
lib/
├── models/
│   └── rating_model.dart           # Rating data model
├── services/
│   └── rating_service.dart         # Rating business logic
├── widgets/
│   ├── rating_widgets.dart         # Reusable rating UI components
│   └── rating_dialog.dart          # Rating input dialog
└── screens/
    └── buyer/
        └── seller_details_screen.dart  # Updated with rating integration
```

### 2. Firestore Rules

The system includes comprehensive security rules:

```javascript
// Seller Ratings collection
match /seller_ratings/{ratingId} {
  // Anyone can read ratings (public reviews)
  allow read: if true;
  
  // Only authenticated users can create ratings for themselves
  allow create: if request.auth != null && 
    request.resource.data.buyerId == request.auth.uid;
  
  // Users can update/delete their own ratings
  allow update, delete: if request.auth != null && 
    resource.data.buyerId == request.auth.uid;
    
  // Admins can manage all ratings
  allow read, write: if request.auth != null && isAdmin();
}

// Review Reports collection
match /review_reports/{reportId} {
  // Users can create reports
  allow create: if request.auth != null && 
    request.resource.data.reportedBy == request.auth.uid;
    
  // Only admins can read and manage reports
  allow read, write: if request.auth != null && isAdmin();
}
```

## Usage Examples

### 1. Display Rating in Seller Profile

```dart
// Simple star rating display
RatingWidget(
  rating: seller.averageRating,
  size: 20,
  showText: true,
)

// Rating distribution chart
RatingDistributionWidget(
  stats: sellerRatingStats,
)
```

### 2. Show Rating Dialog

```dart
// Show rating dialog
await showRatingDialog(
  context: context,
  sellerId: sellerId,
  sellerName: sellerName,
  existingRating: userCurrentRating, // null for new rating
  productId: productId,              // optional
  productName: productName,          // optional
);
```

### 3. Load Seller Ratings

```dart
// Get rating statistics
final stats = await ratingService.getSellerRatingStats(sellerId);

// Stream real-time ratings
StreamBuilder<List<Rating>>(
  stream: ratingService.getSellerRatings(sellerId),
  builder: (context, snapshot) {
    final ratings = snapshot.data ?? [];
    return ListView.builder(
      itemCount: ratings.length,
      itemBuilder: (context, index) {
        return ReviewCard(rating: ratings[index]);
      },
    );
  },
)
```

### 4. Check User's Rating

```dart
// Check if user has already rated this seller
final userRating = await ratingService.getUserRatingForSeller(sellerId);
if (userRating != null) {
  // User has already rated, show edit option
} else {
  // Show rate option
}
```

## Key Features

### 1. Verified Purchase Detection
- Automatically checks if the reviewer actually purchased from the seller
- Uses the `transactions` collection to verify purchases
- Displays verified purchase badge on reviews

### 2. Rating Statistics
- Real-time calculation of average ratings
- Rating distribution (1-5 star breakdown)
- Total review count
- Verified purchase count

### 3. Review Management
- Users can add, edit, or delete their own reviews
- Report inappropriate reviews
- Admin moderation capabilities

### 4. Real-time Updates
- Uses Firestore streams for live updates
- Automatic recalculation of seller statistics
- Instant UI updates when ratings change

### 5. Responsive UI Components
- Reusable rating widgets
- Interactive star rating input
- Professional review cards
- Rating distribution charts

## Best Practices

### 1. Performance Optimization
```dart
// Use pagination for large review lists
final ratings = await ratingService.getSellerRatingsPaginated(
  sellerId: sellerId,
  lastDocument: lastDoc,
  limit: 10,
);
```

### 2. Error Handling
```dart
try {
  await ratingService.addOrUpdateRating(/* ... */);
  showSuccessMessage();
} catch (e) {
  showErrorMessage('Failed to submit rating: $e');
}
```

### 3. Loading States
```dart
// Show loading while fetching ratings
if (isLoading) {
  return Center(child: CircularProgressIndicator());
}
```

## Customization Options

### 1. Rating Widget Customization
```dart
RatingWidget(
  rating: 4.5,
  size: 24,
  activeColor: Colors.amber,
  inactiveColor: Colors.grey,
  showText: true,
  customText: 'Excellent',
)
```

### 2. Review Card Customization
```dart
ReviewCard(
  rating: rating,
  showProductInfo: true,  // Show which product was rated
  onReport: () {
    // Custom report handling
  },
)
```

### 3. Dialog Customization
The rating dialog automatically adapts to:
- New ratings vs. editing existing ratings
- Product-specific ratings
- Verified purchase indicators

## Testing the System

### 1. Test Rating Creation
1. Login as a buyer
2. Navigate to a seller's profile
3. Click "Rate Seller"
4. Select stars and write a review
5. Submit rating

### 2. Test Rating Updates
1. Rate a seller
2. Navigate back to seller profile
3. Click "Update Rating"
4. Modify rating and review
5. Save changes

### 3. Test Real-time Updates
1. Open seller profile in two browser tabs
2. Add a rating in one tab
3. Verify it appears immediately in the other tab

### 4. Test Verified Purchases
1. Complete a purchase transaction
2. Rate the seller
3. Verify the review shows "verified purchase" badge

## Troubleshooting

### Common Issues

1. **Ratings not appearing**: Check Firestore rules and authentication
2. **Permission denied**: Ensure user is authenticated and rules are deployed
3. **Real-time updates not working**: Check Firestore connection and streams
4. **Verified purchase not detected**: Verify transactions collection structure

### Debug Commands
```dart
// Check rating service connection
final stats = await ratingService.getSellerRatingStats(sellerId);
print('Rating stats: $stats');

// Check user authentication
final user = FirebaseAuth.instance.currentUser;
print('Current user: ${user?.uid}');
```

This comprehensive rating system provides a robust foundation for seller reviews in your e-commerce app, with real-time updates, verified purchases, and professional UI components.