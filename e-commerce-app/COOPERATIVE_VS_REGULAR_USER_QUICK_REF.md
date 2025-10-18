# 🚀 Quick Reference: Cooperative vs Regular User Access

## 🎯 The Key Difference

### 🏢 Cooperative Representative (Created by Admin)
```
Role in Database: "cooperative"
Login → Cooperative Dashboard
Can: Manage deliveries, pickups, payments
Cannot: Browse/buy products as customer
```

### 👨‍🌾 Farmer/Regular User (Self-Registered)
```
Role in Database: "buyer" or "seller"
Login → Unified Main Dashboard
Can: Browse, buy, sell products
Cannot: Access Cooperative Dashboard
```

---

## 📊 Quick Comparison Table

| Feature | Cooperative Rep | Farmer/User |
|---------|----------------|-------------|
| **Created By** | Admin via web dashboard | Self-registration in app |
| **Role Value** | `cooperative` | `buyer` / `seller` |
| **Login Screen** | ✅ Shows login form | ✅ Shows login form |
| **After Login** | → Cooperative Dashboard | → Unified Main Dashboard |
| **See Products** | ❌ No | ✅ Yes |
| **Place Orders** | ❌ No | ✅ Yes |
| **Manage Deliveries** | ✅ Yes | ❌ No |
| **Collect Payments** | ✅ Yes | ❌ No |
| **View Coop Orders** | ✅ Yes | ❌ No |

---

## 🔑 How It Works

### Step 1: Admin Creates Coop Account
```javascript
// Web Dashboard creates:
{
  name: "Coop Kapatiran",
  email: "coop@example.com",
  role: "cooperative",  // ← This determines access
  password: "******"
}
```

### Step 2: System Routes Based on Role
```dart
// login_screen.dart
if (role == 'cooperative') {
  → Navigate to CoopDashboard  ✅
} else {
  → Navigate to UnifiedMainDashboard
}
```

### Step 3: Dashboard Verifies Access
```dart
// coop_dashboard.dart
if (role == 'cooperative' || role == 'admin') {
  → Show cooperative features  ✅
} else {
  → Access Denied  ❌
}
```

---

## ✅ What You Configured

1. **Admin Web Dashboard** ✅
   - Creates cooperative accounts
   - Sets role='cooperative'
   - Provides credentials to coop rep

2. **Login Screen** ✅
   - Checks user role
   - Routes cooperative to CoopDashboard
   - Routes others to UnifiedMainDashboard

3. **Cooperative Dashboard** ✅
   - Verifies role on load
   - Shows delivery/payment management
   - Denies access if role is wrong

4. **Access Control** ✅
   - Role-based routing
   - Dashboard-level verification
   - Firestore security rules

---

## 🎭 User Personas

### Persona 1: Maria (Coop Representative)
```
Account Created By: Admin
Email: maria@coopkapatiran.com
Password: (provided by admin)
Role: cooperative

Login Experience:
1. Opens app
2. Enters maria@coopkapatiran.com
3. Sees: COOPERATIVE DASHBOARD
   - Cooperative Delivery orders
   - Pickup at Coop orders
   - Payment tracking
   - Delivery status updates
```

### Persona 2: Juan (Farmer/Buyer)
```
Account Created By: Self (Sign up button)
Email: juan@gmail.com
Password: (chose himself)
Role: buyer

Login Experience:
1. Opens app
2. Enters juan@gmail.com
3. Sees: UNIFIED MAIN DASHBOARD
   - Product catalog
   - Shopping cart
   - Order history
   - Seller features (if seller)
```

---

## 🚫 Access Restrictions

### What Farmers CANNOT Do:
❌ Access Cooperative Dashboard
❌ See cooperative delivery orders
❌ Manage deliveries for the cooperative
❌ Collect payments on behalf of cooperative
❌ View cooperative statistics

### What Coop Reps CANNOT Do:
❌ Browse products as a customer
❌ Add items to cart
❌ Place personal orders
❌ Register as a seller
❌ Access regular user features

---

## 🎯 Testing Guide

### Test 1: Create & Login as Coop
```
1. Admin creates account:
   Name: Test Coop
   Email: testcoop@example.com
   Password: test123456

2. Coop rep opens app
   Login: testcoop@example.com / test123456
   
3. Expected Result:
   ✅ Goes to Cooperative Dashboard
   ✅ Sees delivery management
   ✅ Does NOT see product catalog
```

### Test 2: Login as Regular User
```
1. Farmer opens app
   Login: farmer@gmail.com / password123

2. Expected Result:
   ✅ Goes to Unified Main Dashboard
   ✅ Sees product catalog
   ✅ Does NOT see cooperative features
```

### Test 3: Try Unauthorized Access
```
1. Farmer somehow opens Coop Dashboard

2. Expected Result:
   ✅ Dashboard checks role
   ✅ Shows "Access Denied"
   ✅ Cannot view cooperative data
```

---

## 🎉 Summary

**Your system correctly separates:**

🏢 **Cooperative Representatives**
- Created by admin
- Role = "cooperative"
- Access Cooperative Dashboard ONLY
- Manage deliveries & payments

👨‍🌾 **Farmers/Regular Users**
- Self-registered
- Role = "buyer" or "seller"
- Access Unified Main Dashboard ONLY
- Shop, buy, sell products

**The role field in Firestore controls everything!** 🔐
