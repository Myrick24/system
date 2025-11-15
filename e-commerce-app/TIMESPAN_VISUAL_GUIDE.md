# Timespan Feature - Visual Guide & Examples

## 🎨 UI Layout

### Add Product Screen Flow
```
┌────────────────────────────────────┐
│   ADD NEW PRODUCT                  │
├────────────────────────────────────┤
│                                    │
│  📝 Product Name                   │
│  [________________________]         │
│                                    │
│  📄 Description                    │
│  [________________________]         │
│  [________________________]         │
│                                    │
│  💰 Price                          │
│  [________________________]         │
│                                    │
│  📦 Quantity                       │
│  [________________________]         │
│                                    │
│  📊 Unit (Kg, Bunch, etc)          │
│  [Dropdown ▼]                      │
│                                    │
│  🏪 Category                       │
│  [Dropdown ▼]                      │
│                                    │
│  📍 Pickup Location                │
│  [________________________]         │
│                                    │
│  🚚 Delivery Options               │
│  ☑️ Pick Up                        │
│  ☐ Cooperative Delivery            │
│                                    │
│  📅 Date of Harvest (Optional)     │
│  [Select Date ...]                 │
│                                    │
│  ⏱️ TIMESPAN FOR PERISHABLES      │
│  ┌──────────────────────────┐     │
│  │ ℹ️ Add timespan to        │     │
│  │ indicate shelf life      │     │
│  └──────────────────────────┘     │
│                                    │
│  📋 Product Timespan (Optional)    │
│  [Value]     [Hours/Days ▼]        │
│                                    │
│  💡 Example: "24" + "Hours" or     │
│     "7" + "Days"                   │
│                                    │
│  [SUBMIT PRODUCT FOR APPROVAL]    │
│                                    │
└────────────────────────────────────┘
```

## 📊 Timespan Input Component

### Before Adding Timespan (Old Flow)
```
Product Form
├─ Harvest Date
└─ Submit Button
```

### After Adding Timespan (New Flow)
```
Product Form
├─ Harvest Date
├─ ⭐ Timespan Section
│  ├─ Info Banner
│  ├─ Timespan Value Input
│  ├─ Unit Dropdown (Hours/Days)
│  └─ Example Hint
└─ Submit Button
```

## 🎯 Timespan Input Component Details

### Component Layout
```
┌─────────────────────────────────────────────────┐
│ 📋 Product Timespan (Optional)                  │
├─────────────────────────────────────────────────┤
│                                                 │
│ [Timespan Value]    [Hours/Days ▼]             │
│  Input field         Dropdown selector         │
│  - Accepts numbers   - 2 options               │
│  - Optional          - Default: Hours          │
│  - Positive only                               │
│                                                 │
│ 💡 Example: "24" + "Hours" or "7" + "Days"    │
│    Helpful hint text with common scenarios     │
│                                                 │
└─────────────────────────────────────────────────┘
```

## 🎨 Color Scheme

### Timespan Section Colors
- **Background**: Orange shade 50 (Warning/Perishable context)
- **Border**: Orange shade 200 (Subtle highlight)
- **Icon**: Orange shade 700 (Clear visibility)
- **Text**: Orange shade 800 (Good contrast)
- **Input**: Grey shade 50 (Standard form input)
- **Focus**: Primary Green (App theme)
- **Example Box**: Blue shade 50 (Information color)

### Color Codes
```
Info Banner (Orange):
- Background: #FFF3E0
- Border: #FFE0B2
- Icon: #F57C00
- Text: #E65100

Input Section (Grey):
- Background: #FAFAFA
- Border: #E0E0E0
- Icon: #9E9E9E
- Text: #616161

Example Box (Blue):
- Background: #E3F2FD
- Border: #BBDEFB
- Text: #01579B
```

## 📝 Practical Examples

### Example 1: Fresh Vegetables
```
Seller: Mrs. Santos (Vegetable Farmer)
├─ Product: Fresh Lettuce
├─ Price: ₱50 per Bunch
├─ Quantity: 20 Bunches
├─ Harvest Date: Today
├─ Timespan: 5 Days
└─ Meaning: Lettuce stays fresh for 5 days

Buyer View:
┌──────────────────────┐
│ Fresh Lettuce ₱50    │
│ 🥬 Per Bunch        │
│ ⏱️ Fresh for 5 days  │ ← Shows timespan
│ 🏪 From: Mrs. Santos │
└──────────────────────┘
```

