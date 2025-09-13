# Quick Firestore Rules Deployment
Write-Host "Deploying Firestore Rules..." -ForegroundColor Green
Write-Host ""

Set-Location "d:\capstone-system\e-commerce-app"

Write-Host "Current directory: $(Get-Location)" -ForegroundColor Yellow
Write-Host ""

Write-Host "Checking Firebase CLI..." -ForegroundColor Blue
try {
    firebase --version
    Write-Host "Firebase CLI is working" -ForegroundColor Green
} catch {
    Write-Host "Firebase CLI not found or not working" -ForegroundColor Red
    Write-Host "Install with: npm install -g firebase-tools" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "Checking Firebase login status..." -ForegroundColor Blue
try {
    firebase projects:list
} catch {
    Write-Host "Not logged in to Firebase. Run: firebase login" -ForegroundColor Red
}
Write-Host ""

Write-Host "Deploying Firestore rules..." -ForegroundColor Blue
try {
    firebase deploy --only firestore:rules
    Write-Host "Deployment successful!" -ForegroundColor Green
} catch {
    Write-Host "Deployment failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
