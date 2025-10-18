# PayMongo GCash Payment Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    PAYMONGO GCASH PAYMENT FLOW                          │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────┐
│   USER       │
│   OPENS APP  │
└──────┬───────┘
       │
       ▼
┌──────────────────────────┐
│  1. Browse Products      │
│     - View product list  │
│     - Select a product   │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│  2. Click "Buy Now"      │
│     - Select quantity    │
│     - Choose delivery    │
│     - Select "GCash"     │ ◄── KEY STEP!
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────┐
│  3. Click "Place Order"  │
│     buy_now_screen.dart  │
└──────┬───────────────────┘
       │
       ├─────────────────────────┐
       │                         │
       ▼                         ▼
┌──────────────────┐      ┌─────────────────────┐
│  Create Order    │      │  If Cash on Delivery│
│  in Firestore    │      │  → Show Success     │
│  Status: Pending │      │     Dialog          │
└──────┬───────────┘      └─────────────────────┘
       │
       ▼
┌────────────────────────────────────────┐
│  4. Call PayMongo API                  │
│     paymongo_service.dart              │
│                                        │
│  POST /v1/sources                      │
│  {                                     │
│    amount: 29900,  // ₱299.00         │
│    type: "gcash",                      │
│    currency: "PHP",                    │
│    redirect: {                         │
│      success: "https://.../success",   │
│      failed: "https://.../failed"      │
│    }                                   │
│  }                                     │
└────────┬───────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  5. PayMongo Returns                    │
│     {                                   │
│       id: "src_abc123",                 │
│       checkout_url: "https://...",      │
│       status: "pending"                 │
│     }                                   │
└────────┬────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  6. Save to Firestore                   │
│     Collection: paymongo_payments       │
│     {                                   │
│       sourceId: "src_abc123",           │
│       orderId: "order_123",             │
│       userId: "user_xyz",               │
│       amount: 299.00,                   │
│       status: "pending",                │
│       checkoutUrl: "https://..."        │
│     }                                   │
└────────┬────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  7. Open WebView                        │
│     paymongo_gcash_screen.dart          │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │  ┌─────────────────────────────┐  │ │
│  │  │  Amount to Pay              │  │ │
│  │  │  ₱299.00                    │  │ │
│  │  └─────────────────────────────┘  │ │
│  │                                   │ │
│  │  [PayMongo GCash Page Loads]     │ │
│  │                                   │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │                             │ │ │
│  │  │    [GCash Logo]             │ │ │
│  │  │                             │ │ │
│  │  │    Pay with GCash           │ │ │
│  │  │                             │ │ │
│  │  │    [Continue Button]        │ │ │
│  │  │                             │ │ │
│  │  └─────────────────────────────┘ │ │
│  └───────────────────────────────────┘ │
└────────┬────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  8. User Clicks "Pay with GCash"        │
│                                         │
│  → PayMongo redirects to GCash login    │
└────────┬────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  9. GCash Login Page                    │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │   GCash                           │ │
│  │                                   │ │
│  │   Mobile Number:                  │ │
│  │   [ 09123456789 ]  (test)         │ │
│  │                                   │ │
│  │   [Send OTP]                      │ │
│  └───────────────────────────────────┘ │
└────────┬────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  10. Enter OTP                          │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │   Enter OTP:                      │ │
│  │   [ 123456 ]  (test)              │ │
│  │                                   │ │
│  │   [Verify]                        │ │
│  └───────────────────────────────────┘ │
└────────┬────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  11. Confirm Payment                    │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │   Merchant: Cooperative Store     │ │
│  │   Amount: ₱299.00                 │ │
│  │                                   │ │
│  │   Your GCash Balance: ₱5,000.00   │ │
│  │                                   │ │
│  │   [Confirm Payment]               │ │
│  └───────────────────────────────────┘ │
└────────┬────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  12. Payment Processing...              │
│      ⏳ Please wait                     │
└────────┬────────────────────────────────┘
         │
         ├──────────────────┬──────────────────┐
         │                  │                  │
         ▼                  ▼                  ▼
    ┌─────────┐      ┌──────────┐      ┌──────────┐
    │ SUCCESS │      │  FAILED  │      │ CANCELLED│
    └────┬────┘      └────┬─────┘      └────┬─────┘
         │                │                  │
         │                └──────────┬───────┘
         │                           │
         ▼                           ▼
┌─────────────────────┐    ┌─────────────────────┐
│ Redirect to:        │    │ Redirect to:        │
│ .../payment/success │    │ .../payment/failed  │
└────┬────────────────┘    └────┬────────────────┘
     │                          │
     ▼                          ▼
┌──────────────────────────────────────────────────┐
│  13. WebView Detects Redirect                    │
│      _handleUrlChange() method                   │
│                                                  │
│  if (url.contains('/payment/success'))           │
│    → _handlePaymentSuccess()                     │
│                                                  │
│  if (url.contains('/payment/failed'))            │
│    → _handlePaymentFailed()                      │
└────┬─────────────────────────────────────────────┘
     │
     ▼
┌──────────────────────────────────────────────────┐
│  14. Verify Payment Status                       │
│                                                  │
│  GET /v1/sources/{sourceId}                      │
│                                                  │
│  PayMongo returns:                               │
│  {                                               │
│    id: "src_abc123",                             │
│    status: "chargeable",  ◄── Payment successful!│
│    amount: 29900                                 │
│  }                                               │
└────┬─────────────────────────────────────────────┘
     │
     ▼
