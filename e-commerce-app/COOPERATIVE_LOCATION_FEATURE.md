# Cooperative Pickup Location Feature

## Overview
Added the ability for admins to set a physical pickup location for cooperatives, which buyers can see when they select "Pickup at Coop" delivery option.

## Changes Made

### 1. Admin Web Dashboard (`ecommerce-web-admin`)

**File: `src/components/CooperativeManagement.tsx`**

✅ Added `location` field to cooperative account creation form
✅ Added `Pickup Location` input field (required, minimum 5 characters, TextArea)
✅ Added `Pickup Location` column in the cooperatives table
✅ Location is stored in Firestore `users` collection when creating cooperative accounts

**Form Fields:**
- Cooperative Name
- Email Address
- Password
- Contact Phone Number (Optional)
- **Pickup Location** ⭐ NEW
  - Required field
  - Multi-line text area
  - Example: "123 Main St, Barangay Centro, City, Province"

### 2. Flutter Mobile App (`e-commerce-app`)

**File: `lib/services/cart_service.dart`**

✅ Modified `processCart()` method to fetch cooperative location from Firestore
✅ When delivery method is "Pickup at Coop", queries the `users` collection for a cooperative user
✅ Retrieves the `location` field from cooperative user data
✅ Adds `pickupLocation` to order data in Firestore

**File: `lib/screens/checkout_screen.dart`**

✅ Added display for pickup location in order list
✅ Shows location with store icon (🏪) in green color
✅ Format: "Pickup at: [Location Address]"

**File: `lib/screens/order_status_screen.dart`**

✅ Added pickup location display in order details
✅ Shows for both buyers and sellers
✅ Displays below delivery method information

## How It Works

### Admin Flow:
1. Admin logs into web dashboard
2. Goes to "Cooperative Management" section
3. Fills out form to create new cooperative account
4. **Enters pickup location** in the "Pickup Location" field
5. Submits form
6. Location is saved to Firestore `users/{userId}` with field `location`

### Buyer Flow:
1. Buyer adds products to cart
2. Goes to checkout
3. Selects "Pickup at Coop" as delivery method
4. Places order
5. **System automatically fetches cooperative location** from Firestore
6. Location is saved to the order document
7. Buyer can see pickup location in:
   - Order confirmation
   - Order history (Checkout Screen)
   - Order details (Order Status Screen)

### Cooperative/Seller Flow:
1. Cooperative staff or seller views order
2. Can see pickup location in order details
3. Knows where buyer should pick up the product

## Database Structure

### Firestore Collections

**`users` collection** (Cooperative users):
```json
{
  "name": "Coop Kapatiran",
  "email": "coopkapatiran@example.com",
  "phone": "+639123456789",
  "location": "123 Main St, Barangay Centro, Manila City",  // ⭐ NEW
  "role": "cooperative",
  "status": "active",
  "createdAt": "2025-10-29T...",
  "updatedAt": "2025-10-29T..."
}
```

**`orders` collection** (When "Pickup at Coop" is selected):
```json
{
  "id": "order_123456",
  "buyerId": "user_abc",
  "deliveryMethod": "Pickup at Coop",
  "pickupLocation": "123 Main St, Barangay Centro, Manila City",  // ⭐ NEW
  "productName": "Fresh Vegetables",
  "quantity": 5,
  "status": "pending",
  // ... other fields
}
```

## UI Display

### Checkout Screen (Order List)
```
🏪 Pickup at: 123 Main St, Barangay Centro, Manila City
```
- Green store icon
- Green text color
- Shown below product info

### Order Status Screen
```
Delivery Method: Pickup at Coop
Pickup Location: 123 Main St, Barangay Centro, Manila City
```
- Displayed in order details section
- Visible to both buyer and seller

## Testing Checklist

### Admin Dashboard
- [ ] Create new cooperative account
- [ ] Fill in pickup location field
- [ ] Verify location appears in cooperatives table
- [ ] Check Firestore to confirm `location` field is saved

### Mobile App
- [ ] Add product to cart
- [ ] Select "Pickup at Coop" delivery method
- [ ] Complete checkout
- [ ] Verify pickup location appears in order confirmation
- [ ] Check order in "View Orders"
- [ ] Open order details to see pickup location
- [ ] Verify location is displayed correctly

### Edge Cases
- [ ] Test with cooperative that has no location set (should handle gracefully)
- [ ] Test with empty/null location
- [ ] Test with very long location text
- [ ] Test when no cooperative users exist

## Benefits

✅ **Clarity for Buyers**: No confusion about where to pick up orders
✅ **Reduced Support**: Fewer questions about pickup locations
✅ **Better Experience**: Complete information at checkout
✅ **Flexible**: Admin can update location as needed
✅ **Scalable**: Works with multiple cooperatives (shows first one found)

## Future Enhancements

💡 Possible improvements:
- Allow multiple cooperatives with different locations
- Let buyer choose which cooperative location to pick up from
- Add map integration to show location visually
- Add operating hours for pickup
- Add special pickup instructions

## Files Modified

### Web Admin Dashboard:
- `ecommerce-web-admin/src/components/CooperativeManagement.tsx`

### Mobile App:
- `e-commerce-app/lib/services/cart_service.dart`
- `e-commerce-app/lib/screens/checkout_screen.dart`
- `e-commerce-app/lib/screens/order_status_screen.dart`

## Notes

- System queries for the first cooperative user found (limit 1)
- If multiple cooperatives exist, uses the first one's location
- Location field is required when creating new cooperative accounts
- Existing cooperatives without location will need to be updated manually in Firestore
- Location is only fetched and stored when "Pickup at Coop" is selected
