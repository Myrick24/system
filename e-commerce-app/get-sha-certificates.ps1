# Firebase Phone Auth Setup Helper
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Firebase Phone Auth Setup Helper" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Getting your SHA-1 and SHA-256 certificates..." -ForegroundColor Yellow
Write-Host ""

Set-Location android

Write-Host "Running Gradle signing report..." -ForegroundColor Yellow
Write-Host ""
./gradlew signingReport

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "IMPORTANT: Copy the SHA-1 and SHA-256 values above!" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Copy both SHA-1 and SHA-256 from the output above"
Write-Host "2. Go to Firebase Console: https://console.firebase.google.com"
Write-Host "3. Select your project"
Write-Host "4. Go to Project Settings (gear icon)"
Write-Host "5. Scroll to 'Your apps' section"
Write-Host "6. Click 'Add fingerprint' and paste SHA-1"
Write-Host "7. Click 'Add fingerprint' again and paste SHA-256"
Write-Host "8. Download new google-services.json"
Write-Host "9. Replace android/app/google-services.json"
Write-Host "10. Run: flutter clean"
Write-Host "11. Run: flutter pub get"
Write-Host "12. Run: flutter run"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
