# Cloud Function Implementation Guide

## Quick Implementation - Firebase Cloud Function

This guide shows how to implement the ideal solution using Firebase Cloud Functions.

### Prerequisites
- Firebase project with Firestore and Auth enabled
- Node.js and npm installed
- Firebase CLI installed: `npm install -g firebase-tools`

### Step 1: Initialize Cloud Functions

```bash
cd your-project
firebase init functions
```

Choose:
- TypeScript (for better type safety)
- ESLint: Yes

### Step 2: Install Dependencies

```bash
cd functions
npm install
```

The default `package.json` already includes `firebase-admin` and `firebase-functions`.

### Step 3: Create the Cloud Function

Replace `functions/src/index.ts` with:

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

/**
 * Cloud Function to create a cooperative account
 * Only admins can call this function
 * Admin session is preserved (works differently than client-side auth)
 */
export const createCooperativeAccount = functions.https.onCall(
  async (data: any, context: functions.https.CallableContext) => {
    try {
      // 1. Verify user is authenticated
      if (!context.auth) {
        throw new functions.https.HttpsError(
          'unauthenticated',
          'You must be signed in to create a cooperative account'
        );
      }

      const adminUid = context.auth.uid;

      // 2. Verify user is an admin
      const adminDoc = await db.collection('users').doc(adminUid).get();
      
      if (!adminDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Admin user profile not found'
        );
      }

      const adminData = adminDoc.data();
      if (adminData?.role !== 'admin') {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Only admins can create cooperative accounts'
        );
      }

      // 3. Validate input
      const { name, email, password, phone, location } = data;
      
      if (!name || !email || !password) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Name, email, and password are required'
        );
      }

      if (password.length < 6) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Password must be at least 6 characters'
        );
      }

      const emailLower = email.toLowerCase().trim();

      // 4. Check if email already exists
      const existingUserQuery = await db
        .collection('users')
        .where('email', '==', emailLower)
        .limit(1)
        .get();

      if (!existingUserQuery.empty) {
        throw new functions.https.HttpsError(
          'already-exists',
          'A user with this email already exists'
        );
      }

      // 5. Create authentication user
      console.log(`Creating Firebase Auth user for ${emailLower}`);
      
      const userRecord = await auth.createUser({
        email: emailLower,
        password: password,
        displayName: name.trim(),
      });

      console.log(`Firebase Auth user created: ${userRecord.uid}`);

      // 6. Create Firestore document
      console.log(`Creating Firestore document for cooperative`);
      
      await db.collection('users').doc(userRecord.uid).set({
        name: name.trim(),
        email: emailLower,
        phone: phone?.trim() || '',
        location: location?.trim() || '',
        role: 'cooperative',
        status: 'active',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: adminUid,
      });

      console.log(`Cooperative account successfully created`);

      return {
        success: true,
        uid: userRecord.uid,
        email: emailLower,
        message: `Cooperative account successfully created for ${name}`,
      };

    } catch (error: any) {
      console.error('Error creating cooperative account:', error);
      
      // Re-throw as HttpsError if not already
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      // Handle specific Firebase Auth errors
      if (error.code === 'auth/email-already-exists') {
        throw new functions.https.HttpsError(
          'already-exists',
          'This email is already registered'
        );
      }
      
      if (error.code === 'auth/invalid-email') {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Invalid email address'
        );
      }
      
      if (error.code === 'auth/weak-password') {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Password is too weak'
        );
      }

      throw new functions.https.HttpsError(
        'internal',
        `Failed to create cooperative account: ${error.message}`
      );
    }
  }
);

/**
 * Additional helper functions
 */

/**
 * Update cooperative status
 * Only admins can update
 */
export const updateCooperativeStatus = functions.https.onCall(
  async (data: any, context: functions.https.CallableContext) => {
    try {
      if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Not signed in');
      }

      const adminUid = context.auth.uid;
      const adminDoc = await db.collection('users').doc(adminUid).get();
      
      if (adminDoc.data()?.role !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Not an admin');
      }

      const { cooperativeUid, status } = data;
      
      if (!cooperativeUid || !status) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
      }

      await db.collection('users').doc(cooperativeUid).update({
        status: status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, message: `Cooperative status updated to ${status}` };
    } catch (error: any) {
      console.error('Error updating cooperative status:', error);
      throw error instanceof functions.https.HttpsError 
        ? error 
        : new functions.https.HttpsError('internal', error.message);
    }
  }
);

