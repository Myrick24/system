# PayMongo GCash Payment Testing Guide

## 🧪 How to Test the Fix

### Step 1: Run the App
```powershell
cd c:\Users\Mikec\system\e-commerce-app
flutter run
```

### Step 2: Make a Test Purchase
1. Select any product in your app
2. Choose **GCash** as payment method
3. Complete the checkout process
4. You'll see the PayMongo GCash payment screen

### Step 3: Complete Test Payment
When you see the page: **"GCash Test Payment Page"**

1. Click **"Authorize Test Payment"** button
2. The payment will be automatically approved
3. Wait for the app to detect the payment (3-5 seconds)

### Step 4: Watch Console Logs

You should see these logs in order:

```
🔍 Checking payment status for source: src_xxxxx
💳 Payment status: chargeable
✅ Payment successful! Status: chargeable
🔥 Source is chargeable - creating Payment to record transaction
📊 Amount in centavos: 3500
💰 Creating Payment from source: src_xxxxx
💵 Amount: 3500 centavos (₱35.0)
📤 Payment request: {"data":{"attributes":{...}}}
📥 Payment creation response: 200 or 201
📄 Response body: {...}
✅ SUCCESS! Payment created in PayMongo dashboard
🆔 Payment ID: pay_xxxxx
📊 Status: paid
✅ Payment created successfully in PayMongo dashboard
💳 Payment ID: pay_xxxxx
```

### Step 5: Check PayMongo Dashboard

1. Go to https://dashboard.paymongo.com
2. **Toggle "Test Mode" ON** (top right corner)
3. Click **"Payments"** in the sidebar
4. You should see your transaction with:
   - Payment ID: `pay_xxxxx` (from console)
   - Amount: ₱35.00
   - Status: Paid
   - Payment Method: GCash
   - Date: Today's date

---

## 🔍 Troubleshooting

### Issue 1: No logs appear
**Problem:** App not checking payment status
**Solution:** 
- Make sure you clicked "Authorize Test Payment"
- Check if app is still running
- Restart the app and try again

### Issue 2: "Source is chargeable" but no Payment creation
**Problem:** Payment creation failing
**Look for:** Error logs like:
```
❌ Payment creation FAILED with status: 400
❌ Error response: {...}
```

**Common errors:**

#### Error: "source has already been used"
**Cause:** Trying to create payment from already-used source
**Solution:** Make a new test transaction (old source can't be reused)

#### Error: "amount does not match"
**Cause:** Amount mismatch between source and payment
**Solution:** Already fixed in the code! Amount now passed correctly.

#### Error: "source is not chargeable"
**Cause:** Source expired or wasn't paid
**Solution:** Complete payment faster (source expires after 1 hour)

### Issue 3: Transaction not in dashboard
**Problem:** Looking at wrong mode
**Solution:**
1. Make sure **Test Mode is ON** in dashboard
2. Your API keys are test keys (`sk_test_`)
3. Test transactions ONLY appear in Test Mode
4. Toggle at top-right: **"Test Mode"** should be enabled/highlighted

### Issue 4: Payment shows as "pending"
**Problem:** Payment created but not captured
**Solution:** 
- GCash payments should auto-capture
- Check PayMongo dashboard → Payment details
- May need to wait a few seconds for status update

---

## 📊 What Each Log Means

| Log | Meaning | Action |
|-----|---------|--------|
| `🔍 Checking payment status` | App polling PayMongo API | ✅ Normal |
| `💳 Payment status: pending` | User hasn't paid yet | ⏳ Keep waiting |
| `💳 Payment status: chargeable` | User paid! | ✅ Creating Payment now |
| `🔥 Source is chargeable` | Starting Payment creation | ✅ Normal |
| `💰 Creating Payment from source` | Calling PayMongo Payments API | ✅ Normal |
| `📥 Payment creation response: 201` | Payment created successfully | ✅ Success! |
| `✅ SUCCESS! Payment created` | Transaction in dashboard | ✅ Check dashboard |
| `❌ Payment creation FAILED` | Error occurred | 🔍 Check error detail |

---

## ✅ Success Checklist

After completing a test payment:

- [ ] Saw "Authorize Test Payment" page
- [ ] Clicked "Authorize Test Payment" button
- [ ] App showed "Payment Successful!" dialog
- [ ] Console shows `✅ SUCCESS! Payment created in PayMongo dashboard`
- [ ] Console shows Payment ID: `pay_xxxxx`
- [ ] Went to https://dashboard.paymongo.com
- [ ] Test Mode is enabled (toggle ON)
- [ ] Clicked "Payments" in sidebar
- [ ] See transaction with correct amount
- [ ] Payment ID matches console log
- [ ] Status shows "Paid"
- [ ] Payment method is "GCash"

If ALL boxes checked ✅ = **Working perfectly!**

---

## 🎯 Quick Test Command

To verify the fix is working, look for this specific log:
```
✅ SUCCESS! Payment created in PayMongo dashboard
🆔 Payment ID: pay_xxxxx
```

If you see this, the transaction **IS** in your dashboard (in Test Mode).

---

## 📞 Still Having Issues?

### Get Debug Information:

1. Copy the **entire console output** after clicking "Authorize Test Payment"
2. Note the **Source ID** (src_xxxxx)
3. Check if you see **Payment ID** (pay_xxxxx)
4. Screenshot any error messages

### Check PayMongo API Status:
- Visit: https://status.paymongo.com
- Check if all services are operational

### Verify API Keys:
Go to: https://dashboard.paymongo.com/developers/api-keys
- Your secret key should be: `sk_test_KiH6sokR7sk8UnqoMzUHRmHb`
- If key is different, update in `lib/services/paymongo_service.dart`

---

## 🚀 Testing Tips

### Tip 1: Use Test Mode Always
- Test keys = Test mode dashboard
- Live keys = Live mode dashboard
- Never mix them!

### Tip 2: Fresh Transaction Each Time
- Each source can only be used once
- Make new purchase for each test
- Don't reuse old source IDs

### Tip 3: Check Immediately
- After payment success, check dashboard immediately
- Transaction appears within seconds
- Refresh page if needed

### Tip 4: Console is Your Friend
- Keep console visible while testing
- Logs tell you exactly what's happening
- Copy logs if reporting issues

---

## 📝 Expected Flow

```
1. User clicks "Place Order" with GCash
   ↓
2. App creates Source via PayMongo API
   Status: pending
   ↓
3. User sees "GCash Test Payment Page"
   ↓
4. User clicks "Authorize Test Payment"
   ↓
5. Source status → chargeable
   ↓
6. App detects "chargeable" status
   ↓
7. 🔥 App creates Payment from Source
   ↓
8. PayMongo API returns Payment ID
   ↓
9. ✅ Transaction appears in dashboard
   ↓
10. App shows "Payment Successful!"
```

---

## 🎉 Summary

**The fix is complete!** Your app now:
1. ✅ Creates GCash Source
2. ✅ Detects when user pays
3. ✅ Automatically creates Payment
4. ✅ Transaction appears in PayMongo dashboard

**Key Points:**
- Use **Test Mode** in dashboard for test keys
- Payment created automatically when source is chargeable
- Check console logs to verify everything works
- Payment ID in logs = Transaction in dashboard

**Last Updated:** December 1, 2025
