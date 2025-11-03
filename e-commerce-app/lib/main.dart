import 'package:flutter/material.dart';
import 'screens/guest_main_dashboard.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/cart_service.dart';
import 'services/auth_service.dart';
import 'services/realtime_notification_service.dart'; // Import realtime notifications
import 'tools/admin_setup.dart'; // Import admin setup tool
import 'tools/sample_data_tool.dart'; // Import sample data tool
import 'tools/restore_admin.dart'; // Import restore admin tool
import 'screens/seller/seller_product_dashboard.dart';
import 'screens/seller/seller_main_dashboard.dart';
import 'screens/seller/add_product_screen.dart';
import 'screens/seller/notifications_screen.dart';
import 'screens/buyer/buyer_main_dashboard.dart';
import 'screens/buyer/buyer_product_browse.dart';
import 'screens/notification_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/unified_main_dashboard.dart';
import 'screens/cooperative/coop_dashboard.dart';
import 'theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

// Create a global singleton instance of CartService that can be accessed from anywhere
final cartService = CartService();

// Create a global navigatorKey for handling deep links
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize real-time push notifications
  await RealtimeNotificationService.initialize();
  print('✅ Real-time push notifications initialized');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Move the MultiProvider inside the build method of MyApp
    // This ensures all screens that are pushed on the navigator have access to the provider
    return MultiProvider(
      providers: [
        // Using the existing singleton instance
        ChangeNotifierProvider.value(value: cartService),
      ],
      child: MaterialApp(
        title: 'Harvest App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorKey: navigatorKey,
        routes: {
          '/admin-setup': (context) => const AdminSetupTool(),
          '/sample-data': (context) => const SampleDataTool(),
          '/restore-admin': (context) => const RestoreAdminTool(),
          '/seller-dashboard': (context) => const SellerProductDashboard(),
          '/seller-main-dashboard': (context) => const SellerMainDashboard(),
          '/add-product': (context) => const AddProductScreen(),
          '/buyer-main-dashboard': (context) => const BuyerMainDashboard(),
          '/buyer-browse': (context) => const BuyerProductBrowse(),
          '/notifications': (context) => const NotificationScreen(),
          '/seller-notifications': (context) => const NotificationsScreen(),
          '/guest': (context) => const GuestMainDashboard(),
          '/unified': (context) => const UnifiedMainDashboard(),
          '/admin': (context) => const AdminDashboard(),
          '/coop': (context) => const CoopDashboard(),
          '/home': (context) => const _HomeRouteScreen(),
        },
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _verificationCheckTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    // Periodically check for email verification status in case verification happens externally
    _startVerificationCheckTimer();
  }

  void _startVerificationCheckTimer() {
    // Check every 2 seconds if email got verified (helpful when link is clicked in browser)
    _verificationCheckTimer =
        Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await currentUser.reload();

          // If email becomes verified, navigate to home
          if (FirebaseAuth.instance.currentUser?.emailVerified ?? false) {
            print('✅ Email verification detected! Navigating to home...');
            if (mounted) {
              _verificationCheckTimer?.cancel();
              navigatorKey.currentState?.pushReplacementNamed('/home');
            }
            return;
          }
        }
      } catch (e) {
        print('Error checking verification status: $e');
      }
    });
  }

  @override
  void dispose() {
    _verificationCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Wait for a minimum splash duration
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      // Check if there's a current user and if they just verified their email
      final currentUser = FirebaseAuth.instance.currentUser;

      // Refresh user to get the latest verification status
      if (currentUser != null) {
        await currentUser.reload();
        final refreshedUser = FirebaseAuth.instance.currentUser;

        // If user is logged in and their email is verified, they likely clicked the verification link
        if (refreshedUser?.emailVerified ?? false) {
          print('📧 Email verified! Showing verification pending screen...');
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/home',
            );
          }
          return;
        }
      }

      // Check if user is logged in and get appropriate route
      if (AuthService.isLoggedIn) {
        final homeRoute = await AuthService.getHomeRoute();

        switch (homeRoute) {
          case '/admin':
            Navigator.pushReplacementNamed(context, '/admin');
            break;
          case '/coop':
            Navigator.pushReplacementNamed(context, '/coop');
            break;
          case '/unified':
            Navigator.pushReplacementNamed(context, '/unified');
            break;
          default:
            Navigator.pushReplacementNamed(context, '/guest');
        }
      } else {
        // User not logged in, go to guest screen
        Navigator.pushReplacementNamed(context, '/guest');
      }
    } catch (e) {
      print('Error during app initialization: $e');
      // Fallback to guest screen on error
      Navigator.pushReplacementNamed(context, '/guest');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo with larger size
            Image.asset(
              'lib/assests/images/icon.png',
              width: 180,
              height: 180,
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper screen to determine which home screen to navigate to based on user role
class _HomeRouteScreen extends StatefulWidget {
  const _HomeRouteScreen({Key? key}) : super(key: key);

  @override
  State<_HomeRouteScreen> createState() => _HomeRouteScreenState();
}

class _HomeRouteScreenState extends State<_HomeRouteScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToAppropriateHome();
  }

  Future<void> _navigateToAppropriateHome() async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    try {
      final homeRoute = await AuthService.getHomeRoute();

      if (mounted) {
        Navigator.pushReplacementNamed(context, homeRoute);
      }
    } catch (e) {
      print('Error determining home route: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/guest');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'lib/assests/images/icon.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
