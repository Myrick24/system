# 🌐 How to Run the Web Admin Dashboard

**Last Updated**: October 18, 2025  
**Project**: E-commerce Web Admin Dashboard  
**Tech Stack**: React + TypeScript + Firebase + Ant Design

---

## 📋 Quick Start (3 Steps)

### Option 1: Using PowerShell Script (Easiest)

```powershell
# Navigate to web admin folder
cd C:\Users\Mikec\system\ecommerce-web-admin

# Run the start script
.\start_admin_dashboard.ps1
```

### Option 2: Using npm (Standard)

```powershell
# Navigate to web admin folder
cd C:\Users\Mikec\system\ecommerce-web-admin

# Install dependencies (first time only)
npm install

# Start the development server
npm start
```

### Option 3: Using the Batch File

```powershell
# Navigate to web admin folder
cd C:\Users\Mikec\system\ecommerce-web-admin

# Double-click or run:
start_admin_dashboard.bat
```

---

## 🎯 Complete Step-by-Step Guide

### Step 1: Open Terminal

**PowerShell** (Recommended):
```powershell
# Press Windows Key + X
# Select "Windows PowerShell" or "Terminal"
```

### Step 2: Navigate to Project

```powershell
cd C:\Users\Mikec\system\ecommerce-web-admin
```

### Step 3: Install Dependencies (First Time Only)

If this is your **first time** running the dashboard:

```powershell
npm install
```

**This will install**:
- React 18.3.1
- Ant Design 5.19.1
- Firebase 10.14.1
- TypeScript
- React Router
- All other dependencies

**Wait time**: 2-5 minutes depending on internet speed

### Step 4: Start the Server

```powershell
npm start
```

**What happens**:
1. Compiles the React app
2. Starts development server
3. Opens browser automatically at `http://localhost:3000`
4. Shows compilation progress

**Expected output**:
```
Compiled successfully!

You can now view ecommerce-web-admin in the browser.

  Local:            http://localhost:3000
  On Your Network:  http://192.168.x.x:3000

Note that the development build is not optimized.
To create a production build, use npm run build.

webpack compiled successfully
```

### Step 5: Login

The browser will open automatically. If not, go to: `http://localhost:3000`

**Login Credentials**:
- **Email**: `admin@gmail.com`
- **Password**: `admin123`

*(Or use any admin account you created)*

---

## 🖥️ After Starting Successfully

### What You'll See

```
┌─────────────────────────────────────────────────┐
│          E-commerce Admin Dashboard             │
├─────────────────────────────────────────────────┤
│                                                 │
│  📧 Email: _____________________________       │
│                                                 │
│  🔒 Password: _________________________       │
│                                                 │
│              [ Login ]                          │
│                                                 │
└─────────────────────────────────────────────────┘
```

After login:

```
┌─────────────────────────────────────────────────┐
│  Dashboard  |  Users  |  Products  |  Orders   │
├─────────────────────────────────────────────────┤
│                                                 │
│  📊 Dashboard Overview                          │
│                                                 │
│  Total Users: 150                               │
│  Total Sellers: 25                              │
│  Pending Approvals: 5                           │
│  Total Products: 300                            │
│                                                 │
│  Recent Activity                                │
│  └─ [Activity list...]                          │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## 🔧 Available Scripts

### Development

```powershell
# Start development server (with hot reload)
npm start

# Runs on: http://localhost:3000
# Automatically opens browser
# Hot reload enabled (changes reflect immediately)
```

### Production Build

```powershell
# Create optimized production build
npm run build

