# GitHub Push Protection - Quick Fix Script
# This script helps resolve the blocked push due to exposed API keys

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  GitHub Push Protection - Quick Fix" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "⚠️  GitHub detected API keys in your commits" -ForegroundColor Yellow
Write-Host ""
Write-Host "Detected secrets:" -ForegroundColor Red
Write-Host "  - Stripe Test API Secret Key (paymongo_service.dart)" -ForegroundColor Red
Write-Host "  - Stripe API Key (documentation file)" -ForegroundColor Red
Write-Host ""

Write-Host "📋 You have 3 options:" -ForegroundColor White
Write-Host ""
Write-Host "1️⃣  QUICK FIX (Recommended for test keys):" -ForegroundColor Green
Write-Host "   - Allow the secret on GitHub (it's a test key)" -ForegroundColor Gray
Write-Host "   - Push immediately" -ForegroundColor Gray
Write-Host "   - Revoke the key in PayMongo dashboard" -ForegroundColor Gray
Write-Host "   - Generate new test keys" -ForegroundColor Gray
Write-Host ""
Write-Host "2️⃣  CLEAN HISTORY (Removes secrets from all commits):" -ForegroundColor Yellow
Write-Host "   - Rewrite Git history to remove secrets" -ForegroundColor Gray
Write-Host "   - Force push with clean history" -ForegroundColor Gray
Write-Host ""
Write-Host "3️⃣  MANUAL FIX (Most control):" -ForegroundColor Cyan
Write-Host "   - Follow instructions in GITHUB_PUSH_FIX.md" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Choose an option (1, 2, or 3)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "=== QUICK FIX ===" -ForegroundColor Green
        Write-Host ""
        Write-Host "Step 1: Open this URL in your browser:" -ForegroundColor Yellow
        Write-Host "https://github.com/Myrick24/system/security/secret-scanning/unblock-secret/34HRMXVe717AlVwF8ey3JX9ootr" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Step 2: Click 'Allow secret' on the GitHub page" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter after you've allowed the secret"
        Write-Host ""
        Write-Host "Step 3: Pushing to GitHub..." -ForegroundColor Yellow
        git push
        Write-Host ""
        Write-Host "✅ Push completed!" -ForegroundColor Green
        Write-Host ""
        Write-Host "⚠️  IMPORTANT: Now revoke the exposed keys!" -ForegroundColor Red
        Write-Host "   1. Go to: https://dashboard.paymongo.com/developers/api-keys" -ForegroundColor Yellow
        Write-Host "   2. Delete/revoke the test keys" -ForegroundColor Yellow
        Write-Host "   3. Generate new test keys" -ForegroundColor Yellow
        Write-Host "   4. Update your local paymongo_service.dart (don't commit!)" -ForegroundColor Yellow
        Write-Host ""
    }
    "2" {
        Write-Host ""
        Write-Host "=== CLEAN HISTORY ===" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "⚠️  WARNING: This will rewrite Git history!" -ForegroundColor Red
        Write-Host "Only proceed if you're the only one working on this branch." -ForegroundColor Red
        Write-Host ""
        $confirm = Read-Host "Are you sure? (yes/no)"
        if ($confirm -eq "yes") {
            Write-Host ""
            Write-Host "This requires manual steps:" -ForegroundColor Yellow
            Write-Host "1. Create a new branch from before the secret was added" -ForegroundColor Gray
            Write-Host "2. Cherry-pick commits without the secret" -ForegroundColor Gray
            Write-Host "3. Force push" -ForegroundColor Gray
            Write-Host ""
            Write-Host "See GITHUB_PUSH_FIX.md for detailed instructions" -ForegroundColor Cyan
            Write-Host ""
            notepad GITHUB_PUSH_FIX.md
        }
    }
    "3" {
        Write-Host ""
        Write-Host "Opening detailed instructions..." -ForegroundColor Cyan
        notepad GITHUB_PUSH_FIX.md
    }
    default {
        Write-Host ""
        Write-Host "Invalid option. Please run the script again." -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "For more help, see:" -ForegroundColor White
Write-Host "  - GITHUB_PUSH_FIX.md (detailed instructions)" -ForegroundColor Gray
Write-Host "  - PAYMONGO_KEYS_SETUP.md (secure configuration)" -ForegroundColor Gray
Write-Host "==================================================" -ForegroundColor Cyan
