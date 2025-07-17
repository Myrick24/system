# 🧪 Push Notifications Testing Guide

## Quick Start Testing

### 1. Add Test Button to Any Screen
Add this import and button to any screen in your app:

```dart
import '../widgets/notification_test_button.dart';

// In your build method, add:
const NotificationTestButton(),
```

### 2. Use the Dedicated Test Screen
Navigate to the test screen from anywhere in your app:

```dart
Navigator.pushNamed(context, '/notification-test');
```

### 3. Direct Testing in Code
Import the test helper and call methods directly:

```dart
import '../utils/notification_test_helper.dart';

// Test different notification types
await NotificationTestHelper.testWelcomeNotification();
await NotificationTestHelper.testOrderNotification();
await NotificationTestHelper.testProductNotification();
```

## 📱 Testing Scenarios

### Scenario 1: User Registration
When a user signs up, test the welcome notification:
```dart
await NotificationManager.sendWelcomeNotification(
  userId: newUser.uid,
  userName: newUser.displayName ?? 'New User',
  userRole: 'farmer', // or 'buyer', 'cooperative'
);
```

### Scenario 2: Order Status Updates
Test order notifications with different statuses:
```dart
await NotificationManager.sendOrderUpdateNotification(
  userId: buyerId,
  orderId: 'ORDER_001',
  status: 'Processing', // 'Shipped', 'Delivered', 'Cancelled'
  customerName: 'John Doe',
);
```

### Scenario 3: New Product Alerts
Test when sellers add new products:
```dart
await NotificationManager.sendNewProductNotification(
  productId: 'PROD_001',
  productName: 'Fresh Organic Tomatoes',
  sellerName: 'Green Farm Co.',
  category: 'vegetables',
);
```

### Scenario 4: Payment Confirmations
Test payment notifications:
```dart
await NotificationManager.sendPaymentNotification(
  userId: userId,
  orderId: 'ORDER_001',
  amount: 45.99,
  isReceived: true, // true for seller, false for buyer
);
```

### Scenario 5: Product Approval (Admin)
Test admin approval notifications:
```dart
await NotificationManager.sendProductApprovalNotification(
  userId: sellerId,
  productId: 'PROD_001',
  productName: 'Organic Apples',
  isApproved: true, // or false for rejection
  adminMessage: 'Product meets quality standards',
);
```

### Scenario 6: Low Stock Alerts
Test inventory notifications:
```dart
await NotificationManager.sendLowStockNotification(
  userId: sellerId,
  productId: 'PROD_001',
  productName: 'Organic Tomatoes',
  currentStock: 5,
  threshold: 10,
);
```

### Scenario 7: Announcements
Test broadcast messages:
```dart
await NotificationManager.sendAnnouncement(
  title: 'New Feature Available',
  message: 'Check out our new delivery tracking feature!',
  targetRole: 'all', // 'farmer', 'buyer', 'cooperative'
);
```

### Scenario 8: Farming Tips
Test educational content:
```dart
await NotificationManager.sendFarmingTip(
  tip: 'Plant your seeds 2 inches deep for optimal growth.',
  season: 'spring', // optional: 'summer', 'fall', 'winter'
);
```

### Scenario 9: Market Price Updates
Test market information:
```dart
await NotificationManager.sendMarketPriceUpdate(
  productName: 'Tomatoes',
  newPrice: 3.50,
  oldPrice: 3.00,
  trend: 'up', // 'down', 'stable'
);
```

## 🔧 Testing Setup Requirements

### 1. User Authentication
Many notifications require a logged-in user:
```dart
// Ensure user is signed in
final user = FirebaseAuth.instance.currentUser;
if (user == null) {
  // Sign in user first or use test user ID
}
```

### 2. Firestore Permissions
Ensure your Firestore rules allow writing to the notifications collection:
```javascript
// In firestore.rules
match /notifications/{notificationId} {
  allow read, write: if request.auth != null;
}

match /users/{userId}/notifications/{notificationId} {
  allow read, write: if request.auth != null;
}
```

### 3. FCM Token Generation
The app needs to generate an FCM token:
```dart
// Check if token exists
final token = await PushNotificationService.getCurrentToken();
print('FCM Token: $token');
```

## 📋 Testing Checklist

### ✅ Basic Functionality
- [ ] App generates FCM token
- [ ] Notifications permission granted
- [ ] Firebase connection working
- [ ] Can send test notification

### ✅ Notification Types
- [ ] Welcome notifications
- [ ] Order update notifications
- [ ] New product notifications
- [ ] Payment notifications
- [ ] Admin approval notifications
- [ ] Low stock notifications
- [ ] Announcements
- [ ] Farming tips
- [ ] Market price updates

### ✅ Targeting
- [ ] Individual user notifications
- [ ] Role-based notifications (farmer, buyer, cooperative)
- [ ] Topic-based notifications
- [ ] Broadcast notifications (all users)

### ✅ Data Storage
- [ ] Notifications saved to Firestore
- [ ] User-specific notification collections
- [ ] Notification read/unread status
- [ ] Notification history accessible

### ✅ UI Components
- [ ] Notification list screen shows notifications
- [ ] Test screen functions properly
- [ ] Settings screen (if implemented)
- [ ] Notification badges/counters

## 🚨 Common Testing Issues

### Issue 1: No FCM Token
**Problem**: `getCurrentToken()` returns null
**Solution**: 
- Check Firebase configuration
- Ensure internet connection
- Verify app permissions

### Issue 2: Notifications Not Received
**Problem**: Notifications sent but not received
**Solution**:
- Check device notification settings
- Verify FCM token is valid
- Check Firestore rules
- Test with different notification types

### Issue 3: User Not Found
**Problem**: Error when sending to specific user
**Solution**:
- Ensure user is authenticated
- Check userId is correct
- Verify user document exists in Firestore

### Issue 4: Permission Denied
**Problem**: Firestore permission errors
**Solution**:
- Update Firestore rules
- Ensure user is authenticated
- Check collection paths are correct

## 🎯 Next Steps After Testing

1. **Integrate into Business Logic**: Add notification calls to your app's workflows
2. **Server-Side Setup**: Implement backend notification sending
3. **Production Configuration**: Set up production Firebase project
4. **Analytics**: Add notification tracking and analytics
5. **Rich Features**: Consider adding images, actions, or custom sounds

The notification system is fully functional and ready for comprehensive testing!
