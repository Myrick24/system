#!/usr/bin/env pwsh
# Start Web Admin Dashboard Script

Write-Host "🌐 Starting E-commerce Web Admin Dashboard..." -ForegroundColor Cyan
Write-Host ""

# Navigate to the correct directory
$webAdminPath = "C:\Users\Mikec\system\ecommerce-web-admin"
Set-Location $webAdminPath

Write-Host "📁 Current Directory: $(Get-Location)" -ForegroundColor Yellow
Write-Host ""

# Check if node_modules exists
if (!(Test-Path "node_modules")) {
    Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
    npm install
    Write-Host ""
}

# Start the development server
Write-Host "🚀 Starting React development server..." -ForegroundColor Green
Write-Host "⏳ Please wait for compilation..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Once started, the dashboard will open at: http://localhost:3000" -ForegroundColor Cyan
Write-Host ""

# Set environment variable to disable source maps (faster compilation)
$env:GENERATE_SOURCEMAP = "false"

# Start npm
npm start
