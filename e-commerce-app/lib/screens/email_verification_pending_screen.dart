import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailVerificationPendingScreen extends StatefulWidget {
  final String email;

  const EmailVerificationPendingScreen({
    Key? key,
    required this.email,
  }) : super(key: key);

  @override
  State<EmailVerificationPendingScreen> createState() =>
      _EmailVerificationPendingScreenState();
}

class _EmailVerificationPendingScreenState
    extends State<EmailVerificationPendingScreen> {
  final _auth = FirebaseAuth.instance;
  late User? _currentUser;
  bool _isCheckingVerification = false;
  bool _verificationComplete = false;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _startVerificationCheck();
  }

  void _startVerificationCheck() {
    // Check verification status periodically
    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted && !_verificationComplete) {
        await _checkEmailVerification();
      }
    });
  }

  Future<void> _checkEmailVerification() async {
    try {
      // Refresh the user to get the latest verification status
      await _currentUser?.reload();
      _currentUser = _auth.currentUser;

      if (mounted) {
        if (_currentUser?.emailVerified ?? false) {
          // Email is verified
          print('Email verified! User: ${_currentUser?.email}');

          // Update Firestore to mark email as verified
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUser?.uid)
                .update({
              'emailVerified': true,
            });
          } catch (e) {
            print('Error updating Firestore: $e');
          }

          setState(() {
            _verificationComplete = true;
          });

          // Show success message and navigate to home
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email verified successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );

            // Navigate to home dashboard after a short delay
            await Future.delayed(const Duration(seconds: 1));
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
            }
          }
        } else {
          // Not verified yet, continue checking
          if (mounted) {
            _startVerificationCheck();
          }
        }
      }
    } catch (e) {
      print('Error checking verification: $e');
      if (mounted) {
        _startVerificationCheck();
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      setState(() {
        _isCheckingVerification = true;
      });

      if (_currentUser != null) {
        await _currentUser!.sendEmailVerification();
        print('Verification email resent to ${_currentUser?.email}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification email resent!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error resending verification email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resending email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingVerification = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                // Mail icon
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: const Icon(
                    Icons.mail_outline,
                    size: 80,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 40),
                // Title
                const Text(
                  'Check Your Email',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Description
                Text(
                  'A verification link has been sent to',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Email address
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    widget.email,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 30),
                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber[300]!,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Please follow these steps:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInstructionStep(
                        1,
                        'Check your email inbox',
                      ),
                      const SizedBox(height: 10),
                      _buildInstructionStep(
                        2,
                        'Click the verification link',
                      ),
                      const SizedBox(height: 10),
                      _buildInstructionStep(
                        3,
                        'You\'ll be automatically redirected to the home dashboard',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Resend button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isCheckingVerification
                        ? null
                        : _resendVerificationEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: _isCheckingVerification
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Resend Verification Email',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                // Info text
                Text(
                  'Once verified, the app will automatically redirect you to the home dashboard',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep(int stepNumber, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              '$stepNumber',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
