# 🔑 YOUR SHA FINGERPRINTS - COPY THESE TO FIREBASE

## ✅ Copy These Values to Firebase Console

### **SHA-1 Fingerprint:**
```
4E:54:79:C1:A5:C0:85:FF:6A:BE:56:D6:D3:AD:62:85:4F:1B:E9:7E
```

### **SHA-256 Fingerprint:**
```
06:89:8E:52:09:65:86:BA:7A:70:6F:58:E1:BF:89:FE:03:1F:58:9E:53:D6:38:AC:6A:07:52:19:C0:4B:6D:5E
```

---

## 📋 STEP-BY-STEP INSTRUCTIONS

### Step 1: Open Firebase Console
1. Go to: https://console.firebase.google.com/
2. Click on your project: **e-commerce-app-5cda8**

### Step 2: Open Project Settings
1. Click the **⚙️ gear icon** (top left)
2. Click **"Project settings"**

### Step 3: Find Your Android App
1. Scroll down to **"Your apps"** section
2. Look for your Android app: **com.example.e_commerce**
3. You should see it with package name and some settings

### Step 4: Add SHA-1 Fingerprint
1. Click **"Add fingerprint"** button
2. Paste this SHA-1:
   ```
   4E:54:79:C1:A5:C0:85:FF:6A:BE:56:D6:D3:AD:62:85:4F:1B:E9:7E
   ```
3. Click **"Save"**

### Step 5: Add SHA-256 Fingerprint
1. Click **"Add fingerprint"** button again
2. Paste this SHA-256:
   ```
   06:89:8E:52:09:65:86:BA:7A:70:6F:58:E1:BF:89:FE:03:1F:58:9E:53:D6:38:AC:6A:07:52:19:C0:4B:6D:5E
   ```
3. Click **"Save"**

### Step 6: Download New google-services.json
1. Still in the same screen, find the **download icon** for google-services.json
2. Click to download the file
3. The file will download to your Downloads folder

### Step 7: Replace the Old File
1. Navigate to: `d:\capstone-system - Copy\e-commerce-app\android\app\`
2. **DELETE** the old `google-services.json` file
3. **COPY** the newly downloaded `google-services.json` to this folder

### Step 8: Clean Build
Open PowerShell and run:
```powershell
cd "d:\capstone-system - Copy\e-commerce-app"
flutter clean
flutter pub get
cd android
.\gradlew clean
cd ..
```

### Step 9: Run the App
```powershell
flutter run
```

---

## ✅ Verification

After completing these steps, the new `google-services.json` should have:

```json
"oauth_client": [
  {
    "client_id": "630973639309-xxxxxxxxxx.apps.googleusercontent.com",
    "client_type": 3
  }
]
```

**This will NOT be empty anymore!**

---

## 🧪 Test Phone Authentication

### Add Test Number (Optional but Recommended):

1. Firebase Console → **Authentication**
2. Click **"Sign-in method"** tab
3. Find **"Phone"** and click on it
4. Scroll to **"Phone numbers for testing"**
5. Click **"Add phone number"**
6. Enter:
   - **Phone number:** `+639123456789`
   - **Verification code:** `123456`
7. Click **"Save"**

### Test Signup:

1. Open app
2. Click "Create an account"
3. Fill in all fields
4. Mobile number: `09123456789`
5. Click "Create Account"
6. Enter OTP: `123456`
7. Should work! ✅

---

## 🎯 Summary

**What you need to do:**

1. ✅ Copy SHA-1 fingerprint above
2. ✅ Copy SHA-256 fingerprint above
3. ✅ Add both to Firebase Console
4. ✅ Download new google-services.json
5. ✅ Replace old file
6. ✅ Run flutter clean
7. ✅ Run the app
8. ✅ Test signup/login

**This will fix the `missing-client-identifier` error!** 🚀

---

## 📞 Your Keystore Info

```
Store: C:\Users\myric\.android\debug.keystore
Alias: AndroidDebugKey
Valid until: Sunday, 24 October 2055
```

**Keep this keystore safe!** You'll need it for future builds.

---

## 🆘 If You Need Help

Check the full guide: **PHONE_AUTH_ERROR_FIX.md**
