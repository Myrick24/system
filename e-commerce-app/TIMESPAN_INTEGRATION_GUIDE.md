# Timespan Feature - Integration Guide

## 🎯 Overview
This guide explains how to integrate the timespan data into other parts of the application for displaying, calculating, and utilizing shelf life information.

## 📍 What Was Changed
- **File Modified**: `lib/screens/seller/add_product_screen.dart`
- **New State Variables**: 3 (timespan controller, unit selection, unit list)
- **New UI Section**: ~80 lines of code
- **Database Fields Added**: 2 optional fields (timespan, timespanUnit)

---

## 🔌 Integration Points

### 1. Product Details Screen
**File**: `lib/screens/product_details_screen.dart`
**Purpose**: Display product shelf life to buyers

#### Implementation
```dart
// In the product details UI, add after price/quantity info:

if (product['timespan'] != null) {
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.orange.shade200),
    ),
    child: Row(
      children: [
        Icon(Icons.schedule, color: Colors.orange.shade700),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Shelf Life'),
            Text(
              '${product['timespan']} ${product['timespanUnit']}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    ),
  ),
}
```

### 2. Product Browse Screen (Buyer)
**File**: `lib/screens/buyer/buyer_product_browse.dart`
**Purpose**: Show freshness badge on product cards

#### Implementation
```dart
// In the product card widget, add a freshness chip:

if (product['timespan'] != null) {
  Positioned(
    top: 8,
    right: 8,
    child: Chip(
      label: Text(
        'Fresh ${product['timespan']}${product['timespanUnit'] == 'Hours' ? 'h' : 'd'}',
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
      backgroundColor: Colors.orange.shade600,
      avatar: const Icon(Icons.schedule, size: 16, color: Colors.white),
    ),
  )
}
```

### 3. Product Search/Filter
**File**: `lib/services/product_service.dart` or similar
**Purpose**: Filter products by shelf life

#### Implementation
```dart
// Get perishable products (hours-based, high priority)
Future<List<Map<String, dynamic>>> getPerishableProducts() async {
  return await _firestore.collection('products')
    .where('timespanUnit', isEqualTo: 'Hours')
    .where('status', isEqualTo: 'approved')
    .get()
    .then((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
}

// Get all products with timespan defined
Future<List<Map<String, dynamic>>> getTimestampedProducts() async {
  return await _firestore.collection('products')
    .where('timespan', isNotEqualTo: null)
    .where('status', isEqualTo: 'approved')
    .get()
    .then((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
}

// Get long-lasting products (7+ days)
Future<List<Map<String, dynamic>>> getLongLastingProducts() async {
  return await _firestore.collection('products')
    .where('timespanUnit', isEqualTo: 'Days')
    .where('timespan', isGreaterThanOrEqualTo: 7)
    .where('status', isEqualTo: 'approved')
    .get()
    .then((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
}
```

### 4. Freshness Calculation Service
**File**: `lib/services/freshness_service.dart` (new or existing)
**Purpose**: Calculate remaining shelf life from harvest date

