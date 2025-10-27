# Cooperative Approval System Implementation

## Overview
The e-commerce app has been successfully updated to shift approval responsibilities from the admin to cooperatives. Cooperatives now handle both seller registrations and product approvals since they manage deliveries.

## Changes Made

### 1. Seller Registration (`lib/screens/registration_screen.dart`)

#### Added Cooperative Selection
- **Lines 28-31**: Added cooperative selection variables
  ```dart
  List<Map<String, dynamic>> _cooperatives = []
  String? _selectedCoopId
  String? _selectedCoopName
  bool _loadingCoops = false
  ```

- **Lines 60-85**: Added `_loadCooperatives()` method that fetches all active cooperatives from Firestore

- **Lines 178-189**: Added validation to ensure cooperative is selected before registration

- **Lines 298-301**: Updated seller document to include:
  - `cooperativeId`: Links seller to their chosen cooperative
  - `cooperativeName`: Stores cooperative name for display

- **Lines 309-313**: Updated user document to include `cooperativeId`

- **Lines 315-326**: Changed notification system:
  - **Before**: Sent to `admin_notifications` collection
  - **After**: Sent to `cooperative_notifications` collection with `cooperativeId` field

- **Lines 652-789**: Added comprehensive UI for cooperative selection:
  - Loading state indicator
  - "No cooperatives available" warning
  - Dropdown with cooperative name and email
  - Info message showing selected cooperative
  - Full form validation

### 2. Product Upload (`lib/screens/seller/add_product_screen.dart`)

#### Added Cooperative Selection
- **Lines 23-26**: Added cooperative selection variables (same as registration)

- **Lines 57-124**: Added `initState()` and `_loadSellerCooperative()` method:
  - First checks if seller already has an assigned cooperative
  - If yes, auto-selects that cooperative (read-only)
  - If no, loads all active cooperatives for selection

- **Lines 221-231**: Added validation to ensure cooperative is selected

- **Lines 352-353**: Updated product document to include:
  - `cooperativeId`: Links product to cooperative
  - `cooperativeName`: Stores cooperative name

- **Lines 361-377**: Changed notification system:
  - **Before**: Sent to admin notifications
  - **After**: Sent to `cooperative_notifications` collection
  - Message changed from "admin review" to "cooperative review"

- **Lines 763-904**: Added smart UI for cooperative selection:
  - **If 1 cooperative**: Shows read-only card with cooperative name (auto-assigned)
  - **If multiple cooperatives**: Shows dropdown to select
  - **If no cooperatives**: Shows warning message
  - Loading state during data fetch

### 3. Cooperative Dashboard (`lib/screens/cooperative/coop_dashboard.dart`)

#### Updated Sellers Tab
- **Line 388**: Added filter to show only sellers assigned to this cooperative:
  ```dart
  .where('cooperativeId', isEqualTo: _auth.currentUser?.uid)
  ```

- **Lines 659-703**: Enhanced `_updateSellerStatus()` method:
  - Updates status in both `users` and `sellers` collections
  - Sends notification to seller about approval/rejection via `user_notifications` collection
  - Shows appropriate success/error messages

#### Updated Products Tab  
- **Line 843**: Added filter to show only products assigned to this cooperative:
  ```dart
  .where('cooperativeId', isEqualTo: _auth.currentUser?.uid)
  ```

- **Lines 1164-1215**: Enhanced `_updateProductStatus()` method:
  - Fetches product data to get seller info
  - Updates product status in Firestore
  - Sends notification to seller about product approval/rejection
  - Shows success/error messages

## Workflow Changes

### Before (Admin-Based Approval)
```
1. Farmer registers as seller → Admin notified
2. Admin reviews application → Admin approves/rejects
3. Farmer uploads product → Admin notified
4. Admin reviews product → Admin approves/rejects
5. Admin manages everything
```

### After (Cooperative-Based Approval)
```
1. Farmer registers as seller → Selects cooperative → Coop notified
2. Cooperative reviews application → Coop approves/rejects
3. Farmer uploads product → Product linked to coop → Coop notified
4. Cooperative reviews product → Coop approves/rejects
5. Cooperative manages delivery, payments, and approvals
```

## Database Schema Updates

### Firestore Collections Updated

#### `users` Collection
```javascript
{
  userId: {
    name: String,
    email: String,
    role: 'seller' | 'buyer' | 'cooperative' | 'admin',
    status: 'pending' | 'approved' | 'rejected',
    cooperativeId: String,  // NEW FIELD
    // ... other fields
  }
}
```

#### `sellers` Collection
```javascript
{
  sellerId: {
    fullName: String,
    email: String,
    status: 'pending' | 'approved' | 'rejected',
    cooperativeId: String,    // NEW FIELD
    cooperativeName: String,  // NEW FIELD
    // ... other fields
  }
}
```

