# Firebase Phone Authentication Setup Guide

## Overview
This guide will help you set up Firebase Phone Authentication (SMS OTP) for your e-commerce app.

## The Error You're Seeing
```
Error: INVALID_CERT_HASH
Failed to initialize reCAPTCHA config
Invalid PlayIntegrity token; app not Recognized by Play Store
```

These errors occur because:
1. Your app's SHA-1/SHA-256 certificates are not registered in Firebase
2. Firebase Phone Auth needs these certificates for security verification

---

## Step 1: Get Your SHA-1 and SHA-256 Certificates

### Option A: Using Keytool (Debug Certificate)

Open PowerShell in your project folder and run:

```powershell
cd android
./gradlew signingReport
```

This will output your SHA-1 and SHA-256 certificates. Look for the **debug** section:

```
Variant: debug
Config: debug
Store: C:\Users\YourName\.android\debug.keystore
Alias: AndroidDebugKey
MD5: XX:XX:XX:...
SHA1: AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:00:AA:BB:CC:DD
SHA-256: AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:00:AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:00:AA:BB
```

**Copy both SHA-1 and SHA-256 values!**

### Option B: Manual Keytool Command

If gradlew doesn't work, use this command:

**For Debug Keystore:**
```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**For Release Keystore (if you have one):**
```powershell
keytool -list -v -keystore path\to\your\release.keystore -alias your-key-alias
```

---

## Step 2: Add SHA Certificates to Firebase Console

1. **Go to Firebase Console**: https://console.firebase.google.com
2. **Select your project**: `e-commerce` or your project name
3. **Click the gear icon** (⚙️) next to Project Overview → **Project settings**
4. **Scroll down** to "Your apps" section
5. **Find your Android app**: `com.example.e_commerce`
6. **Click "Add fingerprint"** button
7. **Paste your SHA-1** certificate → Click Save
8. **Click "Add fingerprint"** again
9. **Paste your SHA-256** certificate → Click Save

**IMPORTANT**: Add BOTH debug AND release certificates if you have them!

---

## Step 3: Download Updated google-services.json

1. **Still in Firebase Console** → Project Settings → Your apps
2. **Click "google-services.json"** download button
3. **Replace** the old file at:
   ```
   e-commerce-app/android/app/google-services.json
   ```
4. **Restart your app** completely

---

## Step 4: Enable Phone Authentication in Firebase

1. **Go to Firebase Console** → Authentication
2. **Click "Sign-in method"** tab
3. **Find "Phone"** in the providers list
4. **Click on "Phone"**
5. **Toggle "Enable"** to ON
6. **Click "Save"**

---

## Step 5: Configure Android App (Already Done)

Your `android/app/build.gradle` already has the necessary configuration:

```gradle
plugins {
    id 'com.google.gms.google-services'  // ✓ Already added
}

android {
    minSdk = 23  // ✓ Phone Auth requires API 23+
}
```

---

## Step 6: Clean Build and Test

After completing all steps above, run:

```powershell
cd c:\Users\Mikec\system\e-commerce-app
flutter clean
flutter pub get
flutter run
```

---

## Step 7: Test Phone Authentication

1. **Open the app**
2. **Go to Sign Up screen**
3. **Fill in all fields** including mobile number (09xxxxxxxxx)
4. **Click "Create Account"**
5. **You should see OTP screen** instead of errors
6. **Enter the OTP** received via SMS
7. **Account should be created** and redirected to dashboard

---

## Troubleshooting

### Issue 1: Still Getting INVALID_CERT_HASH
**Solution**: Make sure you added the CORRECT SHA certificates. Run `gradlew signingReport` again and double-check.

### Issue 2: Not Receiving SMS
**Possible causes**:
- Phone number format is wrong (must be +639xxxxxxxxx)
- Firebase project has SMS quota limits
- Test mode not configured for specific numbers

**Solution for Testing**: Add test phone numbers in Firebase Console:
1. Authentication → Sign-in method → Phone
2. Scroll to "Phone numbers for testing"
3. Add: `+639123456789` with OTP: `123456`
4. Now you can test without real SMS

### Issue 3: reCAPTCHA Issues
**Solution**: Firebase will use SafetyNet/Play Integrity after you add SHA certificates. If still failing, enable test mode (see Issue 2).

### Issue 4: "App not recognized by Play Store"
**Solution**: This is normal in development. After adding SHA certificates, Firebase will use reCAPTCHA fallback which works fine.

---

## For Production Release

When you're ready to publish on Play Store:

1. **Generate release keystore** (if not done):
   ```powershell
   keytool -genkey -v -keystore release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias release-key
   ```

2. **Get release SHA certificates**:
   ```powershell
   keytool -list -v -keystore release-keystore.jks -alias release-key
   ```

3. **Add release SHA-1 and SHA-256** to Firebase Console (same as Step 2)

4. **Download updated google-services.json**

5. **Configure signing in android/app/build.gradle**:
   ```gradle
   signingConfigs {
       release {
           keyAlias 'release-key'
           keyPassword 'your-key-password'
           storeFile file('release-keystore.jks')
           storePassword 'your-store-password'
       }
   }
   buildTypes {
       release {
           signingConfig signingConfigs.release
       }
   }
   ```

---

## Quick Test Mode Setup (Recommended for Development)

To test WITHOUT needing real SMS:

1. **Firebase Console** → Authentication → Sign-in method → Phone
2. **Scroll to "Phone numbers for testing"**
3. **Add test numbers**:
   - Phone: `+639123456789`, Code: `123456`
   - Phone: `+639987654321`, Code: `654321`
4. **Save**
5. **Use these numbers** when signing up
6. **Use the fixed OTP code** (e.g., `123456`)
7. **No SMS will be sent**, but verification will work!

---

## Summary of Required Steps

- [ ] Run `gradlew signingReport` to get SHA-1 and SHA-256
- [ ] Add both SHA certificates to Firebase Console
- [ ] Download new google-services.json
- [ ] Enable Phone authentication in Firebase Console
- [ ] (Optional) Add test phone numbers for easy testing
- [ ] Run `flutter clean && flutter pub get && flutter run`
- [ ] Test signup with OTP!

---

## Need Help?

If you still face issues after following this guide:

1. Share the complete error from `flutter run` console
2. Verify you added SHA certificates correctly in Firebase Console
3. Verify google-services.json is updated
4. Try with test phone numbers first (no real SMS needed)

---

**Note**: The OTP verification screen is already implemented in your app! Once you complete the Firebase setup above, everything will work smoothly with real SMS OTP. 📱✅