#### Implementation
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FreshnessService {
  /// Calculate remaining shelf life in percentage
  /// Returns 0.0 to 1.0 (0% to 100%)
  static double getRemainingFreshnessPercent(
    Map<String, dynamic> product,
  ) {
    if (product['harvestDate'] == null || 
        product['timespan'] == null) {
      return 1.0; // Unknown, assume 100% fresh
    }

    final harvestTime = 
        (product['harvestDate'] as Timestamp).toDate();
    final now = DateTime.now();
    final elapsed = now.difference(harvestTime);

    // Convert timespan to duration
    Duration totalDuration;
    if (product['timespanUnit'] == 'Hours') {
      totalDuration = Duration(hours: product['timespan'] as int);
    } else {
      totalDuration = Duration(days: product['timespan'] as int);
    }

    // Calculate percentage
    final percentage = 1.0 - (elapsed.inSeconds / totalDuration.inSeconds);
    return percentage.clamp(0.0, 1.0);
  }

  /// Get freshness status label
  static String getFreshnessStatus(double percent) {
    if (percent >= 0.75) return 'Very Fresh';
    if (percent >= 0.50) return 'Fresh';
    if (percent >= 0.25) return 'Soon Expiring';
    return 'Expiring Soon!';
  }

  /// Get color based on freshness
  static Color getFreshnessColor(double percent) {
    if (percent >= 0.75) return Colors.green;
    if (percent >= 0.50) return Colors.lightGreen;
    if (percent >= 0.25) return Colors.orange;
    return Colors.red;
  }

  /// Calculate expiry date/time
  static DateTime getExpiryDateTime(
    Map<String, dynamic> product,
  ) {
    if (product['harvestDate'] == null || 
        product['timespan'] == null) {
      return DateTime.now().add(const Duration(days: 365));
    }

    final harvestTime = 
        (product['harvestDate'] as Timestamp).toDate();
    
    if (product['timespanUnit'] == 'Hours') {
      return harvestTime.add(
        Duration(hours: product['timespan'] as int),
      );
    } else {
      return harvestTime.add(
        Duration(days: product['timespan'] as int),
      );
    }
  }

  /// Format time remaining
  static String getTimeRemaining(
    Map<String, dynamic> product,
  ) {
    final expiryTime = getExpiryDateTime(product);
    final now = DateTime.now();
    final remaining = expiryTime.difference(now);

    if (remaining.isNegative) {
      return 'Expired';
    }

    if (remaining.inDays > 0) {
      return '${remaining.inDays} day${remaining.inDays == 1 ? '' : 's'} left';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours} hour${remaining.inHours == 1 ? '' : 's'} left';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes} minute${remaining.inMinutes == 1 ? '' : 's'} left';
    }
    
    return 'Expires today';
  }
}
```

### 5. Freshness Display Widget
**File**: `lib/widgets/freshness_badge.dart` (new)
**Purpose**: Reusable widget for displaying freshness

#### Implementation
```dart
import 'package:flutter/material.dart';
import '../services/freshness_service.dart';