### Example 2: Seafood Products
```
Seller: Juan's Fish Market
├─ Product: Bangus (Fresh)
├─ Price: ₱300 per Kilo
├─ Quantity: 5 Kilos
├─ Harvest Date: Today
├─ Timespan: 24 Hours
└─ Meaning: Must be consumed within 24 hours

Data in Firestore:
{
  "name": "Bangus (Fresh)",
  "price": 300,
  "timespan": 24,
  "timespanUnit": "Hours",
  "harvestDate": Timestamp,
  "status": "approved"
}
```

### Example 3: Dairy Products
```
Seller: Barangay Milk Cooperative
├─ Product: Fresh Goat Milk
├─ Price: ₱120 per Liter
├─ Quantity: 10 Liters
├─ Harvest Date: Today 6am
├─ Timespan: 7 Days
└─ Meaning: Milk stays fresh for 7 days if refrigerated

Timeline:
Day 0: Harvest at 6am
Days 1-7: Buyer can safely use
Day 8: Not recommended for use
```

### Example 4: Non-Perishable Items
```
Seller: Green Valley Grains
├─ Product: Rice (White)
├─ Price: ₱45 per Kilo
├─ Quantity: 50 Kilos
├─ Harvest Date: Last Month
├─ Timespan: (Empty) ← No timespan needed
└─ Meaning: Non-perishable, stable shelf life

Note: Seller leaves timespan blank for
      products that don't spoil quickly
```

## 🔄 Data Flow Diagram

```
┌──────────────────────────────────────────┐
│   Seller Creates Product                 │
├──────────────────────────────────────────┤
│                                          │
│  1. Fill Product Form                    │
│     ├─ Name, Price, Quantity            │
│     ├─ Unit, Category                   │
│     └─ Delivery Options                 │
│                                          │
│  2. Optional: Set Harvest Date           │
│     └─ Tap "Date of Harvest"            │
│                                          │
│  3. Optional: Set Timespan               │
│     ├─ Enter value (24)                 │
│     ├─ Select unit (Hours)              │
│     └─ Meaning: Fresh for 24 hours      │
│                                          │
│  4. Upload Images                        │
│     └─ Select product photos            │
│                                          │
│  5. Submit for Approval                  │
│     └─ Click Submit Button               │
│           ↓                              │
│  6. Data Saved to Firestore              │
│     ├─ timespan: 24                     │
│     ├─ timespanUnit: "Hours"            │
│     └─ status: "pending"                │
│                                          │
│  7. Cooperative Reviews                  │
│     ├─ Checks product details           │
│     ├─ Sees timespan: 24 Hours          │
│     └─ Approves product                 │
│           ↓                              │
│  8. Product Goes Live                    │
│     ├─ Buyers can see it                │
│     ├─ See: "Fresh for 24 hours"        │
│     └─ Can purchase it                  │
│                                          │
└──────────────────────────────────────────┘
```

## 📱 Mobile UI Mockup

### Timespan Section (Actual Size)
```
BEFORE SCROLLING TO TIMESPAN:
┌─────────────────────────────┐
│  📅 Date of Harvest(Opt.)   │
│  [Pick Date       ────────] │
│  Dec 15, 2024              │
│                             │
│  [Scroll Down...]           │
└─────────────────────────────┘

AFTER SCROLLING DOWN:
┌─────────────────────────────────┐
│ ℹ️  Add timespan to indicate   │
│ shelf life for perishable      │
│ products                       │
├─────────────────────────────────┤
│                                 │
│ 📋 Product Timespan (Optional)  │
│                                 │
│ [─24─]  [Hours  ▼]             │
│  Numeric Input  Dropdown        │
│                                 │
│ 💡 Example: "24" + "Hours"     │
│    or "7" + "Days"             │
│                                 │
├─────────────────────────────────┤
│                                 │
│ [SUBMIT PRODUCT FOR APPROVAL]  │
│                                 │
└─────────────────────────────────┘
```

