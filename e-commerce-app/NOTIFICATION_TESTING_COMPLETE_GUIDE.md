# 🧪 Notification System Testing Guide

## Quick Start Testing

### Prerequisites
1. ✅ Firestore rules deployed
2. ✅ App running on device/emulator
3. ✅ Firebase project configured
4. ✅ FCM setup complete

---

## 🎯 Test Scenarios

### Test 1: Buyer Checkout Notification

**Steps:**
1. Login as a buyer
2. Browse products and add items to cart
3. Go to cart and click "Checkout"
4. Complete the checkout process
5. **Observe the home button and check notifications**

**Expected Results:**
- ✅ Buyer receives push notification: "✅ Order Confirmed!"
- ✅ Notification appears in device notification tray
- ✅ Firestore `notifications` collection has new entry with `type: checkout_buyer`
- ✅ Seller receives push notification: "🛒 New Purchase!"
- ✅ Firestore `seller_notifications` collection has new entry
- ✅ Order document created in `orders` collection

**Firestore Verification:**
```javascript
// Check notifications collection
notifications/
  - userId: [buyer_id]
    title: "✅ Order Confirmed!"
    type: "checkout_buyer"
    productName: "..."
    quantity: X
    totalAmount: $XX.XX
    read: false

// Check seller_notifications collection
seller_notifications/
  - sellerId: [seller_id]
    type: "new_order"
    productName: "..."
    buyerName: "..."
    needsApproval: true
```

---

### Test 2: Product Approval Notification

**Steps:**
1. Login as admin (web dashboard)
2. Navigate to pending products
3. Approve a product
4. **Check notifications on seller's device**

**Expected Results:**
- ✅ Seller receives: "✅ Product Approved"
- ✅ Buyers receive: "🆕 New Product Available!"
- ✅ Other sellers receive: "🆕 New Product Added"
- ✅ Multiple Firestore collections updated

**Firestore Verification:**
```javascript
// Seller notification
notifications/
  - userId: [seller_id]
    title: "Product Approved! 🎉"
    type: "product_approved"
    
// Buyer alerts
buyer_product_alerts/
  - productName: "..."
    sellerName: "..."
    category: "..."
    
// Seller market updates
seller_market_updates/
  - productName: "..."
    type: "new_product_market"
```

---

### Test 3: Seller Registration Approval

**Steps:**
1. User applies to become a seller
2. Login as admin
3. Approve the seller application
4. **Check user's device**

**Expected Results:**
- ✅ User receives: "🎉 Seller Account Approved!"
- ✅ User status updated to 'approved'
- ✅ Seller document status updated
- ✅ Notification stored in Firestore

**Firestore Verification:**
```javascript
// User document
users/[user_id]
  status: "approved"
  role: "seller"

// Notification
notifications/
  - userId: [user_id]
    title: "🎉 Seller Account Approved!"
    type: "seller_approved"
    priority: "high"
```

---

### Test 4: Product Rejection Notification

**Steps:**
1. Login as admin
2. Reject a pending product with a reason
3. **Check seller's device**

**Expected Results:**
- ✅ Seller receives: "❌ Product Rejected"
- ✅ Notification includes rejection reason
- ✅ Product status updated to 'rejected'

---

### Test 5: Reservation Notification

**Steps:**
1. Login as buyer
2. Add item to cart as **reservation** (with pickup date)
3. Checkout
4. **Check both buyer and seller devices**

**Expected Results:**
- ✅ Buyer receives reservation confirmation
- ✅ Seller receives new reservation notification
- ✅ Reservation document created
- ✅ Product 'reserved' count updated

---

## 🔍 Manual Firestore Checks

### Check Notifications Collection
```
Firebase Console → Firestore Database → notifications
- Verify documents exist
- Check userId matches
- Verify timestamp is recent
- Check 'read' field is false
```

### Check Seller Notifications
```
Firebase Console → Firestore Database → seller_notifications
- Verify sellerId matches
- Check orderId exists
- Verify needsApproval is set
- Check all required fields present
```

### Check Product Alerts
```
Firebase Console → Firestore Database → buyer_product_alerts
- Verify new entries when products approved
- Check productId, sellerName, category
```

---

## 📱 Device Testing

### Foreground Testing
1. App is **open and visible**
2. Trigger notification
3. **Should see**: Floating popup notification
4. **Should hear**: Notification sound
5. **Should feel**: Vibration

### Background Testing
1. App is **minimized** (home button pressed)
2. Trigger notification
3. **Should see**: System notification in tray
4. **Tap notification**: App opens

