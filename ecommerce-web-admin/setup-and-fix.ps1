# Firebase Admin SDK Setup and Seller Fix Script
# This script helps you set up Firebase Admin SDK and run the seller status fix

Write-Host "🔥 Firebase Admin SDK Setup Helper" -ForegroundColor Yellow
Write-Host "=================================" -ForegroundColor Yellow
Write-Host ""

# Check if firebase-admin-key.json exists
$keyPath = ".\firebase-admin-key.json"
$envSet = $false

if (Test-Path $keyPath) {
    Write-Host "✅ Service account key found at $keyPath" -ForegroundColor Green
    
    # Set environment variable
    $fullPath = (Resolve-Path $keyPath).Path
    $env:GOOGLE_APPLICATION_CREDENTIALS = $fullPath
    $envSet = $true
    Write-Host "✅ Environment variable set" -ForegroundColor Green
} else {
    Write-Host "❌ Service account key not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "📋 Setup Instructions:" -ForegroundColor Cyan
    Write-Host "1. Go to https://console.firebase.google.com/" -ForegroundColor White
    Write-Host "2. Select project: e-commerce-app-5cda8" -ForegroundColor White
    Write-Host "3. Project Settings → Service Accounts tab" -ForegroundColor White
    Write-Host "4. Click 'Generate new private key'" -ForegroundColor White
    Write-Host "5. Save as 'firebase-admin-key.json' in this folder" -ForegroundColor White
    Write-Host "6. Run this script again" -ForegroundColor White
    Write-Host ""
    
    $download = Read-Host "Have you downloaded the key? (y/N)"
    if ($download -eq "y" -or $download -eq "Y") {
        Write-Host "Looking for the downloaded key file..." -ForegroundColor Yellow
        
        # Check common download locations
        $downloadPaths = @(
            "$env:USERPROFILE\Downloads\e-commerce-app-5cda8-*.json",
            "$env:USERPROFILE\Downloads\*firebase-adminsdk*.json",
            "$env:USERPROFILE\Downloads\*service-account*.json"
        )
        
        $foundKey = $null
        foreach ($pattern in $downloadPaths) {
            $files = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
            if ($files) {
                $foundKey = $files[0].FullName
                break
            }
        }
        
        if ($foundKey) {
            Write-Host "✅ Found key file: $foundKey" -ForegroundColor Green
            Copy-Item $foundKey $keyPath
            Write-Host "✅ Copied to $keyPath" -ForegroundColor Green
            
            $fullPath = (Resolve-Path $keyPath).Path
            $env:GOOGLE_APPLICATION_CREDENTIALS = $fullPath
            $envSet = $true
            Write-Host "✅ Environment variable set" -ForegroundColor Green
        } else {
            Write-Host "❌ Could not find key file in Downloads folder" -ForegroundColor Red
            Write-Host "Please manually copy the JSON file to this folder and name it 'firebase-admin-key.json'" -ForegroundColor Yellow
            exit 1
        }
    } else {
        exit 1
    }
}

if ($envSet) {
    Write-Host ""
    Write-Host "🚀 Running seller status fix..." -ForegroundColor Green
    Write-Host ""
    
    # Check for specific email parameter
    if ($args.Count -gt 0) {
        $email = $args[0]
        Write-Host "Fixing specific seller: $email" -ForegroundColor Cyan
        node fix-seller-status-admin.js $email
    } else {
        Write-Host "Fixing all sellers..." -ForegroundColor Cyan
        node fix-seller-status-admin.js
    }
}

Write-Host ""
Write-Host "✨ Done!" -ForegroundColor Green
