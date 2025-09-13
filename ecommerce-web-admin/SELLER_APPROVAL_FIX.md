# Seller Approval Status Fix

## ❌ Problem
When you approve a seller through the admin web interface, the approval status doesn't show up in the mobile app.

## 🔍 Root Cause
The admin web interface was only updating the `users` collection with the approval status, but the mobile app checks the `sellers` collection for the seller's status. Both collections need to be updated for the approval to work properly.

## ✅ Solution Applied
Updated the admin web interface (`userService.ts`) to update both collections when approving/rejecting sellers:

1. **Users Collection**: `status: 'approved'`
2. **Sellers Collection**: `status: 'approved'`

## 🔧 Fixed Files
- `ecommerce-web-admin/src/services/userService.ts`
  - Updated `approveSeller()` function
  - Updated `rejectSeller()` function

## 🚀 How to Test
1. **Use the web admin to approve a seller**
2. **Check if both collections are updated:**
   ```bash
   cd ecommerce-web-admin
   npm install firebase
   node check-seller-status.js seller@example.com
   ```

## 🛠️ Manual Fix for Existing Sellers
If you already approved sellers through the old web admin and they're still showing as pending in the app:

```bash
cd ecommerce-web-admin
npm install firebase
node fix-seller-status.js
```

This will find all approved sellers in the `users` collection and update their corresponding `sellers` collection status.

## 📱 Verification in Mobile App
After the fix:
1. Open the mobile app
2. Go to Account screen
3. Check seller status - should now show "APPROVED"
4. Seller dashboard should be accessible

## 🔍 Technical Details

### Before Fix:
- Admin web: Updates only `users` collection
- Mobile app: Checks `sellers` collection
- Result: Status mismatch = app shows "pending"

### After Fix:
- Admin web: Updates both `users` AND `sellers` collections
- Mobile app: Checks `sellers` collection
- Result: Status match = app shows "approved"

### Code Changes Made:
```typescript
// OLD CODE (userService.ts)
async approveSeller(userId: string) {
  await updateDoc(doc(db, 'users', userId), {
    status: 'approved'
  });
}

// NEW CODE (userService.ts)
async approveSeller(userId: string) {
  // Update users collection
  await updateDoc(doc(db, 'users', userId), {
    status: 'approved'
  });
  
  // ALSO update sellers collection
  const userDoc = await getDoc(doc(db, 'users', userId));
  const userEmail = userDoc.data().email;
  const sellerQuery = query(collection(db, 'sellers'), where('email', '==', userEmail));
  const sellerSnapshot = await getDocs(sellerQuery);
  
  if (!sellerSnapshot.empty) {
    await updateDoc(sellerSnapshot.docs[0].ref, {
      status: 'approved'
    });
  }
}
```

## ⚡ Quick Commands
```bash
# Check specific seller status
node check-seller-status.js seller@example.com

# Fix all sellers automatically
node fix-seller-status.js

# Fix specific seller
node fix-seller-status.js seller@example.com
```

The issue is now resolved! Future seller approvals through the admin web will update both collections correctly.
