# Quick Reference - Product Approval Notifications

## 🚀 What Was Implemented

### When Admin Approves a Product:
1. ✅ **Seller receives notification**: "🎉 Product Approved! Great news! Your product '[name]' has been approved and is now live."
2. ✅ **All buyers receive notification**: "🆕 New Product Available! Check out our new product: '[name]' in [category]."

### When Admin Rejects a Product:
1. ✅ **Seller receives notification**: "⚠️ Product Needs Attention. Your product '[name]' needs some changes. Reason: [admin's reason]"
2. ✅ Buyers do NOT receive notification (product not available)

---

## 📝 How to Use (Admin Dashboard)

### Approving a Product:
```
1. Go to Product Management
2. Click "Approve" button on any pending product
3. System automatically:
   - Updates product status to "approved"
   - Sends notification to the seller
   - Sends notification to ALL buyers
4. Success message: "Product approved! Notifications sent to seller and buyers."
```

### Rejecting a Product:
```
1. Go to Product Management
2. Click "Reject" button on any pending product
3. Modal appears with reason input field
4. Enter rejection reason (optional):
   Example: "Image quality is poor"
   Example: "Description incomplete"
   Example: "Pricing needs review"
5. Click OK
6. System automatically:
   - Updates product status to "rejected"
   - Sends notification to seller with the reason
7. Success message: "Product rejected"
```

---

## 📱 Mobile App (Seller & Buyer View)

### Sellers See:
- Notification icon in seller dashboard
- Badge showing unread count
- List of all product-related notifications
- Can tap to view details

### Buyers See:
- Notification icon in main app
- Badge showing unread count
- New product alerts for shopping
- Can tap to view product details

---

## 🎯 Key Features

| Feature | Status | Details |
|---------|--------|---------|
| Seller Approval Notifications | ✅ | Instant when admin approves |
| Seller Rejection Notifications | ✅ | With optional reason from admin |
| Buyer New Product Alerts | ✅ | Sent to all buyers when product approved |
| Rejection Reason Input | ✅ | Admin can provide helpful feedback |
| Multiple Buyers Support | ✅ | Notifies all buyers in parallel |
| Error Handling | ✅ | Notification failures don't block approval |

---

## 🔍 Notification Details

### Seller Approval Notification:
```json
{
  "userId": "seller123",
  "title": "🎉 Product Approved!",
  "message": "Great news! Your product 'Fresh Tomatoes' has been approved and is now live for buyers to purchase.",
  "type": "product_approval",
  "read": false,
  "data": {
    "productId": "prod456",
    "productName": "Fresh Tomatoes"
  }
}
```

### Seller Rejection Notification:
```json
{
  "userId": "seller123",
  "title": "⚠️ Product Needs Attention",
  "message": "Your product 'Fresh Tomatoes' needs some changes before approval. Reason: Image quality is poor",
  "type": "product_rejection",
  "read": false,
  "data": {
    "productId": "prod456",
    "productName": "Fresh Tomatoes",
    "reason": "Image quality is poor"
  }
}
```

### Buyer New Product Notification:
```json
{
  "userId": "buyer789",
  "title": "🆕 New Product Available!",
  "message": "Check out our new product: 'Fresh Tomatoes' in Vegetables category. Shop now!",
  "type": "product_approval",
  "read": false,
  "data": {
    "productId": "prod456",
    "productName": "Fresh Tomatoes",
    "category": "Vegetables",
    "type": "new_product_listing"
  }
}
```

---

## ✅ Testing

### Test Approval:
1. Login to admin dashboard
2. Go to Product Management → Pending tab
3. Click Approve on any product
4. Check seller's mobile app for "Product Approved" notification
5. Check buyer's mobile app for "New Product Available" notification

### Test Rejection:
1. Login to admin dashboard
2. Go to Product Management → Pending tab
3. Click Reject on any product
4. Enter reason: "Please improve product images"
5. Check seller's mobile app for rejection notification with reason

---

## 📊 Expected Behavior

| Action | Seller Notification | Buyer Notification |
|--------|-------------------|-------------------|
| Product Approved | ✅ "Product Approved!" | ✅ "New Product Available!" |
| Product Rejected | ✅ "Product Needs Attention" | ❌ None |
| Product Deleted | ❌ None (future) | ❌ None |

---

## 🐛 Troubleshooting

**Notifications not appearing?**
- Check Firestore `notifications` collection
- Verify userId matches in `users` collection
- Check browser console for errors
- Ensure mobile app has notification permissions

**Only seller notified, not buyers?**
- Check if buyers have role='buyer' in Firestore
- Review console logs for buyer query results
- Verify no errors in browser developer tools

**Rejection reason not showing?**
- Ensure you entered text in the reason field
- Check notification data in Firestore
- Verify modal is properly capturing input

---

## 📄 Related Files

- `src/services/productService.ts` - Backend logic
- `src/components/ProductManagement.tsx` - UI component
- `src/services/notificationService.ts` - Notification helper
- Mobile app notification screens (already implemented)

---

**Documentation:** See `PRODUCT_APPROVAL_NOTIFICATIONS.md` for detailed implementation guide.
