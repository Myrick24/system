# Seller Approval Permission Fix

## Problem
When cooperative users tried to approve or reject new seller applications, they received the following error:

```
Write failed at sellers/n9Jy6cnXnpWI6w5UzpNvsAmTSff2: 
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions., cause=null}
```

## Root Causes

### Issue #1: Missing Field Permissions in Firestore Rules
The Firestore security rules for the `sellers` collection didn't specify which fields cooperatives could update.

### Issue #2: Incorrect Seller Document ID
The code was using the wrong document ID when updating the seller. The `sellerId` parameter passed to the screen was actually the `userId`, but the actual seller document had a different ID. When the code found the seller via fallback query, it stored the data but not the actual document ID.

## Solutions

### Fix #1: Updated Firestore Security Rules

#### For `users` collection (Line 85-88):
**Before:**
```javascript
allow update: if isCoop() && 
                resource.data.cooperativeId == request.auth.uid &&
                request.resource.data.diff(resource.data).affectedKeys()
                  .hasOnly(['status', 'updatedAt']);
```

**After:**
```javascript
allow update: if isCoop() && 
                resource.data.cooperativeId == request.auth.uid &&
                request.resource.data.diff(resource.data).affectedKeys()
                  .hasOnly(['status', 'verified', 'updatedAt']);
```

#### For `sellers` collection (Line 120-123):
**Before:**
```javascript
allow update: if isCoop() && 
                resource.data.cooperativeId == request.auth.uid;
```

**After:**
```javascript
allow update: if isCoop() && 
                resource.data.cooperativeId == request.auth.uid &&
                request.resource.data.diff(resource.data).affectedKeys()
                  .hasOnly(['status', 'verified', 'verifiedAt', 'verifiedBy', 'updatedAt']);
```

### Fix #2: Updated Seller Review Screen Code

Added logic to store and use the actual seller document ID:

**Changes in `seller_review_screen.dart`:**

1. **Added field to store actual seller document ID (Line 27):**
```dart
String? _actualSellerId; // Store the actual seller document ID
```

2. **Updated `_loadSellerData()` to capture actual document ID (Lines 48-69):**
```dart
if (fallbackQuery.docs.isNotEmpty) {
  print('   ✅ Found seller via fallback query');
  final sellerDocFromQuery = fallbackQuery.docs.first;
  setState(() {
    _sellerData = sellerDocFromQuery.data();
    _actualSellerId = sellerDocFromQuery.id; // Store the actual document ID
    _currentStatus = _sellerData?['status'] ?? 'pending';
    _isLoading = false;
  });
  return;
}

setState(() {
  _sellerData = sellerDoc.data();
  _actualSellerId = widget.sellerId; // Store the actual document ID
  _currentStatus = _sellerData?['status'] ?? 'pending';
  _isLoading = false;
});
```

3. **Updated `_updateSellerStatus()` to use correct document ID (Lines 88-95):**
```dart
// Use the actual seller document ID (from fallback query if needed)
final sellerDocId = _actualSellerId ?? widget.sellerId;

print('🔄 Updating seller status to: $newStatus');
print('   Using seller document ID: $sellerDocId');

// Update sellers collection
await _firestore.collection('sellers').doc(sellerDocId).update({
```

### Deployment
The updated Firestore rules were successfully deployed to Firebase:
```bash
firebase deploy --only firestore:rules
```

## Testing
After deploying the fixes, cooperative users should be able to:
1. ✅ View seller applications in the "Sellers" tab
2. ✅ Click on a pending seller to review their details
3. ✅ Click "Approve" or "Reject" buttons
4. ✅ Successfully update seller status without permission errors
5. ✅ See success message confirmation
6. ✅ Seller receives notification about their application status

## Files Modified
1. **firestore.rules** - Added proper field restrictions for both `users` and `sellers` collections
2. **lib/screens/cooperative/seller_review_screen.dart** - Fixed document ID tracking and usage

## Security Considerations
The updated rules still maintain security by:
- ✅ Only allowing cooperatives (role='cooperative') to make updates
- ✅ Only allowing updates to sellers assigned to their cooperative (cooperativeId match)
- ✅ Restricting updates to only specific fields in `users`: `status`, `verified`, `updatedAt`
- ✅ Restricting updates to only specific fields in `sellers`: `status`, `verified`, `verifiedAt`, `verifiedBy`, `updatedAt`
- ✅ Preventing cooperatives from updating other sensitive fields (email, password, role, etc.)

## Summary
The permission errors were caused by two issues:
1. **Firestore rules** not explicitly allowing cooperatives to update necessary fields
2. **Incorrect document ID** being used when the seller was found via fallback query

Both issues have been fixed and deployed.
