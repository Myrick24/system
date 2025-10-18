# 🔐 Creating Cooperative Staff Accounts - Admin Guide

## Overview

**Cooperative staff accounts** are special user accounts with the `role: 'cooperative'` that grant access to the Cooperative Dashboard. Only administrators can create or assign these accounts.

---

## 🎯 Purpose

Cooperative staff need special permissions to:
- View all orders (regardless of seller/buyer)
- Update order statuses
- Manage deliveries and pickups
- Collect Cash on Delivery payments
- Access delivery and payment dashboards

**Regular users (buyers/sellers) should NOT have access to this dashboard.**

---

## 🔒 Security Model

### Access Control Flow

```
User Login
    ↓
Check User Role
    ↓
├─ role: 'admin' ────────→ ✅ Full Access (including coop dashboard)
├─ role: 'cooperative' ──→ ✅ Cooperative Dashboard Access
├─ role: 'seller' ───────→ ❌ Access Denied
└─ role: 'buyer' ────────→ ❌ Access Denied
```

### What Happens Without Permission

If a user without admin/cooperative role tries to access the dashboard:

```
┌────────────────────────────────────┐
│        ⛔ Access Denied            │
├────────────────────────────────────┤
│                                    │
│  Only cooperative staff and        │
│  administrators can access this    │
│  dashboard.                        │
│                                    │
│  Your current role: buyer          │
│                                    │
│  ┌──────────────────────────────┐ │
│  │   How to Get Access          │ │
│  │                              │ │
│  │  1. Contact your admin       │ │
│  │  2. Request cooperative      │ │
│  │     staff access             │ │
│  │  3. Admin will assign        │ │
│  │     "cooperative" role       │ │
│  └──────────────────────────────┘ │
│                                    │
│         [Go Back]                  │
└────────────────────────────────────┘
```

---

## 📋 Methods to Create Cooperative Accounts

### Method 1: Using the Admin Tool (Recommended)

**Location**: Admin Dashboard → Create Cooperative Account

#### Steps:

1. **Login as Admin**
   ```
   Email: admin@gmail.com (your admin account)
   Password: (your admin password)
   ```

2. **Navigate to Tool**
   ```
   Admin Dashboard → Drawer Menu → "Create Cooperative Account"
   ```

3. **Two Options Available**:

   **Option A: Assign Role to Existing User**
   - Get User ID (UID) from Firebase Console
   - Enter UID in the tool
   - Click "Assign Cooperative Role"
   - User immediately gets access
   
   **Option B: Create New Account (Manual)**
   - Have user sign up normally first
   - Get their UID from Firebase Console
   - Use Option A to assign role

---

### Method 2: Direct Firestore Update

#### Steps:

1. **Go to Firebase Console**
   - Navigate to: https://console.firebase.google.com
   - Select your project: `e-commerce-app-5cda8`

2. **Open Firestore Database**
   ```
   Firestore Database → Data → users collection
   ```

3. **Find or Create User Document**
   - If user exists: Click on their document
   - If new user: Create new document with UID

4. **Update/Add Role Field**
   ```json
   {
     "name": "Juan Dela Cruz",
     "email": "juan@cooperative.com",
     "role": "cooperative",
     "phone": "09123456789",
     "createdAt": "2025-10-18T...",
     "updatedAt": "2025-10-18T..."
   }
   ```

5. **Save Changes**

6. **User Can Now Login**
   - Email: juan@cooperative.com
   - They'll have dashboard access immediately

---

### Method 3: Firebase Admin SDK (Production Recommended)

For production environments, use Firebase Admin SDK on your backend:

#### Backend Code Example (Node.js):

```javascript
const admin = require('firebase-admin');

async function createCooperativeAccount(email, password, name, phone) {
  try {
    // Create user in Firebase Auth
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: name,
    });
    
    // Create user document in Firestore with cooperative role
    await admin.firestore().collection('users').doc(userRecord.uid).set({
      name: name,
      email: email,
      role: 'cooperative',
      phone: phone,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log('Cooperative account created:', userRecord.uid);
    return userRecord.uid;
  } catch (error) {
    console.error('Error creating cooperative account:', error);
    throw error;
  }
}

// Usage
createCooperativeAccount(
  'staff@cooperative.com',
  'securePassword123',
  'Maria Santos',
  '09123456789'
);
```

---

## 🛠 Using the Admin Tool

### Step-by-Step Guide

#### **Screen 1: Create Cooperative Account Tool**

When you open the tool, you'll see:

