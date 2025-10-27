# 🔐 PayMongo API Keys Configuration Guide

## ⚠️ IMPORTANT: DO NOT COMMIT API KEYS TO GIT

Your PayMongo API keys were removed from the codebase for security reasons. GitHub's push protection detected the secrets and blocked the push.

---

## 🔑 How to Configure API Keys Securely

### **Option 1: Environment Variables (Recommended for Web/Server)**

1. Create a `.env` file in your project root:
```env
PAYMONGO_PUBLIC_KEY=pk_test_your_actual_key_here
PAYMONGO_SECRET_KEY=sk_test_your_actual_key_here
```

2. Add `.env` to `.gitignore`:
```
.env
*.env
```

3. Load environment variables in your app (requires `flutter_dotenv` package)

---

### **Option 2: Local Configuration File (For Flutter Mobile)**

1. Create `lib/config/paymongo_config.dart`:

```dart
class PayMongoConfig {
  // ⚠️ NEVER commit this file with real keys
  static const String publicKey = 'pk_test_YOUR_KEY_HERE';
  static const String secretKey = 'sk_test_YOUR_KEY_HERE';
}
```

2. Add to `.gitignore`:
```
lib/config/paymongo_config.dart
```

3. Create a template file `lib/config/paymongo_config.dart.example`:
```dart
class PayMongoConfig {
  // Get your keys from: https://dashboard.paymongo.com/developers/api-keys
  static const String publicKey = 'pk_test_REPLACE_WITH_YOUR_PUBLIC_KEY';
  static const String secretKey = 'sk_test_REPLACE_WITH_YOUR_SECRET_KEY';
}
```

4. Update `paymongo_service.dart`:
```dart
import '../config/paymongo_config.dart';

class PayMongoService {
  static const String _publicKey = PayMongoConfig.publicKey;
  static const String _secretKey = PayMongoConfig.secretKey;
  // ... rest of the code
}
```

---

### **Option 3: Manual Local Configuration (Quick Fix)**

1. **After cloning the repository**, manually edit `paymongo_service.dart`:

```dart
static const String _publicKey = 'pk_test_YOUR_ACTUAL_KEY';
static const String _secretKey = 'sk_test_YOUR_ACTUAL_KEY';
```

2. **DO NOT commit** these changes. Keep them local only.

3. Use git to ignore local changes:
```bash
git update-index --assume-unchanged e-commerce-app/lib/services/paymongo_service.dart
```

---

## 📝 Current Setup Instructions

### Step 1: Get Your PayMongo API Keys

1. Go to https://dashboard.paymongo.com
2. Sign up or log in
3. Navigate to **Developers > API Keys**
4. Copy your **Test Keys** (for development):
   - Public Key: `pk_test_...`
   - Secret Key: `sk_test_...`

### Step 2: Configure Locally

Choose one of the options above and add your keys **locally only**.

### Step 3: Test the Integration

```bash
cd e-commerce-app
flutter run
```

---

## 🚫 What NOT to Do

❌ **Never commit API keys to Git**
❌ **Never share API keys in documentation**
❌ **Never use production keys in code**
❌ **Never push secrets to GitHub**

---

## ✅ What TO Do

✅ **Use environment variables**
✅ **Use local configuration files (gitignored)**
✅ **Use separate test and production keys**
✅ **Rotate keys if accidentally exposed**
✅ **Use GitHub Secrets for CI/CD**

---

## 🔄 If You Accidentally Committed Secrets

### Option 1: Rewrite Git History (If not pushed yet)
```bash
git reset --soft HEAD~1
# Remove secrets from files
git add .
git commit -m "Remove secrets from codebase"
```

### Option 2: If Already Pushed
1. **Immediately revoke the exposed keys** in PayMongo Dashboard
2. Generate new keys
3. Update your local configuration
4. Push the sanitized code

---

## 📚 Additional Resources

- [PayMongo Documentation](https://developers.paymongo.com/docs)
- [GitHub Secret Scanning](https://docs.github.com/code-security/secret-scanning)
- [Flutter Environment Variables](https://pub.dev/packages/flutter_dotenv)

---

## 🎯 Current Status

✅ **API keys removed from codebase**
✅ **Placeholders added for local configuration**
✅ **Ready for secure local setup**

Follow the steps above to configure your API keys locally without committing them to Git! 🔐
