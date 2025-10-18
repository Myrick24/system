# Place Order Button - Troubleshooting Guide

## Problem: Button Does Nothing When Clicked

### Diagnostic Steps:

#### 1. Check Debug Console
**What to look for:**
```
Expected: "DEBUG: Place Order button pressed"
```

**If you see this:**
✅ Button is working, issue is in the function logic  
→ Continue to Step 2

**If you DON'T see this:**
❌ Button press not being registered  
→ Possible causes:
- Button is disabled (_isLoading is true)
- Overlay blocking the button
- Navigation issue

**Fix:**
```dart
// Restart the app with hot restart (Press R in terminal)
// Or kill and relaunch the app
```

#### 2. Check Authentication
**What to look for:**
```
Expected: "DEBUG: Starting order placement..."
Not expected: Login prompt or no action
```

**If login prompt appears:**
- User is not authenticated
- Check if login session expired
- **Fix**: Login again

#### 3. Check Address Validation
**What to look for:**
```
If Cooperative Delivery selected:
Expected: "DEBUG: Delivery address: {region: ..., province: ...}"
Not expected: Error snackbar "Please select your delivery address"
```

**If error appears:**
- Address selector not filled completely
- **Fix**: 
  1. Select Region dropdown
  2. Select Province dropdown
  3. Select Municipality dropdown
  4. Select Barangay dropdown
  5. Optionally fill street/house number
  6. Verify preview shows complete address

#### 4. Check Cart Operations
**What to look for:**
```
Expected:
"DEBUG: Cart item created: [Product] x [Qty]"
"DEBUG: Cart cleared"
"DEBUG: Item added to cart: true"
```

**If you see "Item added to cart: false":**
- Not enough stock available
- **Check**: Product stock in Firestore
- **Fix**: 
  - Reduce quantity
  - Or update product stock in Firestore

#### 5. Check Order Processing
**What to look for:**
```
Expected:
"DEBUG: Processing cart..."
"DEBUG: Cart processed successfully: true"
"DEBUG: Order placed successfully!"
```

**If you see "Cart processed successfully: false":**
- Firestore write failed
- **Possible causes**:
  - Network connection lost
  - Firestore security rules blocking write
  - Invalid data format

**Fix:**
1. Check internet connection
2. Check Firestore rules:
```javascript
// Ensure orders collection allows writes
match /orders/{orderId} {
  allow create: if request.auth != null;
  allow read: if request.auth != null;
}
```
3. Check Firebase Console → Firestore → Recent writes

## Problem: Error Messages Appear

### "Please select your delivery address"
**Cause**: Address selector incomplete  
**Solution**: Fill all 4 dropdowns (Region → Province → Municipality → Barangay)

### "Sorry, not enough stock available"
**Cause**: Requested quantity > available stock  
**Solution**: 
1. Check product stock: Firestore → products → [productId] → quantity
2. Reduce order quantity
3. Or update product stock if you're testing

### "Unable to place order. Please check your connection"
**Cause**: processCart() returned false  
**Solution**:
1. Check internet connection
2. Check Firebase status (status.firebase.google.com)
3. Check Firestore rules
4. Review console for additional error messages

### "An error occurred: [error details]"
**Cause**: Exception thrown during processing  
**Solution**:
1. Read the full error message
2. Check console for stack trace
3. Common issues:
   - Null pointer: Missing data in product or user document
   - Type error: Data format mismatch
   - Permission denied: Firestore rules blocking access

## Problem: Success Dialog Doesn't Appear

### Diagnostic Steps:

**Check Console:**
```
Look for: "DEBUG: Order placed successfully!"
```

**If present but no dialog:**
- `mounted` check might be failing
- Context might be invalid

**Fix:**
```dart
// This is already handled in code
// If dialog doesn't show, check for navigation issues
// Ensure you're not navigating away before dialog appears
```

**If not present:**
- Order didn't process successfully
- Review previous debug messages to find where it failed

## Problem: App Crashes

### Get Stack Trace:
1. Look in Debug Console for "ERROR placing order:"
2. Copy full stack trace
3. Identify the line where crash occurred

### Common Crash Causes:

**1. Null Pointer Exception**
```
Error: Null check operator used on a null value
```
**Fix**: Check that product data has all required fields:
- name
- price
- sellerId
- unit
- imageUrl

**2. Type Mismatch**
```
Error: type 'int' is not a subtype of type 'double'
```
**Fix**: Already handled in code with:
```dart
price: widget.product['price'] is int
    ? (widget.product['price'] as int).toDouble()
    : widget.product['price'] as double,
```

**3. Provider Not Found**
```
Error: Could not find the correct Provider<CartService>
```
**Fix**: Ensure CartService provider is in main.dart:
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => CartService()),
    // ... other providers
  ],
  child: MyApp(),
)
```

## Problem: Order Appears in Firestore But No Dialog

**Cause**: Success dialog code not executing  
**Check Console**: Should see "DEBUG: Order placed successfully!"

**If console shows success but no dialog:**
1. Check `mounted` is true
2. Ensure no navigation happening simultaneously
3. Try hot restart

## Testing Checklist

Use this to verify everything is working:

```
□ App launches without errors
□ Can navigate to product details
□ "Buy Now" button works
□ Checkout screen loads with correct title
□ Can adjust quantity
□ Delivery options appear
□ Address selector appears when "Cooperative Delivery" selected
□ All dropdowns load data
□ Can select complete address
□ Address preview shows correctly
□ Payment options appear
□ Order summary shows correct totals
□ "Place Order" button is green with icon
□ Console shows "DEBUG: Place Order button pressed" when clicked
□ Button shows loading state (grey + spinner)
□ Console shows all debug messages in sequence
□ Success dialog appears within 5 seconds
□ Dialog shows correct order details
□ Can click "Continue Shopping"
□ Can click "View Orders" and see new order
□ Order appears in Firestore with correct data
```

## Still Having Issues?

### Collect This Information:

1. **Console Output**: Full debug log from button press to completion
2. **Error Messages**: Any snackbars or dialogs shown
3. **Firestore State**: Screenshot of orders collection
4. **Product Data**: Copy the product document from Firestore
5. **User State**: Check if user is authenticated

### Reset and Retry:

```powershell
# 1. Hot restart
# Press 'R' in terminal

# 2. Full rebuild
flutter clean
flutter pub get
flutter run

# 3. Check Firebase connection
# Firebase Console → Database → should see data

# 4. Verify user authentication
# Firebase Console → Authentication → Recent signins
```

### Manual Order Creation Test:

Test if the issue is with the UI or backend by creating an order manually:

```dart
// In Firebase Console → Firestore → orders collection
// Add document manually with:
{
  "userId": "[your-user-id]",
  "items": [{
    "productId": "[product-id]",
    "productName": "Test Product",
    "price": 100,
    "quantity": 1,
    "unit": "piece",
    "sellerId": "[seller-id]"
  }],
  "totalAmount": 100,
  "paymentMethod": "Cash on Delivery",
  "deliveryMethod": "Pickup at Coop",
  "status": "pending",
  "createdAt": [current-timestamp],
  "orderNumber": "ORD-001"
}
```

If manual creation works:
- ✅ Backend is fine
- ❌ Issue is in app code

If manual creation fails:
- ❌ Firestore rules or permissions issue

---

## Quick Reference: Debug Log Sequence

**Perfect execution should show:**
```
1. DEBUG: Place Order button pressed
2. DEBUG: Starting order placement...
3. DEBUG: Selected delivery option: Cooperative Delivery
4. DEBUG: Selected payment option: Cash on Delivery
5. DEBUG: Delivery address: {region: NCR, province: ...}
6. DEBUG: Cart item created: [Product] x [Qty]
7. DEBUG: Cart cleared
8. DEBUG: Item added to cart: true
9. DEBUG: Processing cart...
10. DEBUG: Cart processed successfully: true
11. DEBUG: Order placed successfully!
12. DEBUG: Order placement process completed
```

**Any deviation from this sequence = problem at that step**

---

**Need Help?** Check:
- PLACE_ORDER_DEBUG_GUIDE.md (detailed implementation guide)
- QUICK_TEST_GUIDE.md (step-by-step testing)
- Firebase Console logs
- Flutter Doctor output: `flutter doctor -v`
