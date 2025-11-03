# ✅ FIREBASE OTP SETUP CHECKLIST

## ⚠️ IMPORTANT: OTP Verification is REQUIRED

**Account creation now requires successful OTP verification via SMS.**
Users CANNOT create accounts without completing OTP verification.

This means you MUST complete the Firebase Phone Auth setup below for the app to work properly.

---

## Your SHA Certificates:
```
SHA-1:   19:35:7F:2B:35:C1:2C:CF:C1:31:16:5D:AE:AA:32:B9:6B:D2:00:04
SHA-256: 74:B3:D4:E5:89:9B:A1:DF:19:CE:AF:55:E3:B5:ED:F2:8D:88:B1:B2:38:03:AF:F3:7D:9F:49:ED:6E:A1:B7:14
```

---

## 🎯 Complete These Steps:

### 1️⃣ Firebase Console Setup (5 minutes)

- [ ] Go to: https://console.firebase.google.com
- [ ] Select your project
- [ ] Go to Project Settings (⚙️ icon)
- [ ] Scroll to "Your apps" → Find Android app
- [ ] Click "Add fingerprint" → Paste SHA-1 → Save
- [ ] Click "Add fingerprint" → Paste SHA-256 → Save
- [ ] Download new google-services.json
- [ ] Replace file at: `android/app/google-services.json`

### 2️⃣ Enable Phone Authentication

- [ ] Firebase Console → Authentication
- [ ] Sign-in method tab
- [ ] Click "Phone"
- [ ] Toggle Enable to ON
- [ ] Click Save

### 3️⃣ Add Test Numbers (Optional but Recommended)

- [ ] Authentication → Sign-in method → Phone
- [ ] Scroll to "Phone numbers for testing"
- [ ] Add: `+639123456789` with code `123456`
- [ ] Add: `+639987654321` with code `654321`
- [ ] Save

### 4️⃣ Clean Build

Run these commands:
```powershell
cd c:\Users\Mikec\system\e-commerce-app
flutter clean
flutter pub get
flutter run
```

- [ ] Run flutter clean
- [ ] Run flutter pub get
- [ ] Run flutter run

### 5️⃣ Test OTP

**Option A - With Test Number (No SMS):**
- [ ] Sign up with `09123456789`
- [ ] Enter OTP: `123456`
- [ ] Success!

**Option B - With Real Number (Real SMS):**
- [ ] Sign up with your real number
- [ ] Receive SMS with OTP
- [ ] Enter the OTP from SMS
- [ ] Success!

---

## ⚡ Quick Commands

Copy and paste in PowerShell:
```powershell
# Go to project
cd c:\Users\Mikec\system\e-commerce-app

# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

---

## 🎉 What's Already Done

✅ OTP verification screen created
✅ Phone authentication code implemented  
✅ SHA certificates retrieved
✅ Auto-focus between OTP digits
✅ Resend OTP functionality
✅ 60-second cooldown timer
✅ Green theme matching your app
✅ Direct login after verification
✅ Comprehensive error handling

---

## 📱 Expected Flow

1. User fills signup form
2. Clicks "Create Account"
3. OTP sent to mobile (via SMS)
4. **OTP Verification Screen appears** ← This is what you wanted!
5. User enters 6-digit OTP
6. Account created
7. Redirects to Dashboard

---

## 🔥 Important Notes

- **SHA certificates** are required for phone auth to work
- **Without SHA certs**, you'll get INVALID_CERT_HASH error
- **Test numbers** let you test without real SMS (perfect for development!)
- **Real SMS** will work once you complete setup

---

## ❓ Questions?

**Q: Why do I need SHA certificates?**
A: Firebase uses them to verify your app's identity for security.

**Q: Can I test without real SMS?**
A: Yes! Use test phone numbers in Firebase Console.

**Q: How long does setup take?**
A: About 5 minutes if you follow the checklist.

**Q: Will it work in production?**
A: Yes! You'll need to add release SHA certificates when publishing.

---

## 🚀 You're Almost There!

Just complete the checklist above and your OTP system will be fully functional! 🎊