# Output: build/ folder
# Ready to deploy to hosting
```

### Testing

```powershell
# Run tests
npm test
```

---

## 🌐 Accessing the Dashboard

### Local Access (Your Computer)

```
http://localhost:3000
```

### Network Access (Other Devices on Same Network)

```
http://192.168.x.x:3000
```

Replace `192.168.x.x` with your computer's IP address shown in the terminal output.

**To find your IP**:
```powershell
ipconfig
```
Look for "IPv4 Address" under your active network adapter.

---

## 📱 Features Available in Web Dashboard

### 1. Dashboard Home
- **Path**: `/` or `/dashboard`
- **Features**:
  - Total users count
  - Total sellers count
  - Pending approvals
  - Total products
  - Recent activity feed
  - Quick stats

### 2. User Management
- **Path**: `/users`
- **Features**:
  - View all users (buyers, sellers)
  - Filter by role
  - Approve/reject sellers
  - Suspend accounts
  - View user details

### 3. Product Management
- **Path**: `/products`
- **Features**:
  - View all products
  - Approve/reject listings
  - View product images
  - Edit product details
  - Delete products

### 4. Transaction Monitoring
- **Path**: `/transactions`
- **Features**:
  - View all orders
  - Filter by status
  - Date range filtering
  - Transaction details
  - Update order status

### 5. Firebase Debugger
- **Path**: `/debug`
- **Features**:
  - Test Firebase connection
  - Test authentication
  - Check admin users
  - Network diagnostics

---

## 🚨 Troubleshooting

### Issue 1: "npm is not recognized"

**Problem**: Node.js not installed

**Solution**:
1. Download Node.js from: https://nodejs.org/
2. Install LTS version (20.x or higher)
3. Restart terminal
4. Try again

**Verify installation**:
```powershell
node --version
npm --version
```

---

### Issue 2: Port 3000 Already in Use

**Problem**: Another app is using port 3000

**Error message**:
```
Something is already running on port 3000.
```

**Solution Option A** - Use different port:
```powershell
# Windows PowerShell
$env:PORT=3001; npm start

# Or edit package.json scripts:
"start": "set PORT=3001 && react-scripts start"
```

**Solution Option B** - Kill process on port 3000:
```powershell
# Find process using port 3000
netstat -ano | findstr :3000

# Kill the process (replace PID with actual number)
taskkill /PID [PID] /F
```

---

### Issue 3: Firebase Configuration Error

**Problem**: Firebase not configured correctly

**Error**: "Firebase: No Firebase App '[DEFAULT]' has been created"

**Solution**:
1. Check `src/config/firebase.ts`
2. Ensure Firebase config matches your Flutter app
3. Verify Firebase project ID

**Your Firebase config should match**:
```typescript
export const firebaseConfig = {
  apiKey: "AIzaSyCcD8N4YSL1jnGhkh1VsFNzgBDpATSuJ3s",
  authDomain: "e-commerce-app-5cda8.firebaseapp.com",
  projectId: "e-commerce-app-5cda8",
  storageBucket: "e-commerce-app-5cda8.firebasestorage.app",
  messagingSenderId: "383808898569",
  appId: "1:383808898569:web:..."
};
```

---

### Issue 4: Login Not Working

**Problem**: Cannot login with admin credentials

**Solutions**:

**A. Check admin account exists**:
```powershell
# Firebase Console
# https://console.firebase.google.com
# → Your project → Authentication
# → Look for admin@gmail.com
```

**B. Check admin role in Firestore**:
```
Firebase Console → Firestore Database
→ users collection
→ Find admin user document
→ Check: role = "admin"
```

**C. Use Firebase Debugger**:
```
1. Go to: http://localhost:3000/debug
2. Test Firebase connection
3. Test authentication
4. Check admin user exists
```

---

### Issue 5: Dependencies Installation Failed

**Problem**: `npm install` errors

**Solution**:
```powershell
# Clear npm cache
npm cache clean --force

# Delete node_modules and package-lock.json
Remove-Item -Recurse -Force node_modules
Remove-Item package-lock.json

# Reinstall
npm install
```

---

### Issue 6: Compilation Errors

**Problem**: TypeScript or React errors during compilation

**Solution**:
```powershell
# Stop the server (Ctrl + C)

# Clear cache
npm cache clean --force

# Delete build files
Remove-Item -Recurse -Force node_modules\.cache