```
┌────────────────────────────────────────────┐
│  Create Cooperative Staff Account         │
├────────────────────────────────────────────┤
│                                            │
│  This user will have access to the        │
│  Cooperative Dashboard to manage          │
│  deliveries and payments.                 │
│                                            │
│  Full Name:    [_____________________]    │
│  Email:        [_____________________]    │
│  Phone:        [_____________________]    │
│  Password:     [_____________________]    │
│                                            │
│       [Create Account]                     │
│                                            │
├────────────────────────────────────────────┤
│  Assign Cooperative Role to Existing User │
│                                            │
│  User ID (UID): [__________________]      │
│                                            │
│  Get UID from Firebase Console →          │
│  Authentication                            │
│                                            │
│       [Assign Cooperative Role]            │
│                                            │
└────────────────────────────────────────────┘
```

#### **Assigning Role to Existing User**

1. **Get User ID**:
   - Firebase Console → Authentication
   - Find the user
   - Copy their "User UID" (long string like: `abc123XYZ456...`)

2. **Paste in Tool**:
   - Enter UID in "User ID (UID)" field
   - Click "Assign Cooperative Role"

3. **Success Message**:
   ```
   Success! ✅
   
   User: Juan Dela Cruz
   Email: juan@example.com
   Role: Cooperative Staff
   
   This user can now access the Cooperative Dashboard.
   ```

4. **User Can Login**:
   - User logs in with their existing credentials
   - They'll now see cooperative dashboard access

---

## 📝 Creating First Cooperative Account

### Complete Workflow

#### 1. Have User Sign Up Normally

User goes to your app:
```
Sign Up Screen:
  Name: Juan Dela Cruz
  Email: juan@cooperative.com
  Password: Juan123!
  Role: Buyer (default)
```

User completes signup → Account created

#### 2. Get User UID

Admin goes to Firebase Console:
```
Firebase Console → Authentication → Users tab
Find: juan@cooperative.com
Copy: User UID (e.g., vK2m9nR4ioPxY7zQ...)
```

#### 3. Assign Cooperative Role

**Option A - Using Admin Tool**:
```
Admin Dashboard → Create Cooperative Account
→ "Assign Cooperative Role to Existing User"
→ Enter UID: vK2m9nR4ioPxY7zQ...
→ Click "Assign Cooperative Role"
→ Success! ✅
```

**Option B - Direct Firestore**:
```
Firestore → users → vK2m9nR4ioPxY7zQ...
→ Edit document
→ Add/Update field: role = "cooperative"
→ Save
```

#### 4. User Logs In

User logs in with same credentials:
```
Email: juan@cooperative.com
Password: Juan123!
```

Now user has access to:
- ✅ Regular buyer features
- ✅ Cooperative Dashboard (from admin menu or direct access)
- ✅ All order management features
- ✅ Payment collection features

---

## 🔍 Verifying Access

### Test Cooperative Account

1. **Logout from Admin**
2. **Login as Cooperative User**
   ```
   Email: (cooperative account email)
   Password: (their password)
   ```

3. **Navigate to Dashboard**
   ```
   Menu → Cooperative Dashboard
   OR
   Admin Dashboard → Cooperative Dashboard (if they're also admin)
   ```

4. **Verify Access**
   - ✅ Can see Overview tab with statistics
   - ✅ Can see Deliveries tab with all delivery orders
   - ✅ Can see Pickups tab with all pickup orders
   - ✅ Can see Payments tab with payment tracking
   - ✅ Can update order statuses
   - ✅ Can mark COD as collected

### Test Non-Cooperative Account

1. **Login as Regular User (buyer/seller)**
2. **Try to Access Dashboard**
   ```
   Navigate to Cooperative Dashboard
   ```

3. **Should See**:
   ```
   ⛔ Access Denied
   
   Only cooperative staff and administrators
   can access this dashboard.
   
   Your current role: buyer
   ```

---

## 👥 Managing Multiple Cooperative Staff

### Best Practices

1. **Create Individual Accounts**
   - Each staff member gets their own account
   - Don't share credentials

2. **Track Staff Members**
   - Maintain list of cooperative staff
   - Document who has access

3. **Remove Access When Needed**
   - Change role back to 'buyer' when staff leaves
   - Or disable account in Firebase Authentication

### Example Staff List

| Name | Email | UID | Date Added | Status |
|------|-------|-----|------------|--------|
| Juan Dela Cruz | juan@coop.com | vK2m9nR4io... | Oct 18, 2025 | Active |
| Maria Santos | maria@coop.com | pX3n8mT5kp... | Oct 20, 2025 | Active |
| Pedro Reyes | pedro@coop.com | qY4o9nU6lq... | Oct 15, 2025 | Removed |

---

## 🔄 Revoking Access

### Remove Cooperative Role

#### Method 1: Admin Tool (Future Enhancement)
Not yet implemented - coming soon

