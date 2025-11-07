import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Quick function to create an admin account directly
/// Call this function once from your main app initialization
/// 
/// Usage:
/// await createAdminAccountQuick(
///   email: 'admin@ecommerce.com',
///   password: 'Admin@123456',
///   name: 'System Admin',
/// );

Future<bool> createAdminAccountQuick({
  required String email,
  required String password,
  required String name,
}) async {
  try {
    print('Creating admin account...');
    
    // 1. Create Firebase Authentication user
    final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    print('Auth user created with UID: ${userCredential.user!.uid}');

    // 2. Create admin document in Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userCredential.user!.uid)
        .set({
      'role': 'admin',
      'name': name.trim(),
      'email': email.trim(),
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'fullName': name.trim(),
    });

    print('Admin document created in Firestore');
    print('✅ Admin account created successfully!');
    print('UID: ${userCredential.user!.uid}');
    print('Email: $email');
    print('Password: $password');
    print('Name: $name');
    
    return true;
  } catch (e) {
    print('❌ Error creating admin account: $e');
    return false;
  }
}

/// Alternative: Add admin role to existing user
Future<bool> addAdminRoleToUser(String userId) async {
  try {
    print('Adding admin role to user: $userId');
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({
      'role': 'admin',
      'status': 'active',
    });

    print('✅ Admin role added successfully!');
    return true;
  } catch (e) {
    print('❌ Error adding admin role: $e');
    return false;
  }
}

/// Check if user is admin
Future<bool> checkIfUserIsAdmin(String userId) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (doc.exists) {
      final role = doc.data()?['role'] ?? '';
      print('User role: $role');
      return role == 'admin';
    }
    return false;
  } catch (e) {
    print('Error checking admin status: $e');
    return false;
  }
}

/// Get all admin accounts
Future<List<Map<String, dynamic>>> getAllAdmins() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    List<Map<String, dynamic>> admins = [];
    for (var doc in snapshot.docs) {
      admins.add({
        'uid': doc.id,
        ...doc.data(),
      });
    }

    print('Found ${admins.length} admin accounts');
    return admins;
  } catch (e) {
    print('Error fetching admins: $e');
    return [];
  }
}

/// Example: How to use in main.dart or initialization
/// 
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   
///   // Initialize Firebase
///   await Firebase.initializeApp();
///   
///   // Create admin account (run only once)
///   // Uncomment to create admin
///   // await createAdminAccountQuick(
///   //   email: 'admin@ecommerce.com',
///   //   password: 'Admin@123456',
///   //   name: 'System Admin',
///   // );
///   
///   runApp(const MyApp());
/// }
