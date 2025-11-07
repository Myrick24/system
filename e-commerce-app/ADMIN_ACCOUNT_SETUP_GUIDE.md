# Admin Account Setup Guide

## Option 1: Using the Admin Setup Tool in the App (Recommended)

The app has a built-in Admin Setup Tool that creates admin accounts directly. 

### Steps:
1. Navigate to the Admin Setup Tool in your Flutter app
2. Fill in the following details:
   - **Admin Name**: Enter a name for the admin (e.g., "System Admin")
   - **Admin Email**: Enter email (e.g., admin@ecommerce.com)
   - **Admin Password**: Enter a secure password

3. Click "Create Admin User"
4. Save the User UID that appears in the success message

The tool creates:
- A Firebase Authentication account with the provided email/password
- A user document in Firestore with role set to 'admin'

---

## Option 2: Using Firebase Console (Direct Database Setup)

If you prefer to create the admin account manually through Firebase Console:

### Step 1: Create Authentication User
1. Go to Firebase Console → Authentication
2. Create a new user with:
   - Email: admin@ecommerce.com
   - Password: (set a secure password)
3. Copy the User UID

### Step 2: Create Admin Document in Firestore
1. Go to Firebase Console → Firestore Database
2. Create a new document in the `users` collection with:
   - Document ID: (paste the User UID from step 1)
   - Add the following fields:
     ```
     role: "admin"
     name: "System Admin"
     email: admin@ecommerce.com
     status: "active"
     createdAt: (current timestamp)
     ```

---

## Option 3: Using Flutter App Admin Setup Tool (Detailed Steps)

### Prerequisites:
- Have the Flutter app running
- Access to the admin setup tool (usually available in developer menu or tools)

### Credentials to Use:
**Default Admin Account (Example):**
- Name: System Admin
- Email: admin@ecommerce.com  
- Password: Admin@123456

### What Gets Created:
- ✅ Firebase Authentication account
- ✅ User document in `users` collection
- ✅ Role set to 'admin'
- ✅ Status set to 'active'
- ✅ Created timestamp

---

## How to Access Admin Dashboard After Setup

1. Open the app and go to Login
2. Enter the admin email and password you created
3. You'll be automatically redirected to the Admin Dashboard
4. The system checks the `role: 'admin'` field in the users collection

---

## Database Schema for Admin User

```
Collection: users
Document ID: {user_uid}
Fields:
├── role: "admin"
├── name: "System Admin"
├── email: "admin@ecommerce.com"
├── status: "active"
└── createdAt: {timestamp}
```

---

## Troubleshooting

### Admin can't login
- ✅ Check if authentication user exists in Firebase Console
- ✅ Check if user document exists in Firestore with role: "admin"
- ✅ Verify email and password are correct

### Dashboard not loading
- ✅ Confirm role field is set to "admin" (not "Admin" or other variations)
- ✅ Check Firestore security rules allow admin access
- ✅ Verify user status is "active"

### Create another admin account
- Repeat the same steps with different email address
- Admin accounts can be created multiple times

---

## Quick Start

**To quickly add an admin account:**

1. Use the Admin Setup Tool in the app with:
   ```
   Name: Admin
   Email: admin@example.com
   Password: Admin@123456
   ```

2. The system will create both:
   - Firebase Auth user
   - Firestore user document with role='admin'

3. Login with the email and password

That's it! Your admin account is ready to use.
