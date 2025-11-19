# Cancelled Orders - Quick Reference

## What Was Fixed

When sellers cancelled/declined buyer orders, those orders weren't showing up in the buyer's "My Orders" Cancelled tab.

## Changes Made

### ✅ Fixed Files
1. **notification_detail_screen.dart** - Added buyerId field, buyer notification, and stock restoration
2. **approval_screen.dart** - Ensured buyerId field is set and used for notifications

### ✅ What Now Works
- ✅ All seller decline paths ensure orders have `buyerId` field
- ✅ Buyers receive notifications when orders are cancelled
- ✅ Cancelled orders appear in buyer's "My Orders" Cancelled tab
- ✅ Stock is restored to inventory on all decline paths
- ✅ Backward compatible with old orders (auto-migrates `userId` to `buyerId`)

## How to Test

### Quick Test
1. **As Seller**: Decline a buyer's order (from any screen)
2. **As Buyer**: 
   - Check notifications (should see cancellation notice)
   - Open "My Orders" → "Cancelled" tab
   - Verify order appears with "CANCELLED" status

### Detailed Test Paths
- [ ] Decline from Order Management screen
- [ ] Decline from notification popup
- [ ] Decline from approval screen
- [ ] Verify each sends buyer notification
- [ ] Verify each appears in Cancelled tab
- [ ] Verify stock is restored

## Database Structure

### Order Document (when cancelled)
```json
{
  "orderId": "order_xxx",
  "status": "cancelled",
  "buyerId": "buyer_user_id",
  "userId": "buyer_user_id",
  "declineReason": "Out of stock",
  "declinedAt": "timestamp",
  "productId": "product_xxx",
  "quantity": 5
}
```

### Buyer Query (Cancelled Tab)
```dart
where('buyerId', isEqualTo: currentUserId)
where('status', in: ['cancelled', 'rejected'])
```

## Status Display

| Database Value | Seller View | Buyer View |
|---------------|-------------|------------|
| `'cancelled'` | DECLINED or CANCELLED | CANCELLED |
| `'rejected'`  | REJECTED | REJECTED |

## Key Functions Modified

### notification_detail_screen.dart::_declineOrder()
**Before**: Only updated status
**After**: 
- Updates status to 'cancelled'
- Ensures `buyerId` field exists
- Sends buyer notification
- Restores stock to inventory

### approval_screen.dart::_declineOrder()
**Before**: Used only `userId` for notifications
**After**:
- Ensures `buyerId` field in order update
- Uses `buyerId` (with fallback) for notifications
- Maintains all existing functionality

## Troubleshooting

### Issue: Old orders not showing in Cancelled tab
**Solution**: The fix auto-migrates orders when they're cancelled. Old orders already cancelled need manual migration:
```dart
// Run this query in Firebase Console
orders.where('status', 'in', ['cancelled', 'rejected'])
     .where('buyerId', '==', null)
// Then update each to add: buyerId = userId
```

### Issue: No notification received
**Check**: 
1. Firestore notifications collection
2. User's notification permission
3. Console logs during decline

### Issue: Stock not restored
**Check**: 
1. Product has `currentStock` field
2. Order has `productId` and `quantity` fields
3. Console logs during decline

## Related Documentation
- [CANCELLED_ORDERS_BUYER_VIEW_FIX.md](CANCELLED_ORDERS_BUYER_VIEW_FIX.md) - Detailed implementation
- [STOCK_RETURN_FIX.md](STOCK_RETURN_FIX.md) - Stock restoration on cancellation

## Summary
All seller cancellation paths now properly ensure orders appear in the buyer's Cancelled tab with notifications and stock restoration.