/**
 * Delete cooperative account
 * Only admins can delete
 */
export const deleteCooperativeAccount = functions.https.onCall(
  async (data: any, context: functions.https.CallableContext) => {
    try {
      if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Not signed in');
      }

      const adminUid = context.auth.uid;
      const adminDoc = await db.collection('users').doc(adminUid).get();
      
      if (adminDoc.data()?.role !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Not an admin');
      }

      const { cooperativeUid } = data;
      
      if (!cooperativeUid) {
        throw new functions.https.HttpsError('invalid-argument', 'Cooperative UID required');
      }

      // Delete Firebase Auth user
      await auth.deleteUser(cooperativeUid);
      
      // Delete Firestore document
      await db.collection('users').doc(cooperativeUid).delete();

      return { success: true, message: 'Cooperative account deleted' };
    } catch (error: any) {
      console.error('Error deleting cooperative:', error);
      throw error instanceof functions.https.HttpsError 
        ? error 
        : new functions.https.HttpsError('internal', error.message);
    }
  }
);
```

### Step 4: Update React Component

Replace the `createNewCooperativeAccount` function in `CooperativeManagement.tsx`:

```typescript
import { httpsCallable } from 'firebase/functions';
import { functions } from '../services/firebase';

// At the top of the component or in a service file:
const createCooperativeAccountFunction = httpsCallable(
  functions,
  'createCooperativeAccount'
);

// Inside the component:
const createNewCooperativeAccount = async (values: CreateCoopFormValues) => {
  setLoading(true);
  try {
    const result = await createCooperativeAccountFunction({
      name: values.name,
      email: values.email,
      password: values.password,
      phone: values.phone || '',
      location: values.location || '',
    });

    message.success(`Successfully created cooperative account for ${values.name}!`);
    form.resetFields();
    loadCooperativeUsers();
  } catch (error: any) {
    console.error('Error creating cooperative account:', error);
    const errorMessage = error.message || 'Failed to create account';
    message.error(errorMessage);
  } finally {
    setLoading(false);
  }
};
```

### Step 5: Add Firebase Functions to Service

Create or update `ecommerce-web-admin/src/services/firebase.ts`:

```typescript
import { initializeApp, getApps, getApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { getStorage } from 'firebase/storage';
import { getFunctions } from 'firebase/functions';
import { firebaseConfig } from '../config/firebase';

const app = !getApps().length ? initializeApp(firebaseConfig) : getApp();

export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);
export const functions = getFunctions(app);

export default app;
```

### Step 6: Deploy Cloud Functions

```bash
# From the root of your Firebase project
firebase deploy --only functions

# Or deploy everything
firebase deploy
```

Output will show your function URLs.

### Step 7: Test the Function

1. Rebuild and run your React app
2. Login as admin
3. Create a cooperative account
4. **Admin session should be preserved!**
5. You stay logged in and see the new cooperative in the list

### Benefits of This Approach

✅ **Admin session never interrupted**
✅ **Scalable and maintainable**
✅ **Backend validation prevents bad data**
✅ **Audit trail (createdBy field)**
✅ **Easy to add more logic later**
✅ **Can be called from mobile apps too**

### Troubleshooting

**Issue: Function not found**
- Solution: Verify deployment succeeded, check function names match exactly

**Issue: Permission denied errors**
- Solution: Check Firestore security rules, ensure admin has correct role

**Issue: Email already exists error**
- Solution: This is expected if email already in system

### Adding More Cloud Functions

Use the same pattern to add functions for:
- Update cooperative details
- Change cooperative status
- Delete cooperative account
- Bulk operations

### Firestore Security Rules for Cloud Functions

```
match /users/{userId} {
  allow read: if request.auth.uid != null;
  allow create: if request.auth.uid != null &&
                request.resource.data.role in ['buyer', 'cooperative', 'seller', 'admin'];
  allow update: if request.auth.uid == userId || 
                get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
  allow delete: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}
```

## Complete! 🎉

You now have a production-ready system for creating cooperative accounts without interrupting the admin's session!
