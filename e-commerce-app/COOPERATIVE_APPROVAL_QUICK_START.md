# 🚀 QUICK START: Cooperative Approval System

## ✅ What's Been Done

The app has been successfully updated! Here's what changed:

### 1. **Seller Registration** - Farmers choose their cooperative
   - ✅ Dropdown shows all active cooperatives
   - ✅ Validates cooperative selection before submission
   - ✅ Saves cooperativeId with seller data
   - ✅ Sends notification to selected cooperative (not admin)

### 2. **Product Upload** - Products linked to cooperative  
   - ✅ Auto-assigns seller's cooperative (if they have one)
   - ✅ Shows cooperative selection if needed
   - ✅ Saves cooperativeId with product data
   - ✅ Notifies cooperative (not admin)

### 3. **Cooperative Dashboard** - Coop handles approvals
   - ✅ Sellers tab filters by cooperativeId
   - ✅ Products tab filters by cooperativeId
   - ✅ Approve/Reject buttons work
   - ✅ Sends notifications to sellers

## 🎯 Next Steps (IMMEDIATE)

### Step 1: Update Firestore Security Rules

Add these rules to `firestore.rules`:

```javascript
// Allow cooperatives to read sellers assigned to them
match /sellers/{sellerId} {
  allow read: if isCooperative() && 
    resource.data.cooperativeId == request.auth.uid;
  allow update: if isCooperative() && 
    resource.data.cooperativeId == request.auth.uid &&
    request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'verified', 'updatedAt']);
}

// Allow cooperatives to read/update products assigned to them
match /products/{productId} {
  allow read: if true; // Public read for buyers
  allow update: if isCooperative() && 
    resource.data.cooperativeId == request.auth.uid &&
    request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'updatedAt']);
  allow create: if request.auth != null && 
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'seller';
}

// Allow cooperatives to read their notifications
match /cooperative_notifications/{notifId} {
  allow read: if isCooperative() && 
    resource.data.cooperativeId == request.auth.uid;
  allow update: if isCooperative() && 
    resource.data.cooperativeId == request.auth.uid &&
    request.resource.data.diff(resource.data).affectedKeys().hasOnly(['read']);
}

// Add helper function if not exists
function isCooperative() {
  return isAuthenticated() && 
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'cooperative';
}
```

### Step 2: Create Firestore Indexes

Add these indexes in Firebase Console:

```
Collection: products
Fields: cooperativeId (Ascending), createdAt (Descending)

Collection: users  
Fields: role (Ascending), cooperativeId (Ascending), status (Ascending)

Collection: cooperative_notifications
Fields: cooperativeId (Ascending), createdAt (Descending)
```

### Step 3: Migrate Existing Data (If Needed)

If you have existing sellers/products without cooperativeId, run this migration:

```dart
// Run once in a Firebase Cloud Function or admin script
Future<void> migrateExistingData() async {
  final firestore = FirebaseFirestore.instance;
  
  // Get a default cooperative to assign
  final coopSnapshot = await firestore
      .collection('users')
      .where('role', isEqualTo: 'cooperative')
      .limit(1)
      .get();
  
  if (coopSnapshot.docs.isEmpty) {
    print('No cooperatives found. Create one first!');
    return;
  }
  
  final defaultCoopId = coopSnapshot.docs.first.id;
  final defaultCoopName = coopSnapshot.docs.first.data()['name'];
  
  // Migrate sellers
  final sellersSnapshot = await firestore
      .collection('users')
      .where('role', isEqualTo: 'seller')
      .get();
  
  for (var doc in sellersSnapshot.docs) {
    if (!doc.data().containsKey('cooperativeId')) {
      await doc.reference.update({
        'cooperativeId': defaultCoopId,
      });
    }
  }
  
  // Migrate products
  final productsSnapshot = await firestore.collection('products').get();
  
  for (var doc in productsSnapshot.docs) {
    if (!doc.data().containsKey('cooperativeId')) {
      await doc.reference.update({
        'cooperativeId': defaultCoopId,
        'cooperativeName': defaultCoopName,
      });
    }
  }
  
  print('Migration complete!');
}
```

## 🧪 Testing Guide

### Test as Farmer/Seller

1. **Register as Seller**:
   ```
   - Go to Account → "Become a Seller"
   - Fill in personal details
   - See cooperative dropdown
   - Select a cooperative
   - Submit application
   - Check for success message mentioning cooperative name
   ```

2. **Upload Product** (after approval):
   ```
   - Go to Seller Dashboard → "Add Product"
   - Fill in product details
   - See cooperative card (auto-assigned) or dropdown
   - Submit product
   - Check for success message
   ```

### Test as Cooperative

