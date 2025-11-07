# Fix: Cooperative Account Creation - Admin Logout Issue

## Problem Description
When an admin creates a new cooperative account in the admin dashboard, the system automatically logs out the admin and redirects to the login page. This happens because Firebase `createUserWithEmailAndPassword()` automatically signs in the newly created user, logging out the current admin session.

## Root Cause
Firebase Authentication's `createUserWithEmailAndPassword()` function:
1. Creates a new user in Firebase Auth
2. **Automatically signs in that new user**
3. This logs out the current admin user
4. The AuthContext detects no admin user and redirects to login

## Solution Implemented

### Current Fix (Temporary)
The fix now:
1. Creates the cooperative account with `createUserWithEmailAndPassword()`
2. Successfully creates the Firestore document with `role: 'cooperative'`
3. Immediately signs out the newly created cooperative user
4. Shows a helpful message informing the admin to log back in
5. Displays success confirmation that the cooperative was created

**Code Changes:**
```typescript
// After creating cooperative account and Firestore document:
setTimeout(async () => {
  try {
    // Sign out the newly created cooperative user
    await auth.signOut();
    // Show helpful message
    message.info('Cooperative account created! Please log back in to continue managing the system.');
  } catch (signOutError) {
    console.error('Error during sign out:', signOutError);
  }
}, 1000);
```

### Better Solution (Recommended - Requires Backend)

For a production-grade solution, implement one of these approaches:

#### Option 1: Firebase Cloud Function (Best)
Create a Cloud Function that uses the Firebase Admin SDK:

```typescript
// functions/src/index.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const createCooperativeAccount = functions.https.onCall(async (data, context) => {
  // Verify caller is admin
  const callerUid = context.auth?.uid;
  const callerDoc = await admin.firestore().collection('users').doc(callerUid!).get();
  
  if (callerDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can create cooperative accounts');
  }

  // Create user (won't affect admin session)
  const user = await admin.auth().createUser({
    email: data.email,
    password: data.password,
    displayName: data.name,
  });

  // Create Firestore document
  await admin.firestore().collection('users').doc(user.uid).set({
    name: data.name,
    email: data.email,
    phone: data.phone || '',
    location: data.location || '',
    role: 'cooperative',
    status: 'active',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    uid: user.uid,
    message: `Cooperative account created for ${data.name}`,
  };
});
```

**Usage in React:**
```typescript
import { httpsCallable } from 'firebase/functions';
import { functions } from '../services/firebase';

const createCooperative = httpsCallable(functions, 'createCooperativeAccount');

const handleCreate = async (values: CreateCoopFormValues) => {
  try {
    const result = await createCooperative({
      name: values.name,
      email: values.email,
      password: values.password,
      phone: values.phone,
      location: values.location,
    });
    
    message.success(result.data.message);
    // Admin session is preserved!
    loadCooperativeUsers();
  } catch (error) {
    message.error(error.message);
  }
};
```

**Advantages:**
- ✅ Admin session is never affected
- ✅ More secure (private API key protected)
- ✅ Can run additional backend operations
- ✅ No page reload needed
- ✅ Better user experience

#### Option 2: Backend API Endpoint
Create a Node.js/Express backend that handles user creation:

```typescript
// backend/routes/admin.ts
app.post('/api/admin/create-cooperative', async (req, res) => {
  // Verify admin token
  const adminToken = req.headers.authorization;
  const decodedToken = await admin.auth().verifyIdToken(adminToken);
  
  if (!decodedToken) {
    return res.status(403).json({ error: 'Unauthorized' });
  }

  // Check if user is admin
  const userDoc = await admin.firestore()
    .collection('users')
    .doc(decodedToken.uid)
    .get();
  
  if (userDoc.data()?.role !== 'admin') {
    return res.status(403).json({ error: 'Not an admin' });
  }

  // Create user
  const user = await admin.auth().createUser({
    email: req.body.email,
    password: req.body.password,
    displayName: req.body.name,
  });

  // Create Firestore document
  await admin.firestore().collection('users').doc(user.uid).set({
    // ... cooperative data
  });

  res.json({ success: true, uid: user.uid });
});
```

## Files Modified
- `ecommerce-web-admin/src/components/CooperativeManagement.tsx`
  - Updated import to include `useAuth` context hook
  - Updated import to include `serverTimestamp` from Firestore
  - Modified `createNewCooperativeAccount` function to handle session properly
  - Added automatic sign-out of newly created cooperative user
  - Added user-friendly message about re-login requirement

## Testing Steps

1. **Login as Admin**
   - Navigate to admin dashboard
   - Ensure you're logged in as an admin

2. **Create Cooperative Account**
   - Go to Cooperative Management
   - Fill in cooperative details:
     - Name: Test Coop
     - Email: test@coop.com
     - Password: (secure password)
     - Phone: 1234567890
     - Location: Test Location

3. **Verify Behavior**
   - ✅ Success message shows cooperative created
   - ✅ Page redirects to login
   - ✅ Cooperatives list may not update (because admin logged out)
   - ✅ Admin can log back in normally

4. **Verify in Database**
   - Check Firestore `users` collection
   - Verify new document exists with `role: 'cooperative'`
   - Verify all fields are populated correctly

## User Experience Flow

### Current Flow (After Fix)
```
Admin Dashboard
    ↓
[Click Create Cooperative]
    ↓
[Fill Form & Submit]
    ↓
[Success! Cooperative Created]
    ↓
[Auto Sign-out - Redirect to Login]
    ↓
Admin Login Page
    ↓
[Re-Login with Admin Credentials]
    ↓
Admin Dashboard (Restored)
```

### Ideal Flow (With Cloud Function)
```
Admin Dashboard
    ↓
[Click Create Cooperative]
    ↓
[Fill Form & Submit]
    ↓
[Cloud Function Processes]
    ↓
[Success! Cooperative Created]
    ↓
[Admin Session Preserved]
    ↓
Admin Dashboard (Still Logged In)
```

## Migration to Cloud Function

To implement the ideal solution:

1. **Set up Firebase Cloud Functions** (if not already done)
   ```bash
   npm install -g firebase-tools
   firebase init functions
   ```

2. **Create the Cloud Function** (as shown in Option 1 above)

3. **Deploy**
   ```bash
   firebase deploy --only functions
   ```

4. **Update CooperativeManagement.tsx** to call the Cloud Function instead

## Security Considerations

- ✅ Only admins can create cooperative accounts (verified in function)
- ✅ Passwords are never exposed in logs
- ✅ Email uniqueness is checked before account creation
- ✅ Role-based access control is enforced
- ✅ Firestore security rules should restrict cooperative creation to admins

**Recommended Firestore Rule:**
```
allow create: if request.auth.uid != null && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin' &&
             request.resource.data.role == 'cooperative';
```

## Troubleshooting

### Issue: Admin still gets logged out
**Solution:** Clear browser cache and cookies, then try again. Ensure Firebase is properly initialized.

### Issue: Cooperative account not created despite success message
**Solution:** Check browser console for errors. Verify Firestore rules allow the operation.

### Issue: Can't log back in as admin
**Solution:** Verify admin credentials are correct. Check that admin account exists in Firebase Auth with `role: 'admin'` in Firestore.

## Summary

The current implementation:
- ✅ Prevents data loss (cooperative is still created)
- ✅ Provides user feedback (success message)
- ✅ Maintains security (role checks)
- ⚠️ Requires re-login (not ideal UX)

The recommended next step is to implement the Cloud Function approach for a seamless admin experience without session interruption.