### Closed Testing
1. App is **completely closed** (swiped away)
2. Trigger notification
3. **Should see**: System notification
4. **Tap notification**: App launches

---

## 🐛 Troubleshooting

### Notifications Not Appearing

**Check 1: Permissions**
```dart
// In app, check notification permissions
Settings → Apps → Your App → Notifications → Enabled
```

**Check 2: FCM Token**
```dart
// Add debug code to check FCM token
final token = await PushNotificationService.getCurrentToken();
print('FCM Token: $token');
```

**Check 3: Firestore Rules**
```bash
# Redeploy rules
firebase deploy --only firestore:rules
```

**Check 4: Console Logs**
```
Look for:
- "Error sending notification: ..."
- "Error creating notification record: ..."
- "Notification sent successfully"
```

### Notifications in Firestore But No Push

**Issue**: Records created but no device notification

**Solution 1**: Check FCM setup
```dart
// Verify initialization in main.dart
await PushNotificationService.initialize();
```

**Solution 2**: Test direct notification
```dart
await PushNotificationService.sendTestNotification(
  title: 'Test',
  body: 'Testing push notifications',
);
```

### Push Notifications Work But No Firestore Records

**Issue**: Notifications appear but no database entries

**Solution**: Check Firestore write permissions
```javascript
// In firestore.rules
allow create: if request.auth != null;
```

---

## ✅ Verification Checklist

### Buyer Notifications
- [ ] Checkout confirmation received
- [ ] New product alerts received
- [ ] Order update notifications received
- [ ] Reservation confirmations received
- [ ] Notifications appear in notification tray
- [ ] Firestore records created

### Seller Notifications
- [ ] New purchase alerts received
- [ ] New reservation alerts received
- [ ] Product approval notifications received
- [ ] Product rejection notifications received
- [ ] Seller registration approval received
- [ ] New marketplace product alerts received
- [ ] Notifications stored in Firestore

### Database Verification
- [ ] `notifications` collection populated
- [ ] `seller_notifications` collection populated
- [ ] `buyer_product_alerts` collection populated
- [ ] `seller_market_updates` collection populated
- [ ] `product_updates` collection populated
- [ ] `orders` collection has complete data
- [ ] `reservations` collection working

---

## 🎬 Quick Test Commands

### Test Buyer Notification
```dart
await NotificationManager.sendCheckoutConfirmationToBuyer(
  buyerId: 'test_buyer_id',
  productName: 'Fresh Tomatoes',
  quantity: 5,
  unit: 'kg',
  totalAmount: 25.50,
  orderId: 'test_order_123',
);
```

### Test Seller Notification
```dart
await NotificationManager.sendCheckoutNotificationToSeller(
  sellerId: 'test_seller_id',
  productName: 'Fresh Tomatoes',
  quantity: 5,
  unit: 'kg',
  totalAmount: 25.50,
  buyerName: 'John Doe',
  orderId: 'test_order_123',
);
```

### Test Product Approval
```dart
await ProductService().approveProduct('test_product_id');
```

### Test Seller Registration
```dart
await UserService().approveSeller('test_user_id');
```

---

## 📊 Expected Notification Flow

```
BUYER CHECKOUT:
1. Buyer clicks "Checkout"
   ↓
2. Cart processes order
   ↓
3. Order document created
   ↓
4. Buyer notification sent (push + Firestore)
   ↓
5. Seller notification sent (push + Firestore)
   ↓
6. Both users see notifications

PRODUCT APPROVAL:
1. Admin approves product
   ↓
2. Product status → 'approved'
   ↓
3. Seller notification (approval)
   ↓
4. Buyer notifications (new product)
   ↓
5. Seller notifications (marketplace update)
   ↓
6. All collections updated

SELLER REGISTRATION:
1. Admin approves seller
   ↓
2. User status → 'approved'
   ↓
3. Seller document updated
   ↓
4. Registration notification sent
   ↓
5. User can now add products
```

---

## 🚀 Next Steps After Testing

1. ✅ Verify all notification types work
2. ✅ Confirm Firestore records are created
3. ✅ Test in different app states (foreground/background/closed)
4. ✅ Verify security rules prevent unauthorized access
5. ✅ Test notification read/unread status updates
6. ✅ Verify notification counts display correctly
7. ✅ Test on both Android and iOS (if applicable)

---

## 📞 Support

If you encounter issues:
1. Check Firebase Console → Firestore → Data
2. Check device logs for errors
3. Verify FCM configuration
4. Test with simple notification first
5. Check Firestore rules deployment

---

**Happy Testing! 🎉**
