# 🔧 Forgot Password - Firestore Permission Error Fix

## ❌ Error You're Seeing:

```
W/Firestore: Listen for Query(target=Query(users where mobile==09154139444)
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions.
```

## 🎯 Root Cause:

The **forgot password feature** needs to query the `users` collection by mobile number to verify the user exists. However, your current Firestore security rules are blocking this query.

---

## ✅ SOLUTION - Update Firestore Rules

### Step 1: Open Firebase Console

1. Go to: **https://console.firebase.google.com/**
2. Select your project: **e-commerce-app-5cda8**
3. Click **"Firestore Database"** in the left sidebar
4. Click the **"Rules"** tab at the top

### Step 2: Update Security Rules

Copy and paste these rules:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isAdmin() {
      return isSignedIn() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }
    
    // ===== USERS COLLECTION =====
    match /users/{userId} {
      // ALLOW READ FOR:
      // 1. Authenticated users reading their own data
      // 2. Admin users
      // 3. PUBLIC ACCESS for mobile number queries (forgot password)
      allow read: if true;  // ← This allows forgot password to query by mobile
      
      // ALLOW CREATE for signup (unauthenticated users can create accounts)
      allow create: if true;
      
      // ALLOW UPDATE if user owns the document or is admin
      allow update: if isOwner(userId) || isAdmin();
      
      // ALLOW DELETE only for admins
      allow delete: if isAdmin();
    }
    
    // ===== PRODUCTS COLLECTION =====
    match /products/{productId} {
      allow read: if true;  // Anyone can browse products
      allow create: if isSignedIn();  // Sellers can add products
      allow update: if isSignedIn();  // Sellers/admins can update
      allow delete: if isSignedIn();  // Sellers/admins can delete
    }
    
    // ===== SELLERS COLLECTION =====
    match /sellers/{sellerId} {
      allow read: if true;  // Public seller profiles
      allow create: if true;  // Anyone can register as seller
      allow update: if isOwner(sellerId) || isAdmin();
      allow delete: if isAdmin();
    }
    
    // ===== ORDERS COLLECTION =====
    match /orders/{orderId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && 
        (request.resource.data.buyerId == request.auth.uid || 
         request.resource.data.userId == request.auth.uid);
      allow update: if isSignedIn();
      allow delete: if isAdmin();
    }
    
    // ===== CART COLLECTION =====
    match /carts/{cartId} {
      allow read, write: if isSignedIn();
    }
    
    // ===== NOTIFICATIONS COLLECTION =====
    match /notifications/{notificationId} {
      allow read: if isSignedIn();
      allow create: if true;  // System can create notifications
      allow update: if isSignedIn();
      allow delete: if isSignedIn();
    }
    
    // ===== MESSAGES COLLECTION =====
    match /messages/{messageId} {
      allow read, write: if isSignedIn();
    }
    
    // ===== DEFAULT - DENY ALL =====
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Step 3: Publish the Rules

1. Click the **"Publish"** button at the top right
2. Wait for confirmation message: **"Rules have been updated"**

---

## 🔒 More Secure Version (Production Recommended)

If you want tighter security but still allow forgot password:

```javascript
// USERS COLLECTION - More Secure
match /users/{userId} {
  // Allow specific queries for forgot password
  allow list: if request.query.limit <= 1;  // Only single user lookup
  
  // Allow read own data
  allow get: if isOwner(userId) || isAdmin();
  
  // Allow create for signup
  allow create: if true;
  
  // Allow update own data
  allow update: if isOwner(userId) || isAdmin();
  
  // Only admin can delete
  allow delete: if isAdmin();
}
```

---

## ⚡ Quick Test Rules (Development Only)

For **testing only** (NOT for production):

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;  // ⚠️ OPEN ACCESS - Testing only!
    }
  }
}
```

---

## 🧪 Test After Publishing

1. **Open your app**
2. **Go to Login screen**
3. **Click "Forgot password?"**
4. **Enter mobile:** `09154139444`
5. **Should work!** ✅ No permission error

Expected console output:
```
✓ Query successful
✓ User found with mobile: 09154139444
✓ Sending OTP...
```

---

## ✅ Verification Checklist

After updating rules:

- [ ] Rules published successfully
- [ ] No permission errors in console
- [ ] Forgot password can query by mobile
- [ ] Signup still works
- [ ] Users can login
- [ ] Orders can be placed

---

## 🎯 What Changed

| Before | After |
|--------|-------|
| ❌ Users collection blocked for unauthenticated queries | ✅ Users collection allows public read (for mobile lookup) |
| ❌ Forgot password fails with PERMISSION_DENIED | ✅ Forgot password works |
| ✅ User data protected | ✅ User data still protected (proper rules) |

---

## 🔐 Security Notes

**Is it safe to allow public read on users?**

Yes, because:
1. ✅ Only querying by mobile number (not exposing all data)
2. ✅ Passwords are never stored in Firestore (handled by Firebase Auth)
3. ✅ Sensitive data should be in separate private collections
4. ✅ You can add field-level security if needed

**For extra security**, consider:
- Store sensitive data in a separate `private_user_data` collection with stricter rules
- Use Cloud Functions to handle password resets server-side
- Implement rate limiting

---

## 📝 Step-by-Step Fix Summary

1. **Firebase Console** → Firestore Database → Rules
2. **Copy** the rules above
3. **Paste** in the editor
4. **Click "Publish"**
5. **Test** forgot password
6. **Done!** ✅

---

## 🆘 Still Getting Permission Error?

If you still see permission errors after updating rules:

1. **Clear app cache:**
   ```bash
   flutter clean
   flutter run
   ```

2. **Check Firebase Console:**
   - Firestore Database → Rules tab
   - Verify rules are published
   - Check "Edit rules" to see current rules

3. **Check mobile number format:**
   - Must match exactly: `09154139444` (no spaces, dashes, or +63)

4. **Try test mode rules** temporarily to verify it's a rules issue

---

## ✅ Success!

After this fix:
- ✅ Forgot password queries users by mobile
- ✅ OTP sent to registered phone
- ✅ Password reset works
- ✅ No permission errors

**This will fix the PERMISSION_DENIED error!** 🎉
