@echo off
echo ========================================
echo Firebase Phone Auth Setup Helper
echo ========================================
echo.
echo Getting your SHA-1 and SHA-256 certificates...
echo.

cd android

echo Running Gradle signing report...
echo.
call gradlew.bat signingReport

echo.
echo ========================================
echo IMPORTANT: Copy the SHA-1 and SHA-256 values above!
echo.
echo Next Steps:
echo 1. Copy both SHA-1 and SHA-256 from the output above
echo 2. Go to Firebase Console: https://console.firebase.google.com
echo 3. Select your project
echo 4. Go to Project Settings (gear icon)
echo 5. Scroll to "Your apps" section
echo 6. Click "Add fingerprint" and paste SHA-1
echo 7. Click "Add fingerprint" again and paste SHA-256
echo 8. Download new google-services.json
echo 9. Replace android/app/google-services.json
echo 10. Run: flutter clean
echo 11. Run: flutter pub get
echo 12. Run: flutter run
echo ========================================
echo.
pause
