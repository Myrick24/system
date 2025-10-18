# PayMongo API Key Setup Script
# This script helps you configure your PayMongo API keys

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   PayMongo API Key Setup Assistant" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if the service file exists
$serviceFile = "lib\services\paymongo_service.dart"
if (-not (Test-Path $serviceFile)) {
    Write-Host "ERROR: Cannot find $serviceFile" -ForegroundColor Red
    Write-Host "Please run this script from the e-commerce-app directory." -ForegroundColor Yellow
    exit 1
}

Write-Host "Welcome to the PayMongo setup assistant!" -ForegroundColor Green
Write-Host ""
Write-Host "This script will help you configure your PayMongo API keys." -ForegroundColor White
Write-Host ""

# Ask for environment
Write-Host "Which environment are you setting up?" -ForegroundColor Yellow
Write-Host "1. Test/Development (recommended for first setup)" -ForegroundColor White
Write-Host "2. Production/Live" -ForegroundColor White
Write-Host ""
$env = Read-Host "Enter choice (1 or 2)"

if ($env -eq "1") {
    $envName = "TEST"
    $keyPrefix = "pk_test_ and sk_test_"
    Write-Host ""
    Write-Host "Setting up TEST environment..." -ForegroundColor Green
} elseif ($env -eq "2") {
    $envName = "LIVE"
    $keyPrefix = "pk_live_ and sk_live_"
    Write-Host ""
    Write-Host "WARNING: Setting up PRODUCTION environment!" -ForegroundColor Red
    Write-Host "Make sure you have thoroughly tested in TEST mode first." -ForegroundColor Yellow
} else {
    Write-Host "Invalid choice. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Getting your API keys:" -ForegroundColor Cyan
Write-Host "1. Go to: https://dashboard.paymongo.com" -ForegroundColor White
Write-Host "2. Log in to your account" -ForegroundColor White
Write-Host "3. Navigate to: Developers > API Keys" -ForegroundColor White
Write-Host "4. Copy your $envName keys (they start with $keyPrefix)" -ForegroundColor White
Write-Host ""

# Get Public Key
Write-Host "Enter your $envName PUBLIC KEY:" -ForegroundColor Yellow
Write-Host "(Should start with pk_test_ or pk_live_)" -ForegroundColor Gray
$publicKey = Read-Host "Public Key"

if ([string]::IsNullOrWhiteSpace($publicKey)) {
    Write-Host "ERROR: Public key cannot be empty!" -ForegroundColor Red
    exit 1
}

# Get Secret Key
Write-Host ""
Write-Host "Enter your $envName SECRET KEY:" -ForegroundColor Yellow
Write-Host "(Should start with sk_test_ or sk_live_)" -ForegroundColor Gray
$secretKey = Read-Host "Secret Key"

if ([string]::IsNullOrWhiteSpace($secretKey)) {
    Write-Host "ERROR: Secret key cannot be empty!" -ForegroundColor Red
    exit 1
}

# Validate key format
if ($env -eq "1") {
    if (-not $publicKey.StartsWith("pk_test_")) {
        Write-Host "WARNING: Public key should start with 'pk_test_' for test environment!" -ForegroundColor Yellow
    }
    if (-not $secretKey.StartsWith("sk_test_")) {
        Write-Host "WARNING: Secret key should start with 'sk_test_' for test environment!" -ForegroundColor Yellow
    }
} else {
    if (-not $publicKey.StartsWith("pk_live_")) {
        Write-Host "WARNING: Public key should start with 'pk_live_' for live environment!" -ForegroundColor Yellow
    }
    if (-not $secretKey.StartsWith("sk_live_")) {
        Write-Host "WARNING: Secret key should start with 'sk_live_' for live environment!" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Updating $serviceFile..." -ForegroundColor Cyan

# Read the file
$content = Get-Content $serviceFile -Raw

# Replace the keys
$content = $content -replace "static const String _publicKey = '[^']*';", "static const String _publicKey = '$publicKey';"
$content = $content -replace "static const String _secretKey = '[^']*';", "static const String _secretKey = '$secretKey';"

# Write back to file
Set-Content $serviceFile -Value $content

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   API Keys Updated Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Your PayMongo API keys have been configured in:" -ForegroundColor White
Write-Host "  $serviceFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run: flutter pub get" -ForegroundColor White
Write-Host "2. Run: flutter run" -ForegroundColor White
Write-Host "3. Test the GCash payment flow" -ForegroundColor White
Write-Host ""

if ($env -eq "1") {
    Write-Host "Test GCash Credentials:" -ForegroundColor Cyan
    Write-Host "  Mobile Number: 09123456789" -ForegroundColor White
    Write-Host "  OTP Code: 123456" -ForegroundColor White
    Write-Host ""
}

Write-Host "For more information, see:" -ForegroundColor Gray
Write-Host "  PAYMONGO_GCASH_INTEGRATION_GUIDE.md" -ForegroundColor Cyan
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Offer to run flutter pub get
Write-Host "Would you like to run 'flutter pub get' now? (y/n)" -ForegroundColor Yellow
$runPubGet = Read-Host "Choice"

if ($runPubGet -eq "y" -or $runPubGet -eq "Y") {
    Write-Host ""
    Write-Host "Running flutter pub get..." -ForegroundColor Cyan
    flutter pub get
    Write-Host ""
    Write-Host "Done! You're ready to test the PayMongo integration." -ForegroundColor Green
}

Write-Host ""
Write-Host "Setup complete! Happy coding! 🎉" -ForegroundColor Green
Write-Host ""