┌──────────────────────────────────────────────────┐
│  15. Update Firestore                            │
│                                                  │
│  paymongo_payments/src_abc123:                   │
│    status: "chargeable" → "completed"            │
│    updatedAt: now                                │
│                                                  │
│  orders/order_123:                               │
│    status: "pending" → "confirmed"               │
│    paymentStatus: "paid"                         │
└────┬─────────────────────────────────────────────┘
     │
     ▼
┌──────────────────────────────────────────────────┐
│  16. Show Success Dialog                         │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │  ✅ Payment Successful!                    │ │
│  │                                            │ │
│  │  Your GCash payment has been processed    │ │
│  │  successfully.                             │ │
│  │                                            │ │
│  │  ┌──────────────────────────────────────┐ │ │
│  │  │  Amount Paid                         │ │ │
│  │  │  ₱299.00                             │ │ │
│  │  │                                      │ │ │
│  │  │  Order ID: order_123                 │ │ │
│  │  │  Status: CHARGEABLE                  │ │ │
│  │  └──────────────────────────────────────┘ │ │
│  │                                            │ │
│  │  Your order will be processed shortly.    │ │
│  │                                            │ │
│  │           [View Orders]                    │ │
│  └────────────────────────────────────────────┘ │
└────┬─────────────────────────────────────────────┘
     │
     ▼
┌──────────────────────────────────────────────────┐
│  17. Navigate to Orders Screen                   │
│      checkout_screen.dart                        │
│                                                  │
│  User can see their order with:                  │
│  - Status: Confirmed                             │
│  - Payment: Paid via GCash                       │
│  - Amount: ₱299.00                               │
└──────────────────────────────────────────────────┘


═══════════════════════════════════════════════════
              BEHIND THE SCENES
═══════════════════════════════════════════════════

┌─────────────────────────────────────────────────┐
│  PayMongo API Flow                              │
└─────────────────────────────────────────────────┘

Your App                PayMongo API           GCash
    │                         │                   │
    │  POST /v1/sources       │                   │
    │──────────────────────>  │                   │
    │                         │                   │
    │  Returns checkout URL   │                   │
    │  <──────────────────────│                   │
    │                         │                   │
    │  User opens URL         │                   │
    │  ───────────────────────┼─────────────────> │
    │                         │                   │
    │                         │  User logs in     │
    │                         │  <─────────────── │
    │                         │                   │
    │                         │  Confirms payment │
    │                         │  <─────────────── │
    │                         │                   │
    │                         │  Payment success  │
    │                         │  ───────────────> │
    │                         │                   │
    │  Redirect to success    │                   │
    │  <──────────────────────┼─────────────────  │
    │                         │                   │
    │  GET /v1/sources/:id    │                   │
    │──────────────────────>  │                   │
    │                         │                   │
    │  Returns status         │                   │
    │  <──────────────────────│                   │
    │                         │                   │
    │  Update order status    │                   │
    │                         │                   │
    │  Show success to user   │                   │
    │                         │                   │


═══════════════════════════════════════════════════
              FIRESTORE COLLECTIONS
═══════════════════════════════════════════════════

paymongo_payments/
└── src_abc123                          ◄── Payment record
    ├── sourceId: "src_abc123"
    ├── orderId: "order_123"
    ├── userId: "user_xyz"
    ├── amount: 299.00
    ├── checkoutUrl: "https://..."
    ├── status: "chargeable"
    ├── paymentMethod: "gcash"
    ├── createdAt: Timestamp
    └── updatedAt: Timestamp

orders/
└── order_123                           ◄── Order record
    ├── buyerId: "user_xyz"
    ├── productId: "prod_456"
    ├── status: "confirmed"
    ├── paymentMethod: "GCash"
    ├── paymentStatus: "paid"
    ├── totalAmount: 299.00
    └── timestamp: Timestamp


═══════════════════════════════════════════════════
                  KEY BENEFITS
═══════════════════════════════════════════════════

✅ AUTOMATIC VERIFICATION
   - No manual checking needed
   - Instant payment confirmation
   - Real-time status updates

✅ SEAMLESS EXPERIENCE
   - Everything happens in-app
   - No app switching required
   - Professional checkout flow

✅ SECURE & COMPLIANT
   - PCI-DSS Level 1 certified
   - End-to-end encryption
   - Firestore security rules

✅ PRODUCTION-READY
   - Enterprise-grade gateway
   - Test mode for development
   - Live mode for production

✅ MULTIPLE PAYMENT METHODS
   - GCash (implemented)
   - Credit cards (supported)
   - PayMaya (supported)
   - GrabPay (supported)


═══════════════════════════════════════════════════
                PAYMENT STATUSES
═══════════════════════════════════════════════════

pending       → User hasn't completed payment yet
chargeable    → Payment successful, ready to process
cancelled     → User cancelled the payment
failed        → Payment failed (insufficient funds, etc.)
expired       → Payment source expired (30 min timeout)


═══════════════════════════════════════════════════
                    TEST VS LIVE
═══════════════════════════════════════════════════

TEST MODE (Development)
├── API Keys: pk_test_..., sk_test_...
├── Test GCash: 09123456789 / OTP: 123456
├── No real money charged
└── Unlimited testing

LIVE MODE (Production)
├── API Keys: pk_live_..., sk_live_...
├── Real GCash accounts
├── Real money charged
└── PayMongo transaction fees apply


═══════════════════════════════════════════════════
```

**That's it! Your app now has professional GCash payment processing! 🎉**
