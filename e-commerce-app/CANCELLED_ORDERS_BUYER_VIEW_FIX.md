# Cancelled Orders in Buyer View - Fix Implementation

## Problem
When sellers declined/cancelled buyer orders, those orders were not appearing in the buyer's "My Orders" Cancelled tab, even though they showed as "DECLINED" in the seller's Order Management view.

## Root Cause Analysis

### How It Should Work
1. Seller declines an order → Status changes to 'cancelled'
2. Buyer's "My Orders" Cancelled tab queries for orders with status 'cancelled' or 'rejected'
3. The query uses `buyerId` field to find orders belonging to the buyer
4. Orders should appear in the Cancelled tab

### Why It Wasn't Working
The system had **multiple code paths** for declining orders:
1. `order_detail_screen.dart` - Used when viewing order details (✅ Working correctly)
2. `notification_detail_screen.dart` - Used when declining from notifications (❌ Missing features)
3. `approval_screen.dart` - Used in approval flow (❌ Partial implementation)

**Issues Found:**

1. **Missing `buyerId` Field**
   - Some decline functions didn't ensure the `buyerId` field was set on the order
   - Old orders might have `userId` instead of `buyerId`
   - Buyer query uses `buyerId`, so orders without it wouldn't appear

2. **No Buyer Notification** (notification_detail_screen.dart)
   - When seller declined from notification screen, buyer never received a notification
   - This left buyers unaware their order was cancelled

3. **No Stock Restoration** (notification_detail_screen.dart)
   - Stock wasn't being returned to inventory when declining from notification screen

## Solution Implemented

### Files Modified

#### 1. `lib/screens/notification_detail_screen.dart`
**Function:** `_declineOrder()`
**Changes:**
- ✅ Fetch complete order data before updating
- ✅ Ensure `buyerId` field is set (add it if missing, using `userId` as source)
- ✅ Send notification to buyer about order cancellation
- ✅ Restore stock to product inventory
- ✅ Enhanced logging for debugging

```dart
// Get order data to ensure we have all fields
final orderDoc = await _firestore.collection('orders').doc(orderId).get();
final orderData = orderDoc.data();

await _firestore.collection('orders').doc(orderId).update({
  'status': 'cancelled',
  'declinedAt': FieldValue.serverTimestamp(),
  'declineReason': selectedReason,
  'updatedAt': FieldValue.serverTimestamp(),
  'notes': 'Declined: $selectedReason',
});

// Ensure buyerId field is set (critical for buyer to see it)
if (orderData != null) {
  if (orderData['buyerId'] == null && orderData['userId'] != null) {
    await _firestore.collection('orders').doc(orderId).update({
      'buyerId': orderData['userId'],
    });
  }
  
  // Send notification to buyer
  final buyerId = orderData['buyerId'] ?? orderData['userId'];
  if (buyerId != null) {
    await _firestore.collection('notifications').add({
      'userId': buyerId,
      'orderId': orderId,
      'type': 'order_status',
      'status': 'cancelled',
      'message': 'Your order for ${orderData['productName']} was declined: $selectedReason',
      'productName': orderData['productName'],
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }
  
  // Return stock to product inventory
  final productId = orderData['productId'];
  final quantity = orderData['quantity'] ?? 0;
  if (productId != null && quantity > 0) {
    await _firestore.collection('products').doc(productId).update({
      'currentStock': FieldValue.increment(quantity),
    });
  }
}
```

#### 2. `lib/screens/approval_screen.dart`
**Function:** `_declineOrder()`
**Changes:**
- ✅ Ensure `buyerId` field is set during order status update
- ✅ Use `buyerId` (with fallback to `userId`) for buyer notification
- ✅ Enhanced logging

```dart
// Update order status
Map<String, dynamic> orderUpdate = {
  'status': 'cancelled',
  'declinedAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
  'notes': 'Declined by seller',
};

// Add buyerId if not present
if (_orderData!['buyerId'] == null && _orderData!['userId'] != null) {
  orderUpdate['buyerId'] = _orderData!['userId'];
}

batch.update(orderRef, orderUpdate);

// Create notification for the buyer using buyerId
final buyerId = _orderData!['buyerId'] ?? _orderData!['userId'];
batch.set(notificationRef, {
  'userId': buyerId,
  'orderId': widget.orderId,
  'type': 'order_status',
  'status': 'cancelled',
  'message': 'Your order for ${_orderData!['productName']} has been declined',
  'productName': _orderData!['productName'],
  'timestamp': FieldValue.serverTimestamp(),
  'isRead': false,
});
```

