# 🏢 Cooperative Dashboard - Complete Guide

## Overview

The **Cooperative Dashboard** is a comprehensive management system that allows cooperatives to handle all delivery and payment operations for their e-commerce platform. This dashboard provides full control over order fulfillment, delivery management, and payment collection.

---

## 🎯 Purpose

The cooperative model centralizes all delivery and payment operations through a single cooperative entity, providing:

- **Unified Order Management** - View and manage all orders in one place
- **Delivery Coordination** - Handle both "Cooperative Delivery" and "Pickup at Coop" orders
- **Payment Tracking** - Monitor Cash on Delivery (COD) and GCash payments
- **Status Updates** - Update order status throughout the fulfillment process
- **Financial Overview** - Track revenue and pending payments

---

## 📱 Features

### 1. **Dashboard Overview Tab**
   - **Statistics Cards**
     - Total Orders
     - Pending Orders
     - Ready for Pickup
     - In Delivery
     - Completed Orders
     - Unpaid COD Orders
   
   - **Financial Summary**
     - Total Revenue (completed orders)
     - Pending COD Payments
   
   - **Quick Actions**
     - Navigate to Deliveries
     - Navigate to Pickups
     - Navigate to Payments

### 2. **Deliveries Tab**
   - View all "Cooperative Delivery" orders
   - Filter by order status (pending, processing, delivered, etc.)
   - Quick status update buttons
   - Customer information and contact details
   - Delivery address display

### 3. **Pickups Tab**
   - View all "Pickup at Coop" orders
   - Filter by order status
   - Mark orders as "Ready for Pickup"
   - Customer contact information
   - Quick status updates

### 4. **Payments Tab**
   - View all payment transactions
   - Filter by payment method (Cash on Delivery, GCash)
   - Payment summary cards
   - Mark COD payments as collected
   - Track payment status

---

## 🚀 Getting Started

### Access the Dashboard

#### Option 1: Through Admin Dashboard
1. Login as **Admin**
2. Open the **Admin Dashboard**
3. Click the **drawer menu** (☰)
4. Select **"Cooperative Dashboard"**

#### Option 2: Direct Access (Future Enhancement)
- Login with a user account that has role: `cooperative`
- The dashboard will be accessible from the main navigation

---

## 👥 User Roles

### Who Can Access?

1. **Admin** - Full access through admin dashboard
2. **Cooperative Staff** (future) - Direct access with role: `cooperative`

### Permissions

Cooperative users can:
- ✅ View all orders
- ✅ Update order status
- ✅ Mark orders as ready, processing, delivered
- ✅ Collect COD payments
- ✅ View customer information
- ✅ Access financial summaries
- ❌ Cannot delete orders
- ❌ Cannot modify order amounts
- ❌ Cannot change customer information

---

## 📦 Order Management

### Order Statuses

| Status | Description | Available Actions |
|--------|-------------|-------------------|
| **pending** | New order, awaiting confirmation | Start Processing |
| **confirmed** | Order confirmed by seller | Start Processing |
| **processing** | Order is being prepared | Mark Ready (Pickup) / Mark Delivered (Delivery) |
| **ready** | Order ready for pickup | Mark Delivered |
| **shipped** | Order shipped/in delivery | Mark Delivered |
| **delivered** | Order delivered to customer | None (Final state) |
| **completed** | Order completed and paid | None (Final state) |
| **cancelled** | Order cancelled | None (Final state) |

### Workflow Examples

#### For "Cooperative Delivery" Orders:
```
1. pending → Start Processing → processing
2. processing → (Out for Delivery) → (Manual: mark as delivered)
3. delivered → (Collect COD if applicable) → completed
```

#### For "Pickup at Coop" Orders:
```
1. pending → Start Processing → processing
2. processing → Mark Ready → ready
3. ready → (Customer picks up) → delivered
4. delivered → (Collect COD if applicable) → completed
```

---

## 💰 Payment Management

### Payment Methods

#### 1. **GCash (Digital Payment)**
- ✅ **Pre-paid** - Payment collected before delivery
- ✅ **Automatic** - No manual collection needed
- ✅ **Verified** - Through PayMongo integration
- Status: Always shows as "Paid"

#### 2. **Cash on Delivery (COD)**
- 💰 **Collect on Delivery** - Cooperative collects payment
- 📝 **Manual Tracking** - Mark as collected in dashboard
- ⏳ **Pending** - Shows as unpaid until marked
- Status: "Unpaid" → "Paid" (after collection)

### How to Collect COD Payments

