import 'package:flutter/material.dart';
import 'screens/guest_main_dashboard.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/cart_service.dart';
import 'services/auth_service.dart';
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
import 'theme/app_theme.dart';

// Create a global singleton instance of CartService that can be accessed from anywhere
final cartService = CartService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait for a minimum splash duration
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    try {
      // Check if user is logged in and get appropriate route
      if (AuthService.isLoggedIn) {
        final homeRoute = await AuthService.getHomeRoute();
        
        switch (homeRoute) {
          case '/admin':
            Navigator.pushReplacementNamed(context, '/admin');
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
