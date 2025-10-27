# Firestore Rules Issues & Fixes

## Issues Found

### Issue 1: Orders Collection - Logic Error in Read/Create Rule
**Current Rule:**
```firerules
allow read, create: if request.auth != null && 
  (request.resource.data.buyerId == request.auth.uid || 
   request.resource.data.sellerId == request.auth.uid ||
   resource.data.buyerId == request.auth.uid || 
   resource.data.sellerId == request.auth.uid);
```

**Problem:**
- On `create`, `resource.data` doesn't exist yet (document is being created)
- The rule tries to access `resource.data` which is `null` during creation
- This causes the entire rule to fail with PERMISSION_DENIED

**Solution:**
- Use `has()` to safely check if fields exist
- Separate create and read logic with proper conditions

### Issue 2: Orders/Items Subcollection - References Old userId Field
**Current Rule:**
```firerules
match /orders/{orderId}/items/{itemId} {
  allow read, write: if request.auth != null && 
    (get(/databases/$(database)/documents/orders/$(orderId)).data.userId == request.auth.uid ||
     get(/databases/$(database)/documents/orders/$(orderId)).data.sellerId == request.auth.uid ||
     isAdmin());
}
```

**Problem:**
- Still checking `userId` field which no longer exists
- Should check `buyerId` instead
- This prevents reading order items

### Issue 3: Missing List Permission
**Current State:**
- Orders collection has no `.list()` permission
- Firestore queries (`.where()`, `.get()` on collections) require list permission
- Checkout screen can't query orders

**Solution:**
- Add `allow list: if request.auth != null;` to allow authenticated users to query

## Fixed Firestore Rules

Replace your orders section with:

```firerules
    // Orders collection
    match /orders/{orderId} {
      // Buyers can create their own orders
      allow create: if request.auth != null && 
        request.resource.data.buyerId == request.auth.uid;
      
      // Users can read orders where they are buyer or seller
      allow read: if request.auth != null && 
        (resource.data.buyerId == request.auth.uid || 
         resource.data.sellerId == request.auth.uid);
      
      // Allow authenticated users to list/query orders (needed for collection queries)
      allow list: if request.auth != null;
      
      // Users can update their own orders with specific fields
      allow update: if request.auth != null && 
        (resource.data.buyerId == request.auth.uid || 
         resource.data.sellerId == request.auth.uid) &&
        request.resource.data.diff(resource.data).affectedKeys()
          .hasOnly(['status', 'updatedAt', 'deliveryDate', 'notes']);
      
      // Admins can read and update any order
      allow read, update: if request.auth != null && isAdmin();
      
      // Order items subcollection
      match /items/{itemId} {
        allow read, write: if request.auth != null && 
          (get(/databases/$(database)/documents/orders/$(orderId)).data.buyerId == request.auth.uid ||
           get(/databases/$(database)/documents/orders/$(orderId)).data.sellerId == request.auth.uid ||
           isAdmin());
      }
    }
```

## Key Changes

| Before | After | Why |
|--------|-------|-----|
| `allow read, create:` combined | Separate rules | `resource.data` doesn't exist on create |
| Checked `resource.data.userId` on items | Check `buyerId` | Field was renamed in code |
| No `list` permission | Added `allow list:` | Needed for `.where()` queries |
| Complex OR logic | Simpler conditions | Clearer and safer logic |

## Why This Fixes Your Issue

1. **Create Works**: Only requires `buyerId` in the new document (which exists)
2. **Read Works**: Checks existing document's fields correctly
3. **Queries Work**: `allow list:` lets authenticated users run `.where()` queries
4. **Items Work**: Uses correct `buyerId` field
5. **No Conflicts**: Admins can bypass all checks

## Implementation Steps

1. Go to Firebase Console → Firestore → Rules
2. Find the `// Orders collection` section
3. Replace entire section (including the old `match /orders/{orderId}/items` subcollection)
4. With the new rules shown above
5. Click "Publish"
6. Test checkout flow immediately
