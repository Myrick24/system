import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'password_reset_otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _mobileController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _mobileError = '';
  DateTime? _lastRequestTime;

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _sendResetCode() async {
    final mobile = _mobileController.text.trim();

    // Clear previous error
    setState(() {
      _mobileError = '';
    });

    // Validate mobile number
    if (mobile.isEmpty) {
      setState(() {
        _mobileError = 'Please enter your mobile number';
      });
      return;
    }

    // Validate mobile number format (Philippine mobile numbers)
    if (!RegExp(r'^09[0-9]{9}$').hasMatch(mobile)) {
      setState(() {
        _mobileError = 'Invalid mobile number format (e.g., 09123456789)';
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

    setState(() {
      _isLoading = true;
    });

    try {
      // First, check if this mobile number is registered
      final querySnapshot = await _firestore
          .collection('users')
          .where('mobile', isEqualTo: mobile)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _mobileError = 'No account found with this mobile number';
          _isLoading = false;
        });
        return;
      }

      // Update last request time
      _lastRequestTime = DateTime.now();

      // Convert Philippine mobile number format to international format
      String phoneNumber = '+63${mobile.substring(1)}';

      // Get user data for password reset
      final userData = querySnapshot.docs.first.data();
      final userId = querySnapshot.docs.first.id;
      final userEmail = userData['email'] as String;
      final userName = userData['name'] as String? ?? 'User';

      // Send OTP via phone verification
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only) - not common for password reset
          setState(() {
            _isLoading = false;
          });
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
          });

          String errorMessage = 'Verification failed. Please try again.';
          if (e.code == 'invalid-phone-number') {
            errorMessage = 'Invalid phone number format';
          } else if (e.code == 'too-many-requests') {
            errorMessage = 'Too many SMS requests. Please wait a few hours and try again.\n\nTip: Try using the email reset option or contact support.';
          } else if (e.code == 'quota-exceeded') {
            errorMessage = 'Daily SMS quota exceeded. Please try again tomorrow.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
          });

          // Navigate to OTP verification screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PasswordResetOtpScreen(
                verificationId: verificationId,
                phoneNumber: phoneNumber,
                userEmail: userEmail,
                userName: userName,
                userId: userId,
                mobile: mobile,
              ),
            ),
          );
        },
        timeout: const Duration(seconds: 60),
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Auto retrieval timeout');
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          'Forgot Password',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(
                Icons.lock_reset,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              Text(
                'Reset Your Password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter your registered mobile number. We\'ll send you a verification code to reset your password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Mobile Number (e.g., 09123456789)',
                  labelText: 'Mobile Number',
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendResetCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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
                    : const Text(
                        'Send Verification Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