1. Navigate to **Payments Tab**
2. Filter by "Cash on Delivery"
3. Find orders with status "Unpaid (COD)"
4. Click **"Mark as Paid (Collected COD)"**
5. Confirm that payment was collected
6. Order status updates to "Completed"

### Payment Summary

The dashboard shows:
- **Total Revenue**: Sum of all completed orders
- **Pending COD**: Total amount of uncollected COD payments
- **COD Orders**: Count of Cash on Delivery orders
- **GCash Payments**: Total GCash revenue

---

## 📊 Using the Dashboard

### Overview Tab

**Purpose**: Get a quick snapshot of all operations

**How to Use**:
1. View statistics cards for current order counts
2. Check financial summary
3. Use quick action buttons to navigate to specific sections

### Deliveries Tab

**Purpose**: Manage "Cooperative Delivery" orders

**How to Use**:
1. **View Orders**
   - All delivery orders are listed
   - Shows customer name, address, contact
   - Displays order status and payment method

2. **Filter Orders**
   - Use dropdown to filter by status
   - Options: All, pending, confirmed, processing, delivered, etc.

3. **Update Status**
   - Click "Start Processing" for new orders
   - Click "Complete" when delivered
   - Tap order card for full details

4. **View Order Details**
   - Tap any order card
   - See complete order information
   - Update status from detail screen
   - View customer contact and address

### Pickups Tab

**Purpose**: Manage "Pickup at Coop" orders

**How to Use**:
1. **View Orders**
   - All pickup orders are listed
   - Shows customer name and contact

2. **Mark Ready**
   - When order is prepared, click "Mark Ready"
   - Order moves to "ready" status
   - Customer can be notified to pick up

3. **Complete Pickup**
   - When customer picks up, click "Complete"
   - Order moves to "delivered" status

### Payments Tab

**Purpose**: Track and manage all payments

**How to Use**:
1. **View All Payments**
   - See all orders with payment information
   - Payment method and status displayed

2. **Filter by Payment Method**
   - Select "All", "Cash on Delivery", or "GCash"
   - Quickly find specific payment types

3. **Collect COD**
   - For unpaid COD orders
   - Click "Mark as Paid"
   - Confirm collection
   - Payment status updates

4. **View Summary**
   - Check total revenue
   - Monitor pending COD payments
   - Track payment distribution

---

## 🔧 Order Detail Screen

### Accessing Order Details
- Tap any order card from Deliveries or Pickups tab
- Opens detailed order information screen

### Information Displayed

#### 1. **Order Status**
- Large status indicator
- Color-coded by status
- Icon representation

#### 2. **Order Information**
- Order ID
- Product name
- Quantity and unit
- Price per unit
- Total amount
- Order date

#### 3. **Customer Information**
- Customer name
- Contact number
- Email address
- Delivery address (for delivery orders)

#### 4. **Delivery & Payment**
- Delivery method
- Payment method
- Payment status (Paid/Unpaid)

#### 5. **Seller Information**
- Seller name
- Seller ID

#### 6. **Order Actions**
Available actions depend on current status:
- **Start Processing** (for pending/confirmed)
- **Mark Ready** (for processing pickups)
- **Mark Delivered** (for ready orders)
- **Cancel Order** (for non-completed orders)

---

## 🎨 UI Features

### Color Coding

Orders are color-coded by status:
- 🟠 **Orange** - Pending
- 🔵 **Blue** - Confirmed
- 🟣 **Purple** - Processing
- 🟢 **Green** - Ready
- 🔷 **Teal** - Delivered
- 🟢 **Dark Green** - Completed
- 🔴 **Red** - Cancelled

### Icons

Each status has a unique icon:
- ⏳ Pending
- ✓ Confirmed
- 🔄 Processing
- ✓✓ Ready
- 🚚 Shipped
- ✓✓✓ Delivered
- ✅ Completed
- ✖ Cancelled

### Cards and Lists

- **Stats Cards**: Quick metrics at a glance
- **Order Cards**: Expandable cards with key information
- **Summary Cards**: Financial overview
- **Filter Controls**: Easy filtering options

---

## 🔐 Security & Permissions

### Firestore Rules

The cooperative dashboard has specific security rules:

```javascript
// Cooperative can view all orders
allow read: if isCoop() || isAdmin();

// Cooperative can update order status
allow update: if isCoop() && 
  request.resource.data.diff(resource.data).affectedKeys()
    .hasOnly(['status', 'updatedAt', 'deliveryDate', 'notes', 
              'paymentCollected', 'paymentCollectedAt']);
```