## ✨ State Transitions

### Form State Machine
```
START
│
├─ Empty Form
│  ├─ User fills basic info
│  │  └─ Product Name, Price, Quantity
│  │
│  ├─ User optionally sets Harvest Date
│  │  └─ Click "Date of Harvest"
│  │
│  ├─ User optionally sets Timespan
│  │  ├─ Enter value in Timespan field
│  │  ├─ Select unit (Hours/Days)
│  │  └─ Read example hint
│  │
│  ├─ User uploads images
│  │  └─ Select 1+ product photos
│  │
│  └─ User clicks Submit
│     ├─ Validation check
│     ├─ Images upload
│     ├─ Data saved
│     └─ SUBMITTED
│
END
```

## 🎛️ Input Validation Flow

```
User enters "24" in Timespan field
│
├─ Is field empty?
│  ├─ YES → No problem (optional field)
│  │  └─ timespan = null
│  └─ NO → Continue validation
│
├─ Can parse to integer?
│  ├─ YES → Continue
│  │  └─ timespan = 24
│  └─ NO → Show error (numbers only)
│
├─ Is value positive?
│  ├─ YES → Valid ✓
│  │  └─ Store: timespan = 24
│  └─ NO → Could show warning (optional)
│
└─ Save to Firestore with unit selection
   └─ timespan: 24, timespanUnit: "Hours"
```

## 📊 Database Record Example

### Firestore Document
```json
{
  "id": "prod_12345",
  "name": "Fresh Tomatoes",
  "description": "Juicy red tomatoes from local farm",
  "price": 50,
  "quantity": 20,
  "currentStock": 20,
  "unit": "Kilo (kg)",
  "category": "Vegetables",
  "pickupLocation": "Barangay Hall",
  "deliveryOptions": ["Pick Up"],
  "orderType": "Available Now",
  "harvestDate": Timestamp(2024-12-15),
  "timespan": 7,           ← NEW FIELD
  "timespanUnit": "Days",  ← NEW FIELD
  "sellerId": "seller_123",
  "sellerName": "Mrs. Santos",
  "cooperativeId": "coop_001",
  "status": "approved",
  "createdAt": Timestamp(2024-12-15),
  "imageUrls": ["url1", "url2"]
}
```

## 🔍 Common Scenarios

### Scenario 1: Quick-Spoiling Items
```
Product: Fresh Fish
Harvest: 8:00 AM Today
Timespan: 24 Hours
Means: Must sell/deliver by 8:00 AM Tomorrow
Risk Level: High if delayed
```

### Scenario 2: Medium Shelf Life
```
Product: Leafy Vegetables
Harvest: 6:00 AM Today
Timespan: 5 Days
Means: Usable until 6:00 AM Day 6
Risk Level: Medium - wilting over time
```

### Scenario 3: Long Shelf Life
```
Product: Grains/Rice
Harvest: Last Month
Timespan: 30 Days (or not set)
Means: Stable for extended period
Risk Level: Low
```

### Scenario 4: Non-Perishable
```
Product: Dried Beans
Harvest: Months Ago
Timespan: (Empty)
Means: No urgency, stable indefinitely
Risk Level: None (non-perishable)
```

## 📈 Future Enhancement Ideas

### With Timespan Data, We Can:
1. **Calculate Freshness Percentage**
   - Show progress bar: "80% Fresh" → "20% Fresh"
   - Color changes from green to red

2. **Warn Near-Expiry Products**
   - Badge: "Expires Tomorrow" (red)
   - Badge: "Expires in 3 Days" (orange)
   - Badge: "Fresh" (green)

3. **Auto-Discount for Approaching Expiry**
   - 5 days left: Auto-apply 10% discount
   - 2 days left: Auto-apply 25% discount
   - 1 day left: Auto-apply 50% discount

4. **Seller Dashboard**
   - "Expiring Soon" alerts
   - Sort by expiry date
   - Bulk mark as expired

5. **Buyer Notifications**
   - "New fresh batch available"
   - "Only 1 day left to use your product"
   - "Consider this product on sale"

---

**Visual Guide Status**: ✅ Complete with examples and mockups
