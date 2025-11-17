# 🔔 Background Notifications - Quick Start

## ⚡ Deploy Now (3 Steps)

### Option 1: Using PowerShell Script
```powershell
cd e-commerce-app
.\deploy-functions.ps1
```

### Option 2: Manual Steps
```powershell
# 1. Install dependencies
cd e-commerce-app\functions
npm install

# 2. Build TypeScript
npm run build

# 3. Deploy to Firebase
cd ..
firebase deploy --only functions
```

---

## ✅ Verify Deployment

```powershell
firebase functions:list
```

**Expected Output:**
- ✅ onNotificationCreated
- ✅ onCooperativeNotificationCreated  
- ✅ onProductApproved
- ✅ onOrderCreated

---

## 🧪 Test Immediately

### Test 1: Close app and place order
1. **Close app** completely
2. **Place order** from web or another device
3. **Check phone** - notification should appear!

### Test 2: Background test
1. **Open app** and login
2. **Press home button** (app goes to background)
3. **Approve product** from admin dashboard
4. **Check notification tray** - new notification!

### Test 3: Force stopped test
1. **Settings → Apps → Harvest App → Force Stop**
2. **Create notification** (order, product approval, etc.)
3. **Wait 2-3 seconds**
4. **Notification appears!** ✨

---

## 📊 How Notifications Work Now

### Before (App Must Be Open) ❌
```
User Action → Firestore → [App Open?] → ❌ No notification
```

### After (Works Always) ✅
```
User Action → Firestore → Cloud Function → FCM → 📱 Device
                              ↓
                          Works 24/7
                     (closed/background/open)
```

---

## 🔍 Monitor & Debug

### View Logs
```powershell
firebase functions:log
```

### Live Monitoring
```powershell
firebase functions:log --only onNotificationCreated
```

### Check User FCM Token
Firestore Console → `users/{userId}` → Check `fcmToken` field exists

---

## 🚨 Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| No notification received | No FCM token | Re-login to app |
| Function not triggering | Not deployed | Run deploy script |
| "Token not found" error | User doc missing token | User needs to open app once |
| Notification shows but no sound | Channel settings | Check phone notification settings |

---

## 📝 What Each Function Does

### `onNotificationCreated`
- **Triggers:** When doc added to `notifications/`
- **Sends to:** User specified in `userId` field
- **Use:** Orders, approvals, general notifications

### `onCooperativeNotificationCreated`
- **Triggers:** When doc added to `cooperative_notifications/`
- **Sends to:** Cooperative specified in `userId` field
- **Use:** Seller applications, product submissions

### `onProductApproved`
- **Triggers:** When product status → "approved"
- **Sends to:** ALL buyers in system
- **Use:** New product alerts

### `onOrderCreated`
- **Triggers:** When doc added to `orders/`
- **Sends to:** Seller specified in `sellerId` field
- **Use:** New order alerts for sellers

---

## 🎯 Success Checklist

After deployment, verify:

- [ ] Functions deployed successfully
- [ ] Functions appear in `firebase functions:list`
- [ ] Test notification with app closed works
- [ ] Test notification with app in background works
- [ ] Logs show "Successfully sent notification"
- [ ] Users receive notifications on their devices
- [ ] Tapping notification opens the app
- [ ] Sound and vibration work

---

## 🆘 Need Help?

### Check Deployment Status
```powershell
firebase functions:list
```

### Re-deploy Specific Function
```powershell
firebase deploy --only functions:onNotificationCreated
```

### Delete and Re-deploy All
```powershell
firebase functions:delete onNotificationCreated onCooperativeNotificationCreated onProductApproved onOrderCreated
firebase deploy --only functions
```

---

## 📚 Full Documentation

See **BACKGROUND_NOTIFICATIONS_COMPLETE.md** for:
- Complete architecture overview
- Detailed testing procedures
- Customization options
- Troubleshooting guide
- Maintenance instructions

---

**Status:** ✅ Ready to Deploy  
**Time to Deploy:** ~3-5 minutes  
**Works When App:** Closed, Background, or Open ✨
