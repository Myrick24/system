import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Admin Tool to Create Cooperative Staff Accounts
/// Only accessible by admins to create users with cooperative role
class CreateCooperativeAccount extends StatefulWidget {
  const CreateCooperativeAccount({Key? key}) : super(key: key);

  @override
  State<CreateCooperativeAccount> createState() =>
      _CreateCooperativeAccountState();
}

class _CreateCooperativeAccountState extends State<CreateCooperativeAccount> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isAdmin = false;
  String _message = '';
  Color _messageColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isAdmin = false;
        });
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final role = userDoc.data()?['role'] ?? '';
        setState(() {
          _isAdmin = role == 'admin';
        });
      }
    } catch (e) {
      setState(() {
        _isAdmin = false;
      });
    }
  }

  Future<void> _createCooperativeAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      // Note: In a real implementation, you would create this account
      // through Firebase Admin SDK on your backend server for security.
      // This is a simplified version for demonstration.

      // For now, we'll just update an existing user's role
      // In production, use Firebase Admin SDK on backend:
      // 1. Create user with admin.auth().createUser()
      // 2. Set role in Firestore

      setState(() {
        _message = 'To create a cooperative account:\n\n'
            '1. Create a new user account normally (sign up)\n'
            '2. Get the user UID from Firebase Console\n'
            '3. Use the "Assign Cooperative Role" tool below\n\n'
            'OR\n\n'
            'Use Firebase Admin SDK on your backend to create the account securely.';
        _messageColor = Colors.blue;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _message = 'Error: $e';
        _messageColor = Colors.red;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Create Cooperative Account'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Admin Access Required',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Only administrators can create cooperative accounts.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Cooperative Account'),
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.business,
                          size: 60, color: Colors.green.shade700),
                      const SizedBox(height: 12),
                      const Text(
                        'Create Cooperative Staff Account',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This user will have access to the Cooperative Dashboard to manage deliveries and payments.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter full name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Phone Field
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Password Field
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Initial Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  helperText: 'Minimum 6 characters',
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Create Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _createCooperativeAccount,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.add_business),
                label: Text(_isLoading ? 'Processing...' : 'Create Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),

              if (_message.isNotEmpty) ...[
                const SizedBox(height: 24),
                Card(
                  color: _messageColor == Colors.red
                      ? Colors.red.shade50
                      : Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _message,
                      style: TextStyle(color: _messageColor),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              // Assign Role Section
              AssignCooperativeRole(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget to assign cooperative role to existing users
class AssignCooperativeRole extends StatefulWidget {
  const AssignCooperativeRole({Key? key}) : super(key: key);

  @override
  State<AssignCooperativeRole> createState() => _AssignCooperativeRoleState();
}

class _AssignCooperativeRoleState extends State<AssignCooperativeRole> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _userIdController = TextEditingController();

  bool _isProcessing = false;
  String _message = '';
  Color _messageColor = Colors.black;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _assignCooperativeRole() async {
    final userId = _userIdController.text.trim();

    if (userId.isEmpty) {
      setState(() {
        _message = 'Please enter a user ID';
        _messageColor = Colors.red;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _message = '';
    });

    try {
      // Check if user exists
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        setState(() {
          _message = 'User not found. Please check the User ID.';
          _messageColor = Colors.red;
          _isProcessing = false;
        });
        return;
      }

      // Update user role to cooperative
      await _firestore.collection('users').doc(userId).update({
        'role': 'cooperative',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final userData = userDoc.data()!;
      final userName = userData['name'] ?? 'Unknown';
      final userEmail = userData['email'] ?? 'Unknown';

      setState(() {
        _message = 'Success! ✅\n\n'
            'User: $userName\n'
            'Email: $userEmail\n'
            'Role: Cooperative Staff\n\n'
            'This user can now access the Cooperative Dashboard.';
        _messageColor = Colors.green;
        _isProcessing = false;
      });

      _userIdController.clear();
    } catch (e) {
      setState(() {
        _message = 'Error assigning role: $e';
        _messageColor = Colors.red;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Assign Cooperative Role to Existing User',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the User ID (UID) of an existing user to give them cooperative access.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _userIdController,
          decoration: InputDecoration(
            labelText: 'User ID (UID)',
            hintText: 'e.g., abc123XYZ456...',
            prefixIcon: const Icon(Icons.fingerprint),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            helperText: 'Get UID from Firebase Console → Authentication',
          ),
        ),

        const SizedBox(height: 16),

        ElevatedButton.icon(
          onPressed: _isProcessing ? null : _assignCooperativeRole,
          icon: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.assignment_ind),
          label:
              Text(_isProcessing ? 'Assigning...' : 'Assign Cooperative Role'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),

        if (_message.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            color: _messageColor == Colors.red
                ? Colors.red.shade50
                : Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _message,
                style: TextStyle(
                  color: _messageColor == Colors.green
                      ? Colors.green.shade900
                      : Colors.red.shade900,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Instructions Card
        Card(
          color: Colors.amber.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    const Text(
                      'How to Get User ID',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '1. Go to Firebase Console\n'
                  '2. Navigate to Authentication\n'
                  '3. Find the user\n'
                  '4. Copy their User UID\n'
                  '5. Paste it here',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