# Restart
npm start
```

---

## 💻 Development Tips

### Hot Reload

The dev server has **hot reload** enabled:
- Save any file in `src/`
- Browser automatically refreshes
- See changes immediately

### Browser DevTools

Press `F12` to open DevTools:
- **Console**: See logs and errors
- **Network**: Monitor API calls
- **Application**: Check Firebase connection

### React DevTools

Install React DevTools extension:
- [Chrome](https://chrome.google.com/webstore/detail/react-developer-tools/fmkadmapgofadopljbjfkapdkoienihi)
- [Firefox](https://addons.mozilla.org/en-US/firefox/addon/react-devtools/)

---

## 📦 Project Structure

```
ecommerce-web-admin/
├── public/
│   ├── index.html          # HTML template
│   └── favicon.ico         # Browser icon
├── src/
│   ├── components/         # React components
│   │   ├── App.tsx        # Main app
│   │   ├── LoginPage.tsx  # Login screen
│   │   ├── DashboardHome.tsx      # Dashboard
│   │   ├── UserManagement.tsx     # Users
│   │   ├── ProductManagement.tsx  # Products
│   │   └── TransactionMonitoring.tsx # Orders
│   ├── contexts/
│   │   └── AuthContext.tsx # Auth state
│   ├── services/
│   │   ├── firebase.ts    # Firebase config
│   │   ├── adminService.ts # Admin functions
│   │   └── ...            # Other services
│   ├── types/
│   │   └── index.ts       # TypeScript types
│   └── index.tsx          # Entry point
├── package.json           # Dependencies
├── tsconfig.json          # TypeScript config
└── README.md              # Documentation
```

---

## 🔐 Admin Account Setup

### If You Don't Have Admin Account Yet

**Option 1: Create via Flutter App** (Recommended)
1. Run your Flutter app
2. Use admin setup tool
3. Creates admin in Firebase Auth + Firestore

**Option 2: Manual Firebase Console Setup**

**A. Create Firebase Auth user**:
```
1. Firebase Console → Authentication → Users
2. Add user → Email/Password
3. Email: admin@gmail.com
4. Password: admin123
5. Save
```

**B. Add Firestore document**:
```
1. Firebase Console → Firestore Database
2. Collection: users
3. Document ID: [Copy UID from Auth]
4. Fields:
   - name: "Admin"
   - email: "admin@gmail.com"
   - role: "admin"
   - status: "active"
5. Save
```

---

## 🚀 Deployment (Optional)

### Build for Production

```powershell
npm run build
```

**Output**: `build/` folder with optimized files

### Deploy to Firebase Hosting

```powershell
# Install Firebase CLI (if not already)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize hosting (first time only)
firebase init hosting

# Deploy
firebase deploy --only hosting
```

**Your admin dashboard will be live at**:
```
https://e-commerce-app-5cda8.web.app
```

---

## 📊 Performance

### Development Server
- **Start time**: 20-40 seconds
- **Hot reload**: 1-3 seconds
- **Memory usage**: ~200-400 MB

### Production Build
- **Build time**: 1-2 minutes
- **Output size**: ~2-5 MB (gzipped)
- **Load time**: 1-2 seconds

---

## 🎨 Customization

### Change Port

Edit `package.json`:
```json
"scripts": {
  "start": "set PORT=3001 && react-scripts start"
}
```

### Change Theme

Edit `src/components/App.tsx`:
```typescript
// Ant Design theme configuration
import { ConfigProvider } from 'antd';

<ConfigProvider
  theme={{
    token: {
      colorPrimary: '#00b96b', // Change primary color
    },
  }}
>
  {/* Your app */}
</ConfigProvider>
```

---

## 📞 Common Commands Reference

```powershell
# Navigate to project
cd C:\Users\Mikec\system\ecommerce-web-admin

# Install dependencies
npm install

# Start dev server
npm start

# Build for production
npm run build

# Check versions
node --version
npm --version

# Clear cache
npm cache clean --force

# Update packages
npm update

# View package info
npm list
```

---

## ✅ Checklist Before Running

```
□ Node.js installed (v16+)
□ npm working (check: npm --version)
□ In correct directory (ecommerce-web-admin)
□ Dependencies installed (npm install)
□ Firebase config correct (src/config/firebase.ts)
□ Admin account exists (Firebase Auth + Firestore)
□ Port 3000 available (or use different port)
□ Internet connection active (for Firebase)
```

---

## 🎉 Success Indicators

When everything works correctly:

```
✅ Terminal shows "Compiled successfully!"
✅ Browser opens automatically to http://localhost:3000
✅ Login page loads without errors
✅ Can login with admin credentials
✅ Dashboard shows data from Firebase
✅ All pages navigate correctly
✅ No console errors (F12)
```

---

## 📚 Additional Resources

- **React Documentation**: https://react.dev/
- **Ant Design**: https://ant.design/
- **Firebase Docs**: https://firebase.google.com/docs
- **TypeScript**: https://www.typescriptlang.org/

---

## 🆘 Getting Help

### Check Logs

**Browser Console** (F12):
- Check for JavaScript errors
- Monitor network requests
- View Firebase connection status

**Terminal Output**:
- Compilation errors
- Warning messages
- Server status

### Debug Mode

Visit: `http://localhost:3000/debug`
- Test Firebase connection
- Check authentication
- Verify admin user

---

**Quick Command**:
```powershell
cd C:\Users\Mikec\system\ecommerce-web-admin && npm start
```

**That's it!** Your admin dashboard should now be running at `http://localhost:3000` 🎊