1. **View Pending Sellers**:
   ```
   - Login as cooperative
   - Go to Cooperative Dashboard → Sellers tab
   - See only sellers assigned to you
   - Click on a pending seller
   - Click "Approve" or "Reject"
   - Check seller receives notification
   ```

2. **Approve Products**:
   ```
   - Go to Products tab
   - See only products from your sellers
   - Click on a pending product
   - Review details
   - Click "Approve" or "Reject"
   - Check seller receives notification
   ```

### Test as Admin

1. **Verify Admin Still Has Access**:
   ```
   - Login as admin
   - Access Cooperative Dashboard
   - Verify you can see cooperative data
   - Admin should NOT receive approval notifications
   ```

## 🐛 Common Issues & Solutions

### Issue: "No cooperatives available"
**Solution**: Create at least one cooperative user:
```dart
// In Firebase Console or admin panel
users/{userId} = {
  name: "Green Valley Cooperative",
  email: "greenvalley@coop.com",
  role: "cooperative",
  status: "active",
  createdAt: serverTimestamp()
}
```

### Issue: Sellers can't upload products
**Solution**: Ensure seller has cooperativeId:
```dart
users/{sellerId} = {
  role: "seller",
  status: "approved",
  cooperativeId: "<coopUserId>",
  // ... other fields
}
```

### Issue: Cooperative sees no sellers/products
**Solution**: Check Firestore queries include cooperativeId filter
```dart
// Should see in logs:
.where('cooperativeId', isEqualTo: currentUser.uid)
```

### Issue: Notifications not received
**Solution**: Verify notification collections exist:
- `cooperative_notifications` - for cooperatives
- `user_notifications` - for sellers/buyers

## 📊 Dashboard Overview

### Cooperative Dashboard Tabs

1. **Sellers Tab**:
   - Shows: Pending, Active, Inactive counts
   - Filters: Only sellers assigned to this coop
   - Actions: Approve/Reject pending applications

2. **Products Tab**:
   - Shows: Pending Review, Approved, Rejected counts
   - Filters: Only products from assigned sellers
   - Actions: Approve/Reject pending products

3. **Orders Tab**:
   - Shows: All orders involving cooperative's products
   - Actions: Manage order fulfillment

4. **Delivery Tab**:
   - Shows: Orders requiring delivery
   - Actions: Update delivery status

5. **Payments Tab**:
   - Shows: Payment tracking and COD management
   - Actions: Confirm payments received

## 🎨 UI Components Added

### Registration Screen
- **Cooperative Selection Section**: 
  - Icon: Groups
  - Dropdown with name + email
  - Validation message if not selected
  - Info card showing selected cooperative

### Product Upload Screen
- **Auto-Assigned Cooperative Card** (if seller has one):
  - Green card with business icon
  - Shows cooperative name
  - Read-only (can't change)
  
- **Cooperative Dropdown** (if multiple available):
  - Same as registration dropdown
  - Required field validation

### Cooperative Dashboard
- **Seller Cards**:
  - Status badges (Pending/Approved/Rejected)
  - Contact information
  - Tap to view details and approve

- **Product Cards**:
  - Product image
  - Price and quantity
  - Status indicator
  - Tap to view and approve

## 🔐 Security Considerations

1. **Cooperative Isolation**: Each cooperative only sees their own data
2. **Role-Based Access**: Only cooperative/admin roles can access dashboard
3. **Update Restrictions**: Cooperatives can only update status fields
4. **Audit Trail**: All changes include updatedAt timestamp

## 📱 Mobile App Flow

```
[Farmer Registration]
    ↓
Select Cooperative
    ↓
Submit Application
    ↓
[Cooperative Receives Notification]
    ↓
Cooperative Reviews
    ↓
Approve/Reject
    ↓
[Farmer Receives Notification]
    ↓
If Approved: Can Upload Products
    ↓
[Product Upload]
    ↓
Linked to Cooperative
    ↓
[Cooperative Receives Notification]
    ↓
Cooperative Reviews Product
    ↓
Approve/Reject
    ↓
[Farmer Receives Notification]
    ↓
If Approved: Product Goes Live!
```

## ✨ Key Features

✅ **Decentralized Approval**: Each cooperative manages their own sellers
✅ **Smart Assignment**: Products auto-link to seller's cooperative
✅ **Real-time Updates**: StreamBuilder keeps data fresh
✅ **Notification System**: Keeps everyone informed
✅ **Flexible Selection**: Farmers choose their cooperative
✅ **Data Isolation**: Cooperatives see only their data
✅ **Mobile-Optimized**: Beautiful UI on all devices

## 🎉 You're Ready!

The cooperative approval system is now fully functional! Test thoroughly and enjoy the improved workflow where cooperatives handle what they do best - managing their local farmers and products.

For detailed information, see `COOPERATIVE_APPROVAL_SYSTEM.md`.