class FreshnessBadge extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool showPercent;

  const FreshnessBadge({
    Key? key,
    required this.product,
    this.showPercent = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (product['timespan'] == null) {
      return const SizedBox.shrink();
    }

    final percent = FreshnessService.getRemainingFreshnessPercent(product);
    final status = FreshnessService.getFreshnessStatus(percent);
    final color = FreshnessService.getFreshnessColor(percent);
    final timeRemaining = FreshnessService.getTimeRemaining(product);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, color: color, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              Text(
                timeRemaining,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          if (showPercent) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 30,
              height: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

### 6. Seller Dashboard
**File**: `lib/screens/seller/seller_dashboard.dart`
**Purpose**: Show products by freshness status

#### Implementation
```dart
// Add section to seller dashboard:

// Expiring Soon Alert
StreamBuilder<QuerySnapshot>(
  stream: _firestore.collection('products')
    .where('sellerId', isEqualTo: currentUser.uid)
    .where('timespan', isNotEqualTo: null)
    .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const SizedBox();
    
    final products = snapshot.data!.docs.map((doc) => 
      doc.data() as Map<String, dynamic>
    ).toList();

    // Filter products expiring within 2 days
    final expiringProducts = products.where((p) {
      final remaining = FreshnessService.getTimeRemaining(p);
      return remaining.contains('day') || remaining.contains('hour');
    }).toList();

    if (expiringProducts.isEmpty) {
      return const SizedBox();
    }

    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  '${expiringProducts.length} Products Expiring Soon',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...expiringProducts.map((product) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${product['name']} - ${FreshnessService.getTimeRemaining(product)}',
                style: const TextStyle(fontSize: 13),
              ),
            )),
          ],
        ),
      ),
    );
  },
)
```

### 7. Cart/Order Summary
**File**: `lib/screens/checkout_screen.dart`
**Purpose**: Show freshness info in order review

#### Implementation
```dart
// In order items list, show freshness:

ListTile(
  title: Text(product['name']),
  subtitle: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (product['timespan'] != null)
        Text(
          'Fresh for ${product['timespan']} ${product['timespanUnit']}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.orange.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      Text('₱${product['price']} x ${item['quantity']}'),
    ],
  ),
  trailing: Text('₱${total.toStringAsFixed(2)}'),
)
```

---

## 📊 Data Flow with Timespan

```
Seller Creates Product
        ↓
Enters Timespan (e.g., 7 Days)
        ↓
Product Saved with:
  - timespan: 7
  - timespanUnit: "Days"
  - harvestDate: timestamp
        ↓
Cooperative Approves
        ↓
Product Published
        ↓
Buyer Sees Product
  - Display: "Fresh for 7 Days"
  - Badge: Shows freshness status
        ↓
Buyer Purchases
        ↓
Order Shows:
  - Product timespan info
  - Expiry guidance
        ↓
Time Passes
        ↓
FreshnessService Calculates:
  - Percent remaining (0-100%)
  - Time remaining
  - Status (Fresh/Expiring/Expired)
        ↓
Dashboard Alerts Seller:
  - "Expiring Soon" products
  - Suggest discounts
```

---

## 🔧 Utility Functions

### Helper Function: Format Freshness
```dart
String formatTimespanDisplay(int? timespan, String? unit) {
  if (timespan == null || unit == null) {
    return 'Non-perishable';
  }
  
  if (unit == 'Hours') {
    if (timespan == 24) return 'Fresh for 1 day';
    if (timespan < 24) return 'Fresh for $timespan hours';
    return 'Fresh for ${(timespan / 24).toStringAsFixed(1)} days';
  } else {
    if (timespan == 1) return 'Fresh for 1 day';
    return 'Fresh for $timespan days';
  }
}
```

### Helper Function: Get Timespan in Hours
```dart
int getTimespanInHours(int? timespan, String? unit) {
  if (timespan == null) return 0;
  
  if (unit == 'Hours') {
    return timespan;
  } else if (unit == 'Days') {
    return timespan * 24;
  }
  return 0;
}
```

---

## ✅ Integration Checklist

- [ ] Added timespan display to product details screen
- [ ] Added freshness badge to product browse cards
- [ ] Created FreshnessService with calculation methods
- [ ] Created FreshnessBadge reusable widget
- [ ] Added expiring soon alert to seller dashboard
- [ ] Updated cart/checkout to show timespan
- [ ] Added freshness filter to product search
- [ ] Tested freshness calculations with various timespans
- [ ] Verified Firestore queries work correctly
- [ ] Updated product filters/sorting

---

## 🚀 Deployment Order

### Phase 1 (Immediate)
1. ✅ Timespan input in add product screen (DONE)
2. ✅ Save timespan to Firestore (DONE)
3. ⏳ Display timespan on product details

### Phase 2 (Week 1)
4. ⏳ Show freshness badge on product cards
5. ⏳ Create FreshnessService
6. ⏳ Create FreshnessBadge widget

### Phase 3 (Week 2)
7. ⏳ Add seller alerts (expiring soon)
8. ⏳ Show timespan in cart/checkout
9. ⏳ Add freshness filters

### Phase 4 (Future)
10. ⏳ Auto-discount near-expiry products
11. ⏳ Buyer notifications
12. ⏳ Advanced analytics

---

## 📚 Related Files

- `lib/screens/seller/add_product_screen.dart` - Timespan input
- `lib/screens/product_details_screen.dart` - (to be updated)
- `lib/screens/buyer/buyer_product_browse.dart` - (to be updated)
- `lib/services/freshness_service.dart` - (to be created)
- `lib/widgets/freshness_badge.dart` - (to be created)
- `TIMESPAN_FEATURE_IMPLEMENTATION.md` - Feature documentation
- `TIMESPAN_QUICK_REFERENCE.md` - Quick reference
- `TIMESPAN_VISUAL_GUIDE.md` - Visual examples

---

## 🐛 Troubleshooting

### Issue: Timespan not displaying
**Check**: Verify `timespan` field exists in Firestore
**Solution**: Recreate product with timespan filled in

### Issue: Calculations off
**Check**: Verify harvestDate is saved as Timestamp
**Solution**: Use `.toDate()` when reading from Firestore

### Issue: Widget not updating
**Check**: Verify StreamBuilder is watching correct field
**Solution**: Add `.snapshots()` to Firestore query

---

**Integration Guide Status**: ✅ Ready for implementation
