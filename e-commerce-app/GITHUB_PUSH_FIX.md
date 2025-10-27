# 🔓 GitHub Push Protection - Unblock Steps

## Current Situation

GitHub detected test API keys in your commits and blocked the push for security.

**Detected Secrets:**
- Stripe Test API Secret Key in `paymongo_service.dart`
- Stripe API Key in `PAYMONGO_GCASH_INTEGRATION_GUIDE.md`

---

## ✅ Quick Fix (Recommended)

Since these are **TEST keys** (not production), you have 3 options:

### **Option 1: Allow the Secret on GitHub (Fastest)**

1. Click this link to allow the secret:
   ```
   https://github.com/Myrick24/system/security/secret-scanning/unblock-secret/34HRMXVe717AlVwF8ey3JX9ootr
   ```

2. After allowing, immediately run:
   ```bash
   git push
   ```

3. **IMMEDIATELY after push**, revoke the exposed keys:
   - Go to https://dashboard.paymongo.com/developers/api-keys
   - Delete/revoke the old test keys
   - Generate new test keys
   - Update your local `paymongo_service.dart` with new keys (don't commit!)

---

### **Option 2: Rewrite Git History (Clean Approach)**

Remove the secrets from Git history completely:

```powershell
# Step 1: Reset to before the secret was added
git reset --soft a869c2d~1

# Step 2: Restore files without secrets
git restore --staged .
git restore .

# Step 3: Manually add files one by one, skipping the secret file
git add e-commerce-app/lib/services/paymongo_service.dart
# Edit the file to remove real keys first!

# Step 4: Commit without secrets
git commit -m "Add PayMongo integration (sanitized)"

# Step 5: Re-add other files
git add .
git commit -m "Merge feature-admin branch"

# Step 6: Force push (⚠️ Only if you're the only one working on this branch)
git push --force-with-lease
```

---

### **Option 3: Use BFG Repo Cleaner (Most Thorough)**

```powershell
# Step 1: Install BFG Repo Cleaner
# Download from: https://rtyley.github.io/bfg-repo-cleaner/

# Step 2: Create a file with the secrets to remove
echo "sk_test_KiH6sokR7sk8UnqoMzUHRmHb" > secrets.txt
echo "pk_test_4tUiAUKKHASyG6h6VWMLjJhH" >> secrets.txt

# Step 3: Run BFG to remove secrets from all history
bfg --replace-text secrets.txt

# Step 4: Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Step 5: Force push
git push --force
```

---

## 🎯 Recommended Workflow

For **quickest resolution**:

1. **Allow the secret** using GitHub's link (they're test keys anyway)
2. **Push immediately**
3. **Revoke the keys** in PayMongo dashboard
4. **Generate new test keys**
5. **Use them locally only** (never commit again)

---

## 📝 For Future Commits

Always use one of these patterns:

### Pattern 1: Config File (Gitignored)
```dart
// lib/config/paymongo_config.dart (add to .gitignore)
class PayMongoConfig {
  static const String publicKey = 'pk_test_YOUR_KEY';
  static const String secretKey = 'sk_test_YOUR_KEY';
}
```

### Pattern 2: Environment Variables
```dart
static String get publicKey => 
  const String.fromEnvironment('PAYMONGO_PUBLIC_KEY');
```

### Pattern 3: Secure Storage
```dart
// Use flutter_secure_storage package
final storage = FlutterSecureStorage();
final publicKey = await storage.read(key: 'paymongo_public_key');
```

---

## ⚡ Run This Now

```powershell
# Quick fix - allow and push
# 1. Click the GitHub link to allow
# 2. Then run:
git push

# 3. Immediately revoke keys at:
# https://dashboard.paymongo.com/developers/api-keys
```

---

## 🔐 Security Reminder

✅ Test keys are **safer** to expose than production keys
✅ Always rotate keys immediately after exposure
✅ Never commit production API keys
✅ Use environment variables or secure storage
✅ Add API config files to .gitignore

The keys in your code were **TEST keys** (`sk_test_*`), so the impact is minimal. Just follow the quick fix above! 🚀
