# 📱 GCash Payment - Visual Flow Guide

## 🎯 User Journey: From Product to Payment

```
┌─────────────────────────────────────────────────────────────┐
│                    STEP 1: Browse & Select                  │
│                                                             │
│  User browses products → Clicks "Buy Now" or "Add to Cart" │
│                                                             │
│  [Product Image]                                            │
│  Organic Tomatoes                                           │
│  ₱50.00 per kg                                             │
│                                                             │
│  [Buy Now]  [Add to Cart]  ← User clicks                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  STEP 2: Choose Payment Method              │
│                                                             │
│  Select Payment Method:                                     │
│  ○ Cash on Delivery                                         │
│  ● GCash  ← User selects this                             │
│                                                             │
│  Delivery Method:                                           │
│  ● Cooperative Delivery                                     │
│  ○ Pickup at Coop                                          │
│                                                             │
│  [Place Order]  ← User clicks                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              STEP 3: PayMongo GCash Payment Screen          │
│                                                             │
│  ╔═══════════════════════════════════════════════════════╗ │
│  ║           🔵 GCash Payment                            ║ │
│  ╚═══════════════════════════════════════════════════════╝ │
│                                                             │
│  ┌───────────────────────────────────────────────┐         │
│  │           Amount to Pay                       │         │
│  │              ₱150.00                          │         │
│  │          Organic Tomatoes                     │         │
│  └───────────────────────────────────────────────┘         │
│                                                             │
│  ┌───────────────────────────────────────────────┐         │
│  │     Scan QR Code with GCash                   │         │
│  │                                               │         │
│  │         ███████████████████████               │         │
│  │         ███████████████████████               │         │
│  │         ███████████████████████  ← QR CODE   │         │
│  │         ███████████████████████               │         │
│  │         ███████████████████████               │         │
│  │                                               │         │
│  │  📱 Open GCash and scan this QR code          │         │
│  └───────────────────────────────────────────────┘         │
│                                                             │
│                      OR                                     │
│  ───────────────────────────────────────────────────       │
│                                                             │
│  ┌───────────────────────────────────────────────┐         │
│  │   Instructions:                               │         │
│  │   1️⃣ Scan QR code with GCash app              │         │
│  │   2️⃣ Or click "Open GCash" button below       │         │
│  │   3️⃣ Log in to your GCash account             │         │
│  │   4️⃣ Review and confirm payment               │         │
│  │   5️⃣ Return to this app after payment         │         │
│  └───────────────────────────────────────────────┘         │
│                                                             │
│  ┌───────────────────────────────────────────────┐         │
│  │    💳 Open GCash App                          │  ← Click│
│  └───────────────────────────────────────────────┘         │
│                                                             │
│  ⚠️ Make sure GCash app is installed              │         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                 STEP 4A: Scan QR Method                     │
│                                                             │
│  User opens GCash app separately                            │
│       ↓                                                     │
│  Taps "Scan QR" in GCash                                   │
│       ↓                                                     │
│  Points camera at QR code on screen                        │
│       ↓                                                     │
│  GCash shows payment details                               │
│       ↓                                                     │
│  User confirms payment in GCash                            │
└─────────────────────────────────────────────────────────────┘
                            OR
┌─────────────────────────────────────────────────────────────┐
│                 STEP 4B: Auto-Open Method                   │
│                                                             │
│  User clicks "Open GCash App" button                       │
│       ↓                                                     │
│  GCash app opens automatically                             │
│       ↓                                                     │
│  Shows payment details                                     │
│       ↓                                                     │
│  User logs in (if not logged in)                           │
│       ↓                                                     │
│  User confirms payment                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              STEP 5: Payment Processing Dialog              │
│                                                             │
│  ┌───────────────────────────────────────────────┐         │
│  │  ⏳ Waiting for Payment                       │         │
│  │                                               │         │
│  │  Complete your payment in the GCash app.      │         │
│  │                                               │         │
│  │  📋 Instructions:                             │         │
│  │   1. Log in to your GCash account             │         │
│  │   2. Review payment details                   │         │
│  │   3. Confirm payment                          │         │
│  │   4. Return to this app                       │         │
│  │                                               │         │
│  │  We'll automatically detect when payment      │         │
│  │  is complete.                                 │         │
│  │                                               │         │
│  │  [Cancel Payment]  [I've Paid]               │         │
│  └───────────────────────────────────────────────┘         │
│                                                             │
│  🔄 Checking payment status every 3 seconds...             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                 STEP 6: Payment Success! 🎉                │
│                                                             │
│  ┌───────────────────────────────────────────────┐         │
│  │  ✅ Payment Successful!                       │         │
│  │                                               │         │
│  │  Your GCash payment has been processed        │         │
│  │  successfully!                                │         │
│  │                                               │         │
│  │  ┌─────────────────────────────────────┐     │         │
│  │  │ Amount Paid                         │     │         │
│  │  │ ₱150.00                             │     │         │
│  │  │                                     │     │         │
│  │  │ Order ID: order_xyz789              │     │         │
│  │  │ Payment Method: GCash               │     │         │
│  │  └─────────────────────────────────────┘     │         │
│  │                                               │         │
│  │  Your order will be processed shortly.       │         │
│  │                                               │         │
│  │           [View Orders]                      │         │
│  └───────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   STEP 7: My Orders Screen                  │
│                                                             │
│  My Orders                                                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━          │
│                                                             │
│  ┌───────────────────────────────────────────────┐         │
│  │ Order #xyz789              [🟢 Pending]      │         │
│  │                                               │         │
│  │ [Product Image]  Organic Tomatoes            │         │
│  │                  Quantity: 3 kg               │         │
│  │                  ₱150.00                      │         │
│  │                                               │         │
│  │ 💳 Payment: GCash (Paid)  ✅                 │         │
│  │ 🚚 Delivery: Cooperative Delivery             │         │
│  │ 📅 Ordered: Oct 29, 2025 2:30 PM             │         │
│  └───────────────────────────────────────────────┘         │
│                                                             │
│  Order confirmed! Waiting for seller to process.           │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Behind the Scenes: Technical Flow

```
User Action          →  App Logic                 →  External Services
─────────────────────────────────────────────────────────────────────

