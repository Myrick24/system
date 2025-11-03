import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'registration_screen.dart';
import 'otp_verification_screen.dart';
import 'buyer/buyer_main_dashboard.dart';
import '../widgets/address_selector.dart';
import '../theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _mobileController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _agreeToTerms = false;
  bool _agreeToPrivacy = false;
  Map<String, String> _selectedAddress = {};
  DateTime? _lastRequestTime; // Track last phone auth request

  String _nameError = '';
  String _emailError = '';
  String _passwordError = '';
  String _confirmPasswordError = '';
  String _mobileError = '';
  String _addressError = '';

  @override
  void initState() {
    super.initState();
    // Add listeners to clear errors when user types
    _nameController.addListener(() {
      if (_nameError.isNotEmpty) {
        setState(() {
          _nameError = '';
        });
      }
    });
    _emailController.addListener(() {
      if (_emailError.isNotEmpty) {
        setState(() {
          _emailError = '';
        });
      }
    });
    _passwordController.addListener(() {
      if (_passwordError.isNotEmpty) {
        setState(() {
          _passwordError = '';
        });
      }
    });
    _confirmPasswordController.addListener(() {
      if (_confirmPasswordError.isNotEmpty) {
        setState(() {
          _confirmPasswordError = '';
        });
      }
    });
    _mobileController.addListener(() {
      if (_mobileError.isNotEmpty) {
        setState(() {
          _mobileError = '';
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final mobile = _mobileController.text.trim();

    // Clear previous errors
    setState(() {
      _nameError = '';
      _emailError = '';
      _passwordError = '';
      _confirmPasswordError = '';
      _mobileError = '';
      _addressError = '';
    });

    // Validate all fields are not empty
    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        mobile.isEmpty ||
        _selectedAddress.isEmpty) {
      setState(() {
        if (name.isEmpty) _nameError = 'Please enter name';
        if (email.isEmpty) _emailError = 'Please enter email';
        if (password.isEmpty) _passwordError = 'Please enter password';
        if (confirmPassword.isEmpty)
          _confirmPasswordError = 'Please confirm password';
        if (mobile.isEmpty) _mobileError = 'Please enter mobile number';
        if (_selectedAddress.isEmpty)
          _addressError = 'Please select complete address';
      });
      return;
    }

    // Validate mobile number format (basic validation for Philippine mobile numbers)
    if (!RegExp(r'^09[0-9]{9}$').hasMatch(mobile)) {
      setState(() {
        _mobileError = 'Invalid mobile number format (e.g., 09123456789)';
      });
      return;
    }

    // Check if terms are agreed
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms and Conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if privacy policy is agreed
    if (!_agreeToPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Data Privacy Policy'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _passwordError = 'Passwords do not match';
        _confirmPasswordError = 'Passwords do not match';
      });
      return;
    }

    // Check cooldown period (60 seconds between requests)
    if (_lastRequestTime != null) {
      final secondsSinceLastRequest =
          DateTime.now().difference(_lastRequestTime!).inSeconds;
      if (secondsSinceLastRequest < 60) {
        final remainingSeconds = 60 - secondsSinceLastRequest;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Please wait $remainingSeconds seconds before trying again'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    // Update last request time
    _lastRequestTime = DateTime.now();

    setState(() {
      _isLoading = true;
    });

    try {
      // Convert Philippine mobile number format (09xxxxxxxxx) to international format (+639xxxxxxxxx)
      String phoneNumber = '+63${mobile.substring(1)}';

      // Initiate phone number verification
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only)
          setState(() {
            _isLoading = false;
          });

          // For auto-verification, directly create account
          try {
            await _auth.signInWithCredential(credential);

            // Create user account with email and password
            final userCredential = await _auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );

            // Store user data in Firestore
            await _firestore
                .collection('users')
                .doc(userCredential.user!.uid)
                .set({
              'name': name,
              'email': email,
              'mobile': mobile,
              'address': _selectedAddress,
              'role': 'buyer',
              'status': 'active',
              'emailVerified': true,
              'mobileVerified': true,
              'createdAt': FieldValue.serverTimestamp(),
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account created successfully!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const BuyerMainDashboard(),
                ),
                (route) => false,
              );
            }
          } catch (e) {
            print('Auto-verification error: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Verification error: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
          });

          print('Phone verification failed: ${e.code} - ${e.message}');

          String errorMessage = 'Failed to send OTP. Please try again.';
          if (e.code == 'invalid-phone-number') {
            errorMessage = 'Invalid phone number format.';
          } else if (e.code == 'too-many-requests') {
            errorMessage =
                'Too many requests. Please wait a moment and try again.';
          } else if (e.code == 'invalid-app-credential' ||
              e.code == 'unknown') {
            errorMessage =
                'Unable to send OTP. Please check your Firebase configuration and add SHA certificates.';
          } else if (e.message != null) {
            errorMessage = e.message!;
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
          });

          // Navigate to OTP verification screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(
                name: name,
                email: email,
                password: password,
                mobile: mobile,
                address: _selectedAddress,
                verificationId: verificationId,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Auto-retrieval timeout: $verificationId');
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show Terms and Conditions Dialog
  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    '📋',
                    style: TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Terms and Conditions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last Updated: October 2025',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to HARVEST, a mobile platform that connects farmers, cooperatives, and buyers for easier and fair agricultural trading. By using this app, you agree to follow the rules and responsibilities written below. Please read them carefully.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTermsSection(
                      '1. Account Registration',
                      'Users must provide accurate and complete information during registration. You are responsible for maintaining the security of your account credentials.',
                    ),
                    const SizedBox(height: 16),
                    _buildTermsSection(
                      '2. User Conduct',
                      'Users must use the platform responsibly and lawfully. Any fraudulent activity or misuse of the platform may result in account suspension.',
                    ),
                    const SizedBox(height: 16),
                    _buildTermsSection(
                      '3. Privacy',
                      'Your personal information will be protected and used only for platform-related purposes. We will not share your data with third parties without your consent.',
                    ),
                    const SizedBox(height: 16),
                    _buildTermsSection(
                      '4. Product Transactions',
                      'Buyers and sellers are responsible for ensuring fair and honest transactions. HARVEST provides the platform but is not liable for disputes between parties.',
                    ),
                    const SizedBox(height: 16),
                    _buildTermsSection(
                      '5. Changes to Terms',
                      'HARVEST reserves the right to update these terms at any time. Users will be notified of significant changes.',
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'I Understand',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // Show Data Privacy Policy Dialog
  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    '🔒',
                    style: TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Data Privacy Policy',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last Updated: October 2025',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HARVEST respects your privacy and is committed to protecting your personal information. This Data Privacy Policy explains how we collect, use, and safeguard your data in accordance with the Data Privacy Act of 2012 (Republic Act No. 10173).',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTermsSection(
                      '1. Information We Collect',
                      'We collect personal information such as your name, email address, mobile number, and address to facilitate your use of the HARVEST platform. This information is necessary for account creation, order processing, and communication.',
                    ),
                    const SizedBox(height: 16),
                    _buildTermsSection(
                      '2. How We Use Your Information',
                      'Your personal data is used to: (a) Process transactions and orders, (b) Communicate with you about your account and orders, (c) Improve our services, (d) Comply with legal obligations. We will never sell your personal information to third parties.',
                    ),
                    const SizedBox(height: 16),
                    _buildTermsSection(
                      '3. Data Security',
                      'We implement appropriate technical and organizational measures to protect your personal data against unauthorized access, alteration, disclosure, or destruction. Your data is stored securely on Firebase servers with encryption.',
                    ),
                    const SizedBox(height: 16),
                    _buildTermsSection(
                      '4. Your Rights',
                      'Under the Data Privacy Act, you have the right to: (a) Access your personal data, (b) Correct inaccurate data, (c) Request deletion of your data, (d) Object to data processing, (e) Withdraw consent at any time. Contact us to exercise these rights.',
                    ),
                    const SizedBox(height: 16),
                    _buildTermsSection(
                      '5. Data Retention',
                      'We retain your personal data only for as long as necessary to fulfill the purposes outlined in this policy or as required by law. You may request deletion of your account and data at any time.',
                    ),
                    const SizedBox(height: 16),
                    _buildTermsSection(
                      '6. Third-Party Services',
                      'We use Firebase (Google) for data storage and authentication. These services have their own privacy policies and security measures. We do not control third-party policies but ensure they meet adequate protection standards.',
                    ),
                    const SizedBox(height: 16),
                    _buildTermsSection(
                      '7. Contact Us',
                      'If you have questions about this Data Privacy Policy or wish to exercise your data protection rights, please contact us through the app\'s Help & Support section.',
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'I Understand',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text.rich(
                TextSpan(
                  text: 'Welcome to ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  children: [
                    TextSpan(
                      text: 'Harvest!',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Name',
                  errorText: _nameError.isNotEmpty ? _nameError : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _nameError.isNotEmpty
                        ? const BorderSide(color: Colors.red, width: 2)
                        : const BorderSide(),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _nameError.isNotEmpty
                        ? const BorderSide(color: Colors.red, width: 2)
                        : const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _nameError.isNotEmpty
                        ? const BorderSide(color: Colors.red, width: 2)
                        : const BorderSide(color: Colors.green, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email Address',
                  errorText: _emailError.isNotEmpty ? _emailError : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _emailError.isNotEmpty
                        ? const BorderSide(color: Colors.red, width: 2)
                        : const BorderSide(),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _emailError.isNotEmpty
                        ? const BorderSide(color: Colors.red, width: 2)
                        : const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _emailError.isNotEmpty
                        ? const BorderSide(color: Colors.red, width: 2)
                        : const BorderSide(color: Colors.green, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  hintText: 'Password',
                  errorText: _passwordError.isNotEmpty ? _passwordError : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _passwordError.isNotEmpty
                        ? const BorderSide(color: Colors.red, width: 2)
                        : const BorderSide(),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _passwordError.isNotEmpty
                        ? const BorderSide(color: Colors.red, width: 2)
                        : const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _passwordError.isNotEmpty
                        ? const BorderSide(color: Colors.red, width: 2)
                        : const BorderSide(color: Colors.green, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _passwordVisible = !_passwordVisible;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: !_confirmPasswordVisible,
                decoration: InputDecoration(
                  hintText: 'Confirm Password',
                  errorText: _confirmPasswordError.isNotEmpty
                      ? _confirmPasswordError
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _confirmPasswordError.isNotEmpty
                        ? const BorderSide(color: Colors.red, width: 2)
                        : const BorderSide(),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _confirmPasswordError.isNotEmpty
                        ? const BorderSide(color: Colors.red, width: 2)
                        : const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _confirmPasswordError.isNotEmpty
                        ? const BorderSide(color: Colors.red, width: 2)
                        : const BorderSide(color: Colors.green, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _confirmPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _confirmPasswordVisible = !_confirmPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Mobile Number (e.g., 09123456789)',
                  errorText: _mobileError.isNotEmpty ? _mobileError : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _mobileError.isNotEmpty
                        ? const BorderSide(color: Colors.red, width: 2)
                        : const BorderSide(),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _mobileError.isNotEmpty
                        ? const BorderSide(color: Colors.red, width: 2)
                        : const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: _mobileError.isNotEmpty
                        ? const BorderSide(color: Colors.red, width: 2)
                        : const BorderSide(color: Colors.green, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  prefixIcon: const Icon(Icons.phone, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              // Address Selector with Philippine Dataset
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Complete Address',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const Text(
                        ' *',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _addressError.isNotEmpty
                            ? Colors.red
                            : Colors.grey.shade300,
                        width: _addressError.isNotEmpty ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: AddressSelector(
                      onAddressChanged: (address) {
                        setState(() {
                          _selectedAddress = address;
                          if (_addressError.isNotEmpty) {
                            _addressError = '';
                          }
                        });
                      },
                    ),
                  ),
                  if (_addressError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 8),
                      child: Text(
                        _addressError,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Terms and Conditions Checkbox
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                ),
                child: CheckboxListTile(
                  title: GestureDetector(
                    onTap: _showTermsDialog,
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms and Conditions',
                            style: const TextStyle(
                              color: AppTheme.primaryGreen,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  value: _agreeToTerms,
                  onChanged: (value) {
                    setState(() {
                      _agreeToTerms = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                ),
              ),
              const SizedBox(height: 12),
              // Data Privacy Policy Checkbox
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                ),
                child: CheckboxListTile(
                  title: GestureDetector(
                    onTap: _showPrivacyDialog,
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Data Privacy Policy',
                            style: const TextStyle(
                              color: AppTheme.primaryGreen,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  value: _agreeToPrivacy,
                  onChanged: (value) {
                    setState(() {
                      _agreeToPrivacy = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_isLoading || !_agreeToTerms || !_agreeToPrivacy)
                    ? null
                    : _signup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_add, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: (_agreeToTerms && _agreeToPrivacy)
                                  ? Colors.white
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
              // Separator with "or" text
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Colors.grey.shade400,
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Colors.grey.shade400,
                      thickness: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?'),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Seller section
              Text(
                'Want to sell your products?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  // Navigate directly to seller registration
                  // The registration screen will handle account creation if needed
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegistrationScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                  side:
                      const BorderSide(color: AppTheme.primaryGreen, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.storefront,
                        size: 20, color: AppTheme.primaryGreen),
                    SizedBox(width: 8),
                    Text(
                      'Apply as Seller',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
