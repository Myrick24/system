# Firestore Permission Fix Guide

## Problem
You're getting a "permission denied" error when guest users try to browse products. This happens because Firestore security rules don't allow unauthenticated users to query the products collection.

## Root Cause
The original Firestore rules only allowed reading individual product documents, but not querying/listing the products collection for unauthenticated (guest) users.

## Solution Applied
Updated the Firestore rules to allow guest users to read approved products. The key change is in the products collection rules:

```javascript
// Products collection
match /products/{productId} {
  // Anyone (including guests) can read approved products
  // This covers both individual document reads and collection queries
  allow read: if resource.data.status == 'approved';
  
  // ... rest of the rules
}
```

## Manual Deploy Instructions

If the automatic deployment didn't work, follow these steps:

### Option 1: Deploy via Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to Firestore Database → Rules
4. Copy the updated rules from `firestore.rules` file
5. Click "Publish"

### Option 2: Deploy via Command Line
```bash
# Navigate to your project directory
cd "d:\capstone-system\e-commerce-app"

# Login to Firebase (if not already logged in)
firebase login

# Deploy only the Firestore rules
firebase deploy --only firestore:rules
```

### Option 3: Alternative PowerShell Commands
If you get execution policy errors:
```powershell
# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or use npx
npx firebase deploy --only firestore:rules

# Or use the full path
node_modules\.bin\firebase deploy --only firestore:rules
```

## Verification

After deploying the rules, test the fix:

1. **Run your Flutter app**
2. **Navigate to the guest browse screen**
3. **Check if products load without permission errors**

## Additional Considerations

### Security Notes
- Guest users can only read products with `status: 'approved'`
- They cannot create, update, or delete any products
- Authentication is still required for all other operations

### Performance
- Added limit to queries to prevent excessive reads
- Only approved products are accessible to guests

### Debugging
If you still get permission errors:

1. **Check Firebase Console → Firestore → Rules** to ensure the new rules are deployed
2. **Look at the browser's network tab** to see the exact Firestore operation that's failing
3. **Check the Firebase Console → Firestore → Usage tab** for any quota issues

## Current Rules Summary

The updated rules now allow:
- ✅ **Guests**: Read approved products only
- ✅ **Authenticated users**: Full access to their own data
- ✅ **Sellers**: Create/manage their own products (when approved)
- ✅ **Admins**: Full access to all data

## Alternative Solution (If Rules Don't Work)

If you continue having issues, you can also implement a cloud function that serves as a public API for approved products, but the rules-based solution should work for your use case.