1. Click "Place Order"
                     →  Create order in Firestore
                     →  Call PayMongo API
                                                   →  PayMongo creates
                                                      payment source
                                                      
2. Show payment screen
                     →  Display QR code
                     →  Show "Open GCash" button
                     
3. User pays         
   (via QR or app)                                →  GCash processes
                                                      payment
                                                      
4. App checks status
   (every 3 seconds) →  Poll PayMongo API
                                                   →  PayMongo returns
                                                      payment status
                                                      
5. Payment confirmed
                     →  Update Firestore
                     →  Save payment record
                     →  Show success dialog
                     →  Navigate to orders
```

---

## 💾 Database Records Created

### 1. Order Record (in `orders` collection)
```javascript
{
  orderId: "order_xyz789",
  buyerId: "user_123",
  sellerId: "farmer_456",
  productName: "Organic Tomatoes",
  quantity: 3,
  price: 50.00,
  totalAmount: 150.00,
  paymentMethod: "GCash",  ← Payment type
  paymentStatus: "paid",    ← Updated after payment
  status: "pending",
  deliveryMethod: "Cooperative Delivery",
  timestamp: "2025-10-29..."
}
```

### 2. Payment Record (in `paymongo_payments` collection)
```javascript
{
  sourceId: "src_abc123",        ← PayMongo ID
  orderId: "order_xyz789",       ← Links to order
  userId: "user_123",
  amount: 150.00,
  checkoutUrl: "https://...",    ← QR code data
  status: "chargeable",          ← Payment successful
  paymentMethod: "gcash",
  orderDetails: {
    productName: "Organic Tomatoes",
    quantity: 3,
    deliveryMethod: "Cooperative Delivery"
  },
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

---

## 🎨 UI Components Breakdown

### Payment Screen Components

```
┌─────────────────────────────────────┐
│  AppBar                             │  ← "GCash Payment" title
│  [←] GCash Payment         [...]    │     Back button
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  Logo Section (Blue background)     │  ← Icon + "GCash Payment"
│  🔵 GCash Payment                   │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  Amount Card (Gradient)             │  ← Shows payment amount
│  Amount to Pay                      │
│  ₱150.00                            │  ← Large, bold text
│  Organic Tomatoes                   │  ← Product name
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  QR Code Section (White card)       │  ← Main payment method
│  Scan QR Code with GCash            │
│  [QR CODE IMAGE]                    │  ← Large QR code (250x250)
│  📱 Open GCash and scan this QR     │
└─────────────────────────────────────┘

         OR Divider
     ─────────────────

┌─────────────────────────────────────┐
│  Instructions Card (Grey)            │  ← Step-by-step guide
│  ℹ️ How to Pay                      │
│  1️⃣ Scan QR code...                 │
│  2️⃣ Or click button...               │
│  3️⃣ Log in to GCash...              │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  [💳 Open GCash App]                │  ← Primary action button
└─────────────────────────────────────┘  ← Opens GCash app

┌─────────────────────────────────────┐
│  ⚠️ Make sure GCash is installed    │  ← Warning message
└─────────────────────────────────────┘
```

---

## 📊 Status Flow Chart

```
Payment Status Progression:

pending  →  chargeable  →  Order Confirmed
   │           │
   │           └─→ Payment Successful
   │
   ├─→ cancelled  →  User Cancelled
   │
   └─→ failed  →  Payment Failed
```

**What Each Status Means:**

- **`pending`** = Waiting for user to pay
- **`chargeable`** = Payment successful, can be captured
- **`cancelled`** = User cancelled the payment
- **`failed`** = Payment failed (insufficient funds, etc.)

---

## 🚀 Performance Optimizations

### Real-Time Status Checking
```
App checks payment status:
Every 3 seconds (configurable)
└─→ Polls PayMongo API
    └─→ Updates local state
        └─→ Shows success when "chargeable"
```

### QR Code Generation
```
QR code generated instantly:
checkoutUrl from PayMongo
└─→ Passed to QrImageView widget
    └─→ Rendered as scannable image
        └─→ High error correction (Level H)
```

---

## ✨ User Experience Features

### 1. **Dual Payment Options**
   - Scan QR code (traditional)
   - Auto-open GCash app (modern)
   - Users choose their preferred method

### 2. **Real-Time Feedback**
   - Loading states during API calls
   - Progress dialogs during payment
   - Instant success notifications

### 3. **Clear Instructions**
   - Numbered steps
   - Icons for visual clarity
   - Warning messages for requirements

### 4. **Error Prevention**
   - Validates GCash app installation
   - Checks internet connection
   - Handles API failures gracefully

### 5. **Professional Design**
   - Gradient cards for amounts
   - Clean, modern UI
   - Brand-consistent colors
   - Responsive layout

---

## 🎯 Success Metrics You Can Track

```sql
-- Payment success rate
SELECT 
  COUNT(CASE WHEN status = 'chargeable' THEN 1 END) * 100.0 / COUNT(*) as success_rate
FROM paymongo_payments
WHERE created_at > CURRENT_DATE - INTERVAL '7 days';

-- Average payment time
SELECT 
  AVG(updated_at - created_at) as avg_payment_time
FROM paymongo_payments
WHERE status = 'chargeable';

-- Payment method preferences
SELECT 
  payment_method,
  COUNT(*) as count
FROM orders
GROUP BY payment_method;
```

---

## 📱 Supported Devices & Platforms

### ✅ Tested & Working:
- Android 5.0+ (with GCash app)
- iOS 11.0+ (with GCash app)
- Physical devices (required for GCash app)

### ⚠️ Limitations:
- Emulator: QR code works, but can't open GCash app
- Desktop: Not applicable (GCash is mobile-only)
- Web: Can display QR, but can't auto-open app

---

## 🎉 That's It!

You now have a **complete, production-ready GCash payment system** that works exactly like major e-commerce platforms (Shopee, Lazada, etc.)!

**Key Takeaway:** Users can pay in **2 simple ways**:
1. 📱 **Scan QR code** with GCash app
2. 🚀 **Click button** to auto-open GCash app

Both methods work seamlessly with real-time status tracking! 💯
