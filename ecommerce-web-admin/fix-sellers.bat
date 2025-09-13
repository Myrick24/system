@echo off
echo 🔥 Firebase Seller Status Fix
echo ===========================
echo.

:: Check if Node.js is available
node --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Node.js not found. Please install Node.js first.
    pause
    exit /b 1
)

:: Check if firebase-admin package is installed
if not exist "node_modules\firebase-admin" (
    echo 📦 Installing firebase-admin...
    npm install firebase-admin
    if errorlevel 1 (
        echo ❌ Failed to install firebase-admin
        pause
        exit /b 1
    )
)

:: Check if service account key exists
if exist "firebase-admin-key.json" (
    echo ✅ Service account key found
    set GOOGLE_APPLICATION_CREDENTIALS=%~dp0firebase-admin-key.json
    echo ✅ Environment variable set
) else (
    echo ❌ Service account key not found
    echo.
    echo 📋 Setup Instructions:
    echo 1. Go to https://console.firebase.google.com/
    echo 2. Select project: e-commerce-app-5cda8
    echo 3. Project Settings → Service Accounts tab
    echo 4. Click 'Generate new private key'
    echo 5. Save as 'firebase-admin-key.json' in this folder
    echo 6. Run this script again
    echo.
    pause
    exit /b 1
)

echo.
echo 🚀 Running seller status fix...
echo.

if "%1"=="" (
    echo Fixing all sellers...
    node fix-seller-status-admin.js
) else (
    echo Fixing seller: %1
    node fix-seller-status-admin.js %1
)

echo.
echo ✨ Done!
pause
