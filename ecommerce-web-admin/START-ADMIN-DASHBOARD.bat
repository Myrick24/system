@echo off
echo ========================================
echo  E-commerce Web Admin Dashboard
echo ========================================
echo.
echo Starting the development server...
echo Please wait for compilation (30-60 seconds)
echo.
echo Once started, open your browser to:
echo http://localhost:3000
echo.
echo Press Ctrl+C to stop the server
echo ========================================
echo.

cd /d "C:\Users\Mikec\system\ecommerce-web-admin"
set BROWSER=none
set GENERATE_SOURCEMAP=false
npm start

pause
