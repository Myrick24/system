# PayMongo Dashboard Troubleshooting Guide

## ✅ Fix Applied

The code has been updated to automatically create a **Payment** from the GCash source when the payment is successful. This ensures transactions appear in your PayMongo dashboard.

---

## 🔍 Why Transactions Might Not Appear

### **Issue #1: Test Mode vs Live Mode** ⭐ MOST COMMON

Your app is using **TEST API keys** (`sk_test_...`), which means:
- ✅ Transactions work perfectly
- ❌ But they ONLY appear in **Test Mode** dashboard
- ❌ NOT visible in Live Mode dashboard

#### Solution:

1. Go to https://dashboard.paymongo.com
2. Look at the **top navigation bar** (or top right corner)
3. Find the **"Test Mode" toggle switch**
4. **Make sure "Test Mode" is ON/ENABLED** (usually appears as a toggle or badge)
5. Navigate to **Payments** in the sidebar
6. Your transactions should now be visible!

![PayMongo Test Mode](https://developers.paymongo.com/docs/test-mode)

**Current API Keys in Your App:**
```dart
static const String _publicKey = 'pk_test_4tUiAUKKHASyG6h6VWMLjJhH';  // TEST key
static const String _secretKey = 'sk_test_KiH6sokR7sk8UnqoMzUHRmHb';  // TEST key
```

The `_test_` in the keys means **Test Mode**.

---

### **Issue #2: Sources vs Payments**

Previously, your app was only creating **Sources** (which don't show in dashboard). The fix added automatic **Payment** creation.

#### What the Fix Does:

```
Old Flow:
Create Source → User pays → Source = "chargeable" → STOP ❌
(Nothing in dashboard)

New Flow (FIXED):
Create Source → User pays → Source = "chargeable" → Create Payment ✅
(Transaction appears in dashboard!)
```

---

## 📊 How to Check Your Dashboard

### Step 1: Access Dashboard
1. Go to https://dashboard.paymongo.com
2. Log in with your PayMongo account

### Step 2: Enable Test Mode
1. Look for **"Test Mode"** toggle at the top
2. **Turn it ON** (if using test keys)
3. The interface might change color (usually darker or with "TEST" badge)

### Step 3: View Payments
1. Click **"Payments"** in the left sidebar
2. You should see a list of transactions
3. Each transaction shows:
   - Payment ID
   - Amount
   - Status (paid, failed, pending)
   - Payment method (GCash)
   - Date & time

### Step 4: Filter by Payment Method
1. Look for filter options at the top
2. Select **"GCash"** to see only GCash transactions
3. You can also filter by date range

---

## 🧪 Testing the Fix

### Test Transaction:

1. **Run your app:**
   ```powershell
   cd c:\Users\Mikec\system\e-commerce-app
   flutter run
   ```

2. **Make a test purchase:**
   - Select a product
   - Choose **GCash** as payment method
   - Complete checkout
   - Click "Open GCash App"

3. **Complete payment** (use test credentials):
   - Mobile: Any 10-digit number (e.g., 09123456789)
   - OTP: 123456
   - Amount: Should match your order total

4. **Watch the console logs:**
   ```
   🔍 Checking payment status for source: src_xxxxx
   💳 Payment status: chargeable
   ✅ Payment successful! Status: chargeable
   Source is chargeable - creating Payment to record transaction
   Creating Payment from source: src_xxxxx
   ✅ Payment created: pay_xxxxx with status: paid
   ✅ Payment created successfully in PayMongo dashboard
   ```

5. **Check PayMongo Dashboard:**
   - Go to https://dashboard.paymongo.com
   - **Enable Test Mode** toggle
   - Click "Payments"
   - Your transaction should appear with:
     - Payment ID: `pay_xxxxx`
     - Amount: Your order total
     - Status: Paid
     - Method: GCash

---

## 🔐 Test Mode vs Live Mode Explained

| Feature | Test Mode | Live Mode |
|---------|-----------|-----------|
| API Keys | `sk_test_...` | `sk_live_...` |
| Real Money | No ❌ | Yes ✅ |
| Real GCash Account | Not required | Required |
| Dashboard View | Separate "Test" view | Main dashboard |
| Test Credentials | 09123456789 / OTP: 123456 | Real phone & OTP |
| Transactions | Visible in Test Mode only | Visible in Live Mode only |

**Important:** Test and Live transactions are **completely separate**. You cannot see test transactions in live mode or vice versa.

---

## 🚨 Common Mistakes

### ❌ Mistake #1: Looking at Live Dashboard with Test Keys
**Problem:** Using test keys but checking live dashboard
**Solution:** Toggle to Test Mode in dashboard

### ❌ Mistake #2: Not Creating Payment from Source
**Problem:** Only creating Source, not Payment
**Solution:** ✅ Already fixed in the code update!

### ❌ Mistake #3: Using Wrong API Keys
**Problem:** Using test keys but expecting live transactions
**Solution:** Make sure dashboard mode matches your API key type

---

## 🔧 Verification Checklist

Use this checklist to verify everything is working:

- [ ] **API Keys Match Mode**
  - Using `sk_test_` keys? → Check Test Mode dashboard ✅
  - Using `sk_live_` keys? → Check Live Mode dashboard ✅

- [ ] **Dashboard Settings**
  - [ ] Logged into https://dashboard.paymongo.com
  - [ ] Test Mode toggle is ON (if using test keys)
  - [ ] Viewing "Payments" section (not just "Sources")

- [ ] **Code Updated**
  - [ ] Latest changes pulled/saved
  - [ ] `createPaymentFromSource()` method exists in paymongo_service.dart
  - [ ] `checkPaymentStatus()` calls `createPaymentFromSource()` when status is "chargeable"

- [ ] **Test Transaction**
  - [ ] Completed a test GCash payment
  - [ ] Saw success message in app
  - [ ] Console shows "Payment created successfully"
  - [ ] Transaction appears in PayMongo dashboard

---

## 📱 PayMongo Dashboard Navigation

### Desktop View:
```
┌─────────────────────────────────────────┐
│  PayMongo Logo    [Test Mode: ON] 👤   │ ← Toggle here
├─────────────────────────────────────────┤
│ 📊 Dashboard                            │
│ 💳 Payments        ← Click here         │
│ 🔄 Sources                              │
│ 📝 Payment Intents                      │
│ 🎯 Payment Methods                      │
│ ⚙️  Settings                            │
└─────────────────────────────────────────┘
```

### Mobile View:
- Tap hamburger menu (≡)
- Look for "Test Mode" toggle at top
- Navigate to "Payments"

---

## 🆘 Still Not Showing?

If transactions still don't appear after following all steps:

### 1. Verify API Keys Are Correct
Check `lib/services/paymongo_service.dart`:
```dart
static const String _secretKey = 'sk_test_KiH6sokR7sk8UnqoMzUHRmHb';
```

Go to https://dashboard.paymongo.com/developers/api-keys and verify this key exists.

### 2. Check Console Logs
After completing payment, you should see:
```
✅ Payment created: pay_xxxxx with status: paid
```

If you see errors instead:
```
❌ Payment creation failed: [error message]
```
Copy the error message - it will tell you what's wrong.

### 3. Try a Fresh Test Transaction
- Clear app data/cache
- Make a new test purchase
- Watch console logs carefully
- Check dashboard immediately after payment

### 4. Check PayMongo API Status
Go to https://status.paymongo.com to verify PayMongo services are operational.

### 5. Contact PayMongo Support
If nothing works:
- Email: support@paymongo.com
- Provide:
  - Your merchant ID
  - Payment source ID (from console logs)
  - Timestamp of transaction
  - Error messages (if any)

---

## 📖 PayMongo Documentation

- **Dashboard Guide:** https://developers.paymongo.com/docs/dashboard
- **Payments API:** https://developers.paymongo.com/docs/payments
- **Sources API:** https://developers.paymongo.com/docs/sources
- **GCash Integration:** https://developers.paymongo.com/docs/gcash
- **Test Credentials:** https://developers.paymongo.com/docs/testing

---

## ✅ Quick Check Command

Run this in your app to test if payment creation works:

```dart
// In your Flutter console, look for these logs:
🔍 Checking payment status for source: src_xxxxx
💳 Payment status: chargeable
Source is chargeable - creating Payment to record transaction
Creating Payment from source: src_xxxxx
Payment creation response: 201
✅ Payment created: pay_xxxxx with status: paid
✅ Payment created successfully in PayMongo dashboard
```

If you see all these logs, your transaction **IS** in the dashboard - just make sure you're looking at **Test Mode**!

---

## 🎯 Summary

**The fix is complete.** Your transactions now:
1. ✅ Create a Source (for user to pay)
2. ✅ Automatically create a Payment (for dashboard)
3. ✅ Appear in PayMongo dashboard

**Most likely issue:** You're looking at **Live Mode** when you should be looking at **Test Mode**.

**Solution:** Toggle to Test Mode in your PayMongo dashboard!

---

**Last Updated:** December 1, 2025
**Fix Applied By:** GitHub Copilot