#### Method 2: Firestore Direct
1. Firebase Console → Firestore → users
2. Find user document
3. Change `role: 'cooperative'` to `role: 'buyer'`
4. Save
5. User loses access immediately

#### Method 3: Disable Account
1. Firebase Console → Authentication
2. Find user
3. Click ⋮ (three dots) → Disable user
4. Account cannot login

---

## 🛡️ Security Best Practices

### For Admins

1. **Verify Identity**
   - Confirm person's identity before granting access
   - Check with cooperative management

2. **Limited Access**
   - Only create accounts for actual staff members
   - Don't create test accounts with cooperative role

3. **Monitor Activity**
   - Regularly review cooperative staff list
   - Check for unused accounts

4. **Strong Passwords**
   - Require strong passwords (min 8 characters)
   - Mix of letters, numbers, symbols

5. **Regular Audits**
   - Review who has access monthly
   - Remove inactive accounts

### For Cooperative Staff

1. **Keep Credentials Secure**
   - Don't share login credentials
   - Use strong passwords

2. **Logout When Done**
   - Always logout after shift
   - Especially on shared devices

3. **Report Issues**
   - Report suspicious activity
   - Report lost/compromised credentials

---

## 📊 Firestore Structure

### User Document with Cooperative Role

```json
{
  "users": {
    "vK2m9nR4ioPxY7zQ3aB1cD2e": {
      "name": "Juan Dela Cruz",
      "email": "juan@cooperative.com",
      "role": "cooperative",
      "phone": "09123456789",
      "address": "123 Main St, Manila",
      "createdAt": Timestamp,
      "updatedAt": Timestamp,
      "status": "active"
    }
  }
}
```

### Required Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | String | ✅ Yes | Full name of staff |
| `email` | String | ✅ Yes | Email address (login) |
| `role` | String | ✅ Yes | Must be "cooperative" |
| `phone` | String | ⚠️ Recommended | Contact number |
| `createdAt` | Timestamp | ✅ Yes | Account creation date |
| `updatedAt` | Timestamp | ⚠️ Recommended | Last update date |

---

## ❓ Troubleshooting

### Issue: User Can't Access Dashboard

**Check**:
1. User role in Firestore is exactly `"cooperative"` (lowercase)
2. User is logged in
3. Firestore rules are deployed
4. User refreshed/reloaded app after role assignment

**Fix**:
```
Firestore → users → [user document]
→ Verify: role = "cooperative"
→ If different, update to "cooperative"
→ Save
→ User logout and login again
```

### Issue: Admin Tool Shows "Access Required"

**Cause**: Current user is not admin

**Fix**:
1. Login as admin first
2. Verify admin role in Firestore
3. Check: `users/[uid]/role = "admin"`

### Issue: Can't Find User UID

**Steps**:
1. Firebase Console
2. Authentication tab
3. Users sub-tab
4. Search by email
5. UID is in first column (long string)
6. Click to copy

---

## 📚 Related Documentation

- **Dashboard Guide**: `COOPERATIVE_DASHBOARD_GUIDE.md`
- **Implementation**: `COOPERATIVE_DASHBOARD_IMPLEMENTATION.md`
- **Quick Reference**: `COOP_DASHBOARD_QUICK_REFERENCE.md`
- **Delivery Model**: `COOPERATIVE_DELIVERY_MODEL.md`

---

## ✅ Checklist for Creating Account

- [ ] Verify person is authorized staff member
- [ ] Decide: New account or existing user
- [ ] If existing: Get User UID from Firebase Console
- [ ] Use Admin Tool to assign cooperative role
- [ ] Verify role updated in Firestore
- [ ] Test login with cooperative credentials
- [ ] Verify dashboard access works
- [ ] Document staff member in your records
- [ ] Provide dashboard training to staff

---

## 🎯 Summary

### Key Points

1. **Only admins** can create cooperative accounts
2. **Cooperative role** (`role: 'cooperative'`) grants dashboard access
3. **Regular users** cannot access cooperative dashboard
4. **Access is restricted** at code level and Firestore rules
5. **Multiple methods** available to create accounts
6. **Admin tool** is easiest method
7. **Direct Firestore** works but requires Firebase Console access
8. **Production** should use Firebase Admin SDK

### Quick Commands

**Assign Role via Admin Tool**:
```
Admin Dashboard → Create Cooperative Account → 
Enter UID → Assign Cooperative Role
```

**Direct Firestore Update**:
```
Firestore → users → [uid] → role: "cooperative"
```

**Verify Access**:
```
Login as user → Try to access Cooperative Dashboard
Should see: Dashboard (if cooperative) or Access Denied (if not)
```

---

**Created**: October 2025  
**For**: E-commerce Cooperative Platform  
**Access**: Admins Only  
**Purpose**: Secure cooperative staff account creation
