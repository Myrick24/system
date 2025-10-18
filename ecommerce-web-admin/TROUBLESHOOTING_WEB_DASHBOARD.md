# ⚠️ Web Dashboard Troubleshooting Guide

**Issue**: React development server starts but crashes immediately

---

## 🔍 Current Status

The dependencies are installed correctly, but the React development server exits after starting with these warnings:
- Deprecation warnings about webpack middleware (these are normal and not errors)
- Server exits with code 1 (indicates an error occurred)

---

## 🛠️ Solution Steps

### Step 1: Try Running Manually

Open a **NEW PowerShell terminal** (not in VS Code) and run:

```powershell
cd C:\Users\Mikec\system\ecommerce-web-admin
npm start
```

**Wait for about 30-60 seconds** for the compilation to complete.

The terminal output might be truncated in VS Code, but running in a standalone terminal will show the full error message.

---

### Step 2: Check for Port Conflicts

If port 3000 is already in use:

```powershell
# Check what's using port 3000
netstat -ano | findstr :3000

# Kill the process (replace PID with the actual number)
taskkill /PID [PID] /F

# Or use a different port
$env:PORT=3001; npm start
```

---

### Step 3: Clear Cache and Rebuild

```powershell
cd C:\Users\Mikec\system\ecommerce-web-admin

# Clear npm cache
npm cache clean --force

# Delete node_modules and reinstall
Remove-Item -Recurse -Force node_modules
Remove-Item package-lock.json
npm install

# Try starting again
npm start
```

---

### Step 4: Check for Compilation Errors

The server might be crashing due to TypeScript/React errors. To see them:

```powershell
# Run with verbose output
npm start --verbose
```

Look for errors like:
- `Module not found`
- `Cannot find module`
- `TypeScript error`
- `Syntax error`

---

### Step 5: Alternative - Use React Scripts Directly

```powershell
cd C:\Users\Mikec\system\ecommerce-web-admin

# Run react-scripts directly
npx react-scripts start
```

---

### Step 6: Check Node.js Version

```powershell
node --version
npm --version
```

**Required versions**:
- Node.js: 16.x or higher
- npm: 8.x or higher

If your version is too old:
1. Download latest LTS from: https://nodejs.org/
2. Install
3. Restart terminal
4. Try again

---

### Step 7: Disable Source Maps (Faster Compilation)

```powershell
cd C:\Users\Mikec\system\ecommerce-web-admin

$env:GENERATE_SOURCEMAP="false"
npm start
```

---

### Step 8: Check for Missing Dependencies

```powershell
cd C:\Users\Mikec\system\ecommerce-web-admin

# Reinstall all dependencies
npm install
```

---

## 🔍 Common Errors and Solutions

### Error: "Cannot find module 'react-scripts'"

**Solution**:
```powershell
npm install react-scripts@5.0.1 --save
npm start
```

### Error: "Port 3000 is already in use"

**Solution**:
```powershell
$env:PORT=3001
npm start
```

### Error: "ENOSPC: System limit for number of file watchers reached"

**Solution** (Windows):
```powershell
# Reduce file watching
$env:CHOKIDAR_USEPOLLING="true"
npm start
```

### Error: TypeScript/ESLint errors

**Solution**:
```powershell
# Disable strict type checking temporarily
$env:TSC_COMPILE_ON_ERROR="true"
npm start
```

---

## 📋 Manual Start Instructions

### Option 1: Command Prompt

1. Press `Windows Key + R`
2. Type `cmd` and press Enter
3. Run:
   ```cmd
   cd C:\Users\Mikec\system\ecommerce-web-admin
   npm start
   ```

### Option 2: PowerShell (Standalone)

1. Press `Windows Key + X`
2. Select "Windows PowerShell"
3. Run:
   ```powershell
   cd C:\Users\Mikec\system\ecommerce-web-admin
   npm start
   ```

### Option 3: VS Code Integrated Terminal

1. In VS Code, press `` Ctrl + ` `` (backtick)
2. Click the `+` dropdown → Select "Command Prompt" or "PowerShell"
3. Run:
   ```powershell
   cd C:\Users\Mikec\system\ecommerce-web-admin
   npm start
   ```

---

## 🎯 What to Look For

When the server starts successfully, you should see:

```
Compiled successfully!

You can now view ecommerce-web-admin in the browser.

  Local:            http://localhost:3000
  On Your Network:  http://192.168.x.x:3000

Note that the development build is not optimized.
To create a production build, use npm run build.

webpack compiled successfully
```

Then your browser should open automatically to `http://localhost:3000`

---

## 🐛 If Still Not Working

### Get Full Error Log

```powershell
cd C:\Users\Mikec\system\ecommerce-web-admin
npm start > output.log 2>&1
```

Then open `output.log` to see the full error message.

### Check React Scripts Version

```powershell
npm list react-scripts
```

Should show: `react-scripts@5.0.1`

### Verify Package.json

Make sure `package.json` contains:

```json
{
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build"
  }
}
```

---

## 🚀 Quick Command Reference

```powershell
# Navigate to project
cd C:\Users\Mikec\system\ecommerce-web-admin

# Install dependencies
npm install

# Start server
npm start

# Start with different port
$env:PORT=3001; npm start

# Start with disabled source maps
$env:GENERATE_SOURCEMAP="false"; npm start

# Clear cache and reinstall
npm cache clean --force
Remove-Item -Recurse -Force node_modules
npm install
npm start
```

---

## 📞 Need More Help?

If the server is still not starting, the full error message (visible in a standalone terminal) will tell us exactly what's wrong. Common issues are:

1. Port 3000 already in use
2. Missing or corrupted node_modules
3. TypeScript compilation errors
4. Firewall blocking localhost connections

**Try running in a standalone PowerShell window outside VS Code to see the full error output.**

---

**Last Updated**: October 18, 2025
