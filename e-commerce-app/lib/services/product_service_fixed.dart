import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_manager.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all products
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    try {
      QuerySnapshot querySnapshot =
          await _firestore.collection('products').get();
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting all products: $e');
      return [];
    }
  }

  // Get products by status (pending, approved, rejected)
  Future<List<Map<String, dynamic>>> getProductsByStatus(String status) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('products')
          .where('status', isEqualTo: status)
          .get();

      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting products by status: $e');
      return [];
    }
  }

  // Approve product
  Future<bool> approveProduct(String productId) async {
    try {
      // Get product details first
      DocumentSnapshot productDoc =
          await _firestore.collection('products').doc(productId).get();
      if (!productDoc.exists) return false;

      Map<String, dynamic> productData =
          productDoc.data() as Map<String, dynamic>;
      String productName = productData['name'] ?? 'Product';
      String sellerId = productData['sellerId'] ?? '';

      await _firestore.collection('products').doc(productId).update({
        'status': 'approved',
      });

      // Send approval notification to seller
      if (sellerId.isNotEmpty) {
        await NotificationManager.sendProductApprovalNotification(
          sellerId: sellerId,
          productName: productName,
          isApproved: true,
        );
      }

      // Send new product notification to buyers
      await NotificationManager.sendNewProductNotification(
        productId: productId,
        productName: productName,
        sellerName: productData['sellerName'] ?? 'Seller',
        category: productData['category'] ?? 'General',
      );

      return true;
    } catch (e) {
      print('Error approving product: $e');
      return false;
    }
  }

  // Reject product
  Future<bool> rejectProduct(String productId, {String? reason}) async {
    try {
      // Get product details first
      DocumentSnapshot productDoc =
          await _firestore.collection('products').doc(productId).get();
      if (!productDoc.exists) return false;

      Map<String, dynamic> productData =
          productDoc.data() as Map<String, dynamic>;
      String productName = productData['name'] ?? 'Product';
      String sellerId = productData['sellerId'] ?? '';

      await _firestore.collection('products').doc(productId).update({
        'status': 'rejected',
        'rejectionReason': reason ?? 'Not specified',
      });

      // Send rejection notification to seller
      if (sellerId.isNotEmpty) {
        await NotificationManager.sendProductApprovalNotification(
          sellerId: sellerId,
          productName: productName,
          isApproved: false,
          rejectionReason: reason,
        );
      }

      return true;
    } catch (e) {
      print('Error rejecting product: $e');
      return false;
    }
  }

  // Get product stats
  Future<Map<String, int>> getProductStats() async {
    try {
      QuerySnapshot allProducts = await _firestore.collection('products').get();

      // Fixed the query to properly get count
      AggregateQuerySnapshot activeListingsSnapshot = await _firestore
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .count()
          .get();

      // Handle potentially nullable count with null-aware operator
      int activeListings = activeListingsSnapshot.count ?? 0;

      return {
        'totalProducts': allProducts.docs.length,
        'activeListings': activeListings,
      };
    } catch (e) {
      print('Error getting product stats: $e');
      return {
        'totalProducts': 0,
        'activeListings': 0,
      };
    }
  }

  // Get weekly product activity (for graph)
  Future<Map<String, int>> getWeeklyProductActivity() async {
    try {
      // Get current date
      DateTime now = DateTime.now();

      // Create a map to store data for the last 7 days
      Map<String, int> weeklyActivity = {};

      // Populate map with last 7 days (including today)
      for (int i = 6; i >= 0; i--) {
        DateTime date = now.subtract(Duration(days: i));
        String dateString =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        weeklyActivity[dateString] = 0;
      }

      // Query products created in the last 7 days
      DateTime sevenDaysAgo = now.subtract(const Duration(days: 7));
      QuerySnapshot querySnapshot = await _firestore
          .collection('products')
          .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgo)
          .get();

      // Count products by day
      for (var doc in querySnapshot.docs) {
        if ((doc.data() as Map<String, dynamic>)['createdAt'] != null) {
          DateTime createdAt =
              (doc.data() as Map<String, dynamic>)['createdAt'].toDate();
          String dateString =
              '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          if (weeklyActivity.containsKey(dateString)) {
            weeklyActivity[dateString] = weeklyActivity[dateString]! + 1;
          }
        }
      }

      return weeklyActivity;
    } catch (e) {
      print('Error getting weekly product activity: $e');
      return {};
    }
  }

  // Check for low stock and send notifications
  Future<void> checkLowStockAndNotify() async {
    try {
      QuerySnapshot lowStockProducts = await _firestore
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .where('currentStock', isLessThanOrEqualTo: 10) // Low stock threshold
          .get();

      for (var doc in lowStockProducts.docs) {
        Map<String, dynamic> productData = doc.data() as Map<String, dynamic>;
        String productName = productData['name'] ?? 'Product';
        String sellerId = productData['sellerId'] ?? '';
        int currentStock = productData['currentStock'] ?? 0;

        if (sellerId.isNotEmpty && currentStock > 0) {
          await NotificationManager.sendLowStockNotification(
            sellerId: sellerId,
            productName: productName,
            currentStock: currentStock,
            threshold: 10,
          );
        }
      }
    } catch (e) {
      print('Error checking low stock: $e');
    }
  }

  // Send seasonal farming tips
  static Future<void> sendSeasonalFarmingTip() async {
    try {
      DateTime now = DateTime.now();
      String season = '';
      String tip = '';

      // Determine season and tip based on current month
      switch (now.month) {
        case 3:
        case 4:
        case 5:
          season = 'Spring';
          tip =
              'Spring is perfect for planting tomatoes, peppers, and leafy greens. Ensure soil temperature is above 60°F before planting.';
          break;
        case 6:
        case 7:
        case 8:
          season = 'Summer';
          tip =
              'During summer, ensure regular watering and provide shade for delicate crops. Harvest early morning for best quality.';
          break;
        case 9:
        case 10:
        case 11:
          season = 'Fall';
          tip =
              'Fall is great for root vegetables and winter crops. Start preparing soil for next season and harvest remaining summer crops.';
          break;
        case 12:
        case 1:
        case 2:
          season = 'Winter';
          tip =
              'Winter is time for planning next year\'s crops and maintaining equipment. Consider greenhouse farming for year-round production.';
          break;
      }

      await NotificationManager.sendFarmingTip(
        tip: tip,
        season: season,
      );
    } catch (e) {
      print('Error sending farming tip: $e');
    }
  }
}
