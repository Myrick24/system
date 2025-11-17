# Firebase Cloud Functions Deployment Script
# Run this script from the e-commerce-app directory

Write-Host "🚀 Firebase Cloud Functions Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Navigate to functions directory
Write-Host "📁 Step 1: Navigating to functions directory..." -ForegroundColor Yellow
Set-Location -Path "functions"

if (-not (Test-Path "package.json")) {
    Write-Host "❌ Error: package.json not found. Are you in the correct directory?" -ForegroundColor Red
    exit 1
}

# Step 2: Install dependencies
Write-Host "📦 Step 2: Installing dependencies..." -ForegroundColor Yellow
npm install

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
    exit 1
}

# Step 3: Build TypeScript
Write-Host "🔨 Step 3: Building TypeScript..." -ForegroundColor Yellow
npm run build

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to build TypeScript" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Build successful!" -ForegroundColor Green
Write-Host ""

# Step 4: Go back to root and deploy
Write-Host "🚀 Step 4: Deploying to Firebase..." -ForegroundColor Yellow
Set-Location -Path ".."

firebase deploy --only functions

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Deployment failed" -ForegroundColor Red
    Write-Host "💡 Make sure you're logged in: firebase login" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Verify functions: firebase functions:list" -ForegroundColor White
Write-Host "2. Test notifications with app closed" -ForegroundColor White
Write-Host "3. Monitor logs: firebase functions:log" -ForegroundColor White
Write-Host ""
Write-Host "📚 Documentation: See BACKGROUND_NOTIFICATIONS_COMPLETE.md" -ForegroundColor Cyan