### Allowed Updates

Cooperative staff can only update:
- ✅ `status` - Order status
- ✅ `updatedAt` - Timestamp
- ✅ `deliveryDate` - Delivery date
- ✅ `notes` - Order notes
- ✅ `paymentCollected` - COD payment flag
- ✅ `paymentCollectedAt` - Collection timestamp

### Restricted Actions

Cooperative staff **cannot**:
- ❌ Change order amounts
- ❌ Modify product details
- ❌ Change customer information
- ❌ Delete orders
- ❌ Access other users' data beyond orders

---

## 📱 Mobile Responsive

The dashboard is fully responsive:
- ✅ Works on tablets
- ✅ Works on phones
- ✅ Adaptive layout
- ✅ Touch-friendly buttons
- ✅ Swipe-able tabs

---

## 🔄 Real-time Updates

### Live Data
- Uses Firestore **StreamBuilder**
- Updates automatically when orders change
- No manual refresh needed (optional refresh button available)

### Refresh Options
1. **Pull-to-Refresh** on Overview tab
2. **Refresh Button** (floating action button)
3. **Auto-refresh** when returning to screen

---

## 📋 Common Tasks

### Task 1: Process a New Order

1. Go to **Deliveries** or **Pickups** tab
2. Find order with status "pending"
3. Click **"Start Processing"**
4. Order moves to "processing"
5. Prepare the order for delivery/pickup

### Task 2: Prepare Order for Pickup

1. Go to **Pickups** tab
2. Find processing order
3. When ready, click **"Mark Ready"**
4. Notify customer (manual or via system)
5. Wait for customer pickup

### Task 3: Complete a Delivery

1. Go to **Deliveries** tab
2. Find order being delivered
3. After successful delivery, click **"Complete"**
4. Order status becomes "delivered"
5. If COD, collect payment separately

### Task 4: Collect COD Payment

1. Go to **Payments** tab
2. Filter by "Cash on Delivery"
3. Find unpaid order
4. Collect cash from customer
5. Click **"Mark as Paid"**
6. Confirm collection
7. Order status becomes "completed"

### Task 5: Cancel an Order

1. Open order details
2. Click **"Cancel Order"**
3. Confirm cancellation
4. Order status becomes "cancelled"

### Task 6: Check Daily Revenue

1. Go to **Overview** tab
2. View **"Total Revenue"** card
3. Check **"Pending COD Payments"**
4. Navigate to **Payments** tab for breakdown

---

## 🛠 Technical Details

### Files Created

```
lib/screens/cooperative/
├── coop_dashboard.dart           # Main dashboard with tabs
├── coop_order_details.dart       # Detailed order view
└── coop_payment_management.dart  # Payment tracking
```

### Dependencies

No additional packages required! Uses existing:
- `cloud_firestore` - Database
- `firebase_auth` - Authentication
- `intl` - Date formatting

### Database Collections Used

1. **orders** - All order data
   - Query by `deliveryMethod`
   - Update `status`, `paymentCollected`
   
2. **users** - User role verification
   - Check for `role: 'cooperative'` or `role: 'admin'`

### Queries

**Get Delivery Orders**:
```dart
_firestore
  .collection('orders')
  .where('deliveryMethod', isEqualTo: 'Cooperative Delivery')
  .snapshots()
```

**Get Pickup Orders**:
```dart
_firestore
  .collection('orders')
  .where('deliveryMethod', isEqualTo: 'Pickup at Coop')
  .snapshots()
```

**Get All Orders**:
```dart
_firestore
  .collection('orders')
  .snapshots()
```

---

## 🎓 Best Practices

### For Cooperative Staff

1. **Check Dashboard Regularly**
   - Review pending orders multiple times daily
   - Update status promptly

2. **Update Status Accurately**
   - Don't mark as delivered until actually delivered
   - Don't mark ready until order is prepared

3. **Collect COD Promptly**
   - Collect cash on delivery/pickup
   - Mark as paid immediately in system

4. **Customer Communication**
   - Notify customers when orders are ready
   - Provide contact information for queries

5. **Daily Reconciliation**
   - Check total COD collected vs system records
   - Verify GCash payments match records

### For Administrators

1. **Monitor Dashboard Usage**
   - Track cooperative staff performance
   - Review order fulfillment times

2. **Regular Audits**
   - Check payment collections
   - Verify status updates

3. **User Management**
   - Assign `role: 'cooperative'` to staff
   - Remove access when staff leaves

