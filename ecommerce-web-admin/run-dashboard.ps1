# Start Web Admin Dashboard
Write-Host "Starting E-commerce Web Admin Dashboard..." -ForegroundColor Cyan

Set-Location "C:\Users\Mikec\system\ecommerce-web-admin"

Write-Host "Current Directory: $(Get-Location)" -ForegroundColor Yellow

$env:GENERATE_SOURCEMAP = "false"

npm start
