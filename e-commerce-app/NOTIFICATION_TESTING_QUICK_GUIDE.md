# Quick Testing Guide for Notifications

## Step 1: Run the Debug Helper

Add this code temporarily to any screen you're testing (like the notifications screen):

```dart
import '../utils/notification_debug_helper.dart';

// Add this in initState or a button press:
@override
void initState() {
  super.initState();
  _debugNotifications();
}

Future<void> _debugNotifications() async {
  await NotificationDebugHelper.runAllChecks();
}
```

## Step 2: Create Test Notifications

You can add a floating action button to create test notifications:

```dart
floatingActionButton: FloatingActionButton(
  onPressed: () async {
    await NotificationDebugHelper.createTestNotification(
      type: 'product_approved',
      title: 'Test Product Approved',
      message: 'Your test product has been approved by admin',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test notification created!')),
    );
  },
  child: const Icon(Icons.add),
),
```

## Step 3: Manual Firestore Test

Go to Firebase Console and manually create a notification:

### For Seller:
```json
{
  "userId": "YOUR_USER_UID_HERE",
  "type": "product_approved",
  "title": "Product Approved",
  "message": "Your product 'Test Product' has been approved",
  "read": false,
  "timestamp": [Firebase Server Timestamp],
  "productName": "Test Product"
}
```

### For Buyer:
```json
{
  "userId": "YOUR_USER_UID_HERE",
  "type": "order_status",
  "title": "Order Update",
  "message": "Your order has been confirmed",
  "read": false,
  "timestamp": [Firebase Server Timestamp],
  "orderId": "test-order-123"
}
```

## Step 4: Check Your User UID

Add this to get your user UID:

```dart
final user = FirebaseAuth.instance.currentUser;
print('Current User UID: ${user?.uid}');
print('Current User Email: ${user?.email}');
```

## Step 5: Verify Firestore Rules

Make sure your `firestore.rules` allows reading notifications:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /notifications/{notificationId} {
      // Users can read their own notifications
      allow read: if request.auth != null && 
                     request.auth.uid == resource.data.userId;
      
      // Authenticated users can create notifications
      allow write: if request.auth != null;
    }
  }
}
```

## Step 6: Common Issues Checklist

### ❌ No notifications showing?

1. **Check user is logged in:**
   ```dart
   final user = FirebaseAuth.instance.currentUser;
   if (user == null) print('Not logged in!');
   ```

2. **Check notifications exist in Firestore:**
   - Open Firebase Console
   - Navigate to Firestore Database
   - Look for `notifications` collection
   - Verify documents exist with your `userId`

3. **Check the userId matches:**
   ```dart
   // The notification's userId must match the current user's uid
   await NotificationDebugHelper.checkNotifications();
   ```

4. **Check field names:**
   - Notification should have either `timestamp` or `createdAt`
   - Notification should have either `read` or `isRead`
   - The code now handles both variations

5. **Check notification type:**
   - For sellers: Use types like `product_approved`, `checkout_seller`, `order_status`
   - For buyers: Use types like `order_status`, `order_update`, `checkout_buyer`

### ❌ Firestore permission error?

Deploy your rules:
```powershell
firebase deploy --only firestore:rules
```

### ❌ Still not working?

Run the full debug:
```dart
await NotificationDebugHelper.runAllChecks();
```

This will print detailed information about:
- Your user info and role
- All notifications for your account
- Notification types and counts
- Read/unread status

## Expected Output

When notifications are working, you should see:

### Seller Notifications Screen:
- Product approval/rejection notifications
- New order notifications
- Seller account status notifications

### Buyer Account Notifications:
- Order confirmation notifications
- Order status updates
- New product notifications

### Empty State:
If no notifications exist, you'll see a friendly message:
- "No notifications yet"
- Description of what types of notifications will appear

## Quick Test Flow

1. **Log in as seller**
2. **Run**: `await NotificationDebugHelper.createTestNotification(type: 'product_approved', ...)`
3. **Navigate to** Notifications Screen
4. **Verify** notification appears
5. **Tap notification** - should mark as read
6. **Refresh** - read indicator should update

## Still Having Issues?

Share the output from:
```dart
await NotificationDebugHelper.runAllChecks();
```

This will help identify the exact issue!