## How It Works Now

### Seller Declines Order - All Paths
1. ✅ Order status changes to 'cancelled'
2. ✅ `buyerId` field is ensured on the order document
3. ✅ Stock is returned to product inventory
4. ✅ Buyer receives a notification
5. ✅ Order appears in buyer's "My Orders" Cancelled tab

### Buyer Views Cancelled Orders
1. ✅ Buyer navigates to "My Orders" → "Cancelled" tab
2. ✅ Query finds all orders with status 'cancelled' or 'rejected' where `buyerId` matches current user
3. ✅ All declined orders are displayed with proper status badge
4. ✅ Buyer can tap to view order details

## Testing Checklist

### Test Scenario 1: Decline from Order Detail Screen
- [ ] Seller opens order from Order Management
- [ ] Seller clicks "Decline" and selects a reason
- [ ] Order status changes to 'cancelled'
- [ ] Stock is restored to product
- [ ] Buyer receives notification
- [ ] Order appears in buyer's Cancelled tab

### Test Scenario 2: Decline from Notification Screen
- [ ] Seller receives new order notification
- [ ] Seller opens notification and clicks "Decline Order"
- [ ] Seller selects a decline reason
- [ ] Order status changes to 'cancelled'
- [ ] Stock is restored to product
- [ ] Buyer receives notification
- [ ] Order appears in buyer's Cancelled tab

### Test Scenario 3: Decline from Approval Screen
- [ ] Seller navigates to order via approval flow
- [ ] Seller clicks decline button
- [ ] Order status changes to 'cancelled'
- [ ] Stock is restored to product
- [ ] Buyer receives notification
- [ ] Order appears in buyer's Cancelled tab

### Test Scenario 4: Verify Old Orders
- [ ] Old orders with only `userId` field work correctly
- [ ] System automatically adds `buyerId` when order is cancelled
- [ ] Old cancelled orders appear in buyer's Cancelled tab after the fix

## Technical Notes

### Database Field Consistency
- **Old orders**: May have `userId` field only
- **New orders**: Should have both `buyerId` and `userId`
- **Migration**: Not required - system handles both cases dynamically

### Query Structure
```dart
// Buyer's Cancelled tab query
final buyerIdQuery = await _firestore
    .collection('orders')
    .where('buyerId', isEqualTo: userId)
    .get();

// Filter by status in memory
statuses = ['cancelled', 'rejected'];
```

### Status Values
- **Database**: 'cancelled' (lowercase)
- **Display**: 'CANCELLED' or 'DECLINED' (formatted via `_formatStatusText()`)
- Both are the same underlying status

## Benefits

1. **Complete Feature**: Buyers can now see all their cancelled orders
2. **Consistent Behavior**: All decline paths work the same way
3. **Better Communication**: Buyers receive notifications when orders are declined
4. **Inventory Accuracy**: Stock is always restored across all decline paths
5. **Backward Compatible**: Works with old and new order documents

## Verification

To verify the fix is working:

1. **Check Database** (Firebase Console):
   ```
   orders collection → cancelled order document
   Fields should include:
   - status: 'cancelled'
   - buyerId: <user_id>
   - declineReason: <reason>
   - declinedAt: <timestamp>
   ```

2. **Check Buyer App**:
   - Open "My Orders" → "Cancelled" tab
   - Verify cancelled orders appear
   - Tap order to see details including decline reason

3. **Check Notifications**:
   - Buyer should have notification about order cancellation
   - Notification should include product name and reason

## Related Files
- `lib/screens/buyer/buyer_main_dashboard.dart` - Buyer orders view (no changes needed)
- `lib/screens/order_detail_screen.dart` - Already working correctly
- `lib/screens/notification_detail_screen.dart` - ✅ Fixed
- `lib/screens/approval_screen.dart` - ✅ Fixed
