@echo off
echo Deploying Firestore Rules...
echo.

cd /d "d:\capstone-system\e-commerce-app"

echo Current directory: %CD%
echo.

echo Checking Firebase CLI...
firebase --version
echo.

echo Checking Firebase login status...
firebase projects:list
echo.

echo Deploying Firestore rules...
firebase deploy --only firestore:rules

echo.
echo Deployment complete!
pause
