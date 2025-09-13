# Firebase Admin SDK Setup Guide

## The Problem
Your script is getting a "Missing or insufficient permissions" error because it's using the Firebase client SDK, which requires user authentication and is subject to Firestore security rules. To perform admin operations like bulk updates, you need to use the Firebase Admin SDK.

## Solution Steps

### Step 1: Generate a Service Account Key

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `e-commerce-app-5cda8`
3. Click the gear icon ⚙️ next to "Project Overview" → "Project settings"
4. Click on the "Service accounts" tab
5. Click "Generate new private key"
6. Click "Generate key" to download the JSON file
7. Save the file as `firebase-admin-key.json` in your `ecommerce-web-admin` folder

### Step 2: Set Environment Variable

Open PowerShell and run:
```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="d:\capstone-system\ecommerce-web-admin\firebase-admin-key.json"
```

### Step 3: Run the Fixed Script

```powershell
cd d:\capstone-system\ecommerce-web-admin
node fix-seller-status-admin.js
```

## Alternative: Quick Fix Script (If you prefer not to download service account)

I can also create a script that temporarily modifies your Firestore rules to allow the operation, runs the fix, then restores the rules. This is less secure but works for one-time fixes.

## What This Will Fix

The script will:
1. Find all users with role='seller' and status='approved'
2. Update the corresponding documents in the 'sellers' collection to have status='approved'
3. This ensures both collections are synchronized

## Security Note

The service account key gives full admin access to your Firebase project. Keep it secure and don't commit it to version control.