---

## 🆘 Troubleshooting

### Issue: Can't See Orders

**Possible Causes**:
- Not logged in as admin/cooperative
- No orders exist yet
- Firestore rules not deployed

**Solution**:
1. Verify user role in Firestore
2. Deploy updated Firestore rules
3. Check if orders exist in database

### Issue: Can't Update Order Status

**Possible Causes**:
- Insufficient permissions
- Invalid status transition
- Network issue

**Solution**:
1. Check user role (must be admin or cooperative)
2. Verify Firestore rules deployed
3. Check internet connection
4. Try refreshing the page

### Issue: Payment Not Showing

**Possible Causes**:
- Order not completed
- Payment method filter applied
- Data sync delay

**Solution**:
1. Check order status (must be delivered/completed for revenue)
2. Clear payment method filter (select "All")
3. Pull to refresh or click refresh button

### Issue: Statistics Not Updating

**Possible Causes**:
- Cached data
- Need manual refresh

**Solution**:
1. Click refresh button (floating action button)
2. Pull to refresh on Overview tab
3. Navigate away and back to dashboard

---

## 📊 Reports & Analytics

### Available Metrics

**Order Metrics**:
- Total orders
- Orders by status
- Orders by delivery method
- Orders by payment method

**Financial Metrics**:
- Total revenue (completed orders)
- Pending COD payments
- GCash payment total
- Average order value (calculated manually)

**Performance Metrics**:
- Orders pending (needs attention)
- Orders ready for pickup (waiting for customer)
- Orders in delivery (out for delivery)

### Export Data (Future Enhancement)

Currently, data can be:
- Viewed in dashboard
- Exported via Firestore console
- Analyzed using Firebase Analytics

Future enhancements:
- CSV export
- PDF reports
- Email summaries
- Chart visualizations

---

## 🔮 Future Enhancements

### Planned Features

1. **Delivery Assignments**
   - Assign specific delivery staff to orders
   - Track delivery personnel performance

2. **Route Optimization**
   - Plan delivery routes
   - Map view of delivery addresses

3. **Customer Notifications**
   - Auto-notify when order ready
   - Send delivery updates via SMS/push

4. **Inventory Management**
   - Track product stock at cooperative
   - Alert when items running low

5. **Advanced Analytics**
   - Charts and graphs
   - Sales trends
   - Performance reports

6. **Multi-Cooperative Support**
   - Support multiple cooperative branches
   - Branch-specific dashboards

7. **Barcode Scanning**
   - Scan products for pickup verification
   - Quick order lookup

---

## 📞 Support

### For Issues or Questions

1. **Check This Guide** - Most questions answered here
2. **Contact Admin** - Reach out to system administrator
3. **Check Firestore Console** - Verify data exists
4. **Review Logs** - Check for error messages

### Training

Recommended training for new cooperative staff:
1. Read this complete guide
2. Practice with test orders
3. Shadow experienced staff
4. Review common tasks section

---

## ✅ Quick Reference

### Status Update Flow

```
Delivery Orders:
pending → processing → delivered → completed

Pickup Orders:
pending → processing → ready → delivered → completed
```

### Payment Collection Flow

```
GCash:
Automatic - Always paid

COD:
Order delivered → Collect cash → Mark as paid → Completed
```

### Dashboard Navigation

```
Overview → Quick stats and actions
Deliveries → Manage delivery orders
Pickups → Manage pickup orders
Payments → Track and collect payments
```

---

## 🎉 Summary

The Cooperative Dashboard provides:
- ✅ **Complete Order Management** - All orders in one place
- ✅ **Easy Status Updates** - Quick action buttons
- ✅ **Payment Tracking** - Monitor all transactions
- ✅ **Real-time Data** - Live updates from Firestore
- ✅ **Mobile Friendly** - Works on any device
- ✅ **Secure** - Role-based access control
- ✅ **User Friendly** - Intuitive interface

### Getting Started Checklist

- [ ] Login as admin or cooperative user
- [ ] Access dashboard from admin menu
- [ ] Review Overview tab statistics
- [ ] Check pending orders in Deliveries/Pickups
- [ ] Update order statuses as needed
- [ ] Monitor and collect COD payments
- [ ] Review daily revenue

---

**Congratulations! You now have a complete cooperative delivery and payment management system!** 🎊

For questions or support, contact your system administrator.

---

**Last Updated**: October 2025  
**Version**: 1.0  
**Dashboard Created By**: GitHub Copilot  
**Integration**: Firebase Firestore + Flutter