#### `products` Collection
```javascript
{
  productId: {
    name: String,
    sellerId: String,
    status: 'pending' | 'approved' | 'rejected',
    cooperativeId: String,    // NEW FIELD
    cooperativeName: String,  // NEW FIELD
    // ... other fields
  }
}
```

#### `cooperative_notifications` Collection (NEW)
```javascript
{
  notificationId: {
    title: String,
    message: String,
    type: 'seller_application' | 'product_approval',
    cooperativeId: String,     // Target cooperative
    sellerId: String,
    productId: String,          // For product notifications
    priority: 'high' | 'medium' | 'low',
    read: Boolean,
    createdAt: Timestamp,
  }
}
```

#### `user_notifications` Collection (UPDATED)
```javascript
{
  notificationId: {
    title: String,
    message: String,
    type: 'seller_status' | 'product_status',
    userId: String,             // Target user (seller)
    productId: String,
    priority: 'high' | 'medium' | 'low',
    read: Boolean,
    createdAt: Timestamp,
  }
}
```

## User Experience

### For Farmers/Sellers

1. **During Registration**:
   - See list of available cooperatives
   - Choose which cooperative will handle their products
   - Submit application to selected cooperative
   - Receive notification when cooperative approves/rejects

2. **When Uploading Products**:
   - Product automatically linked to their assigned cooperative
   - If no cooperative assigned, can select one
   - See cooperative name displayed
   - Receive notification when cooperative approves product

### For Cooperatives

1. **Sellers Tab**:
   - View only sellers assigned to their cooperative
   - See pending applications prominently
   - Click on seller to view details
   - Approve or reject with one tap
   - Seller receives immediate notification

2. **Products Tab**:
   - View only products from their assigned sellers
   - See pending products needing approval
   - Review product details (name, price, description, image)
   - Approve or reject products
   - Seller notified of decision

3. **Dashboard Stats**:
   - Pending sellers count
   - Active/inactive sellers count
   - Pending products count
   - Approved/rejected products count

### For Admin

- Admin role can still access cooperative dashboard for oversight
- Admin doesn't receive seller/product approval notifications
- Admin focuses on system management, not day-to-day approvals

## Notification Flow

### Seller Registration
```
Farmer submits application
    ↓
cooperative_notifications collection
    ↓
Notification to selected cooperative
    ↓
Cooperative approves/rejects
    ↓
user_notifications collection
    ↓
Notification to farmer
```

### Product Upload
```
Seller uploads product
    ↓
cooperative_notifications collection
    ↓
Notification to assigned cooperative
    ↓
Cooperative approves/rejects
    ↓
user_notifications collection
    ↓
Notification to seller
```

## Testing Checklist

### Seller Registration
- [ ] Cooperative dropdown loads all active cooperatives
- [ ] Cannot submit without selecting cooperative
- [ ] Registration saves cooperativeId to both users and sellers collections
- [ ] Notification sent to correct cooperative
- [ ] Seller receives approval/rejection notification

### Product Upload
- [ ] Seller with assigned cooperative sees read-only cooperative card
- [ ] Seller without cooperative sees dropdown
- [ ] Cannot submit product without cooperative
- [ ] Product saves cooperativeId and cooperativeName
- [ ] Notification sent to correct cooperative
- [ ] Seller receives approval/rejection notification

### Cooperative Dashboard
- [ ] Sellers tab shows only sellers assigned to this cooperative
- [ ] Products tab shows only products from assigned sellers
- [ ] Approve button updates status to 'approved'
- [ ] Reject button updates status to 'rejected'
- [ ] Seller receives notification after approval/rejection
- [ ] Stats accurately reflect pending/approved/rejected counts

## Future Enhancements

1. **Multi-Cooperative Support**: Allow sellers to work with multiple cooperatives
2. **Cooperative Ratings**: Let sellers rate cooperatives for better selection
3. **Bulk Approval**: Allow cooperatives to approve multiple items at once
4. **Approval Comments**: Let cooperatives add notes when rejecting
5. **Auto-Assignment**: Automatically assign sellers to nearest cooperative based on location
6. **Reassignment**: Allow admin to reassign sellers to different cooperatives
7. **Cooperative Analytics**: Show cooperative-specific performance metrics

## Important Notes

- All existing sellers without `cooperativeId` will need to be assigned to a cooperative
- Products without `cooperativeId` should be assigned to appropriate cooperatives
- Firestore security rules should be updated to enforce cooperative access controls
- Consider adding indexes for `cooperativeId` fields for better query performance

## Files Modified

1. `lib/screens/registration_screen.dart` - Added cooperative selection to seller registration
2. `lib/screens/seller/add_product_screen.dart` - Added cooperative selection to product upload
3. `lib/screens/cooperative/coop_dashboard.dart` - Updated to filter by cooperativeId and handle approvals

## Summary

This implementation successfully transfers approval authority from admin to cooperatives, aligning with their role in handling deliveries. The system is now more scalable, with each cooperative managing their own sellers and products independently.
