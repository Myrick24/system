import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../services/paymongo_service.dart';
import 'checkout_screen.dart';

/// PayMongo GCash Payment Screen with Deep Linking
/// 
/// This opens the ACTUAL GCash app on user's phone (like Shopee, Lazada)
/// User completes payment in GCash app, then returns here
class PayMongoGCashScreen extends StatefulWidget {
  final double amount;
  final String orderId;
  final String userId;
  final Map<String, dynamic> orderDetails;

  const PayMongoGCashScreen({
    Key? key,
    required this.amount,
    required this.orderId,
    required this.userId,
    required this.orderDetails,
  }) : super(key: key);

  @override
  State<PayMongoGCashScreen> createState() => _PayMongoGCashScreenState();
}

class _PayMongoGCashScreenState extends State<PayMongoGCashScreen> with WidgetsBindingObserver {
  final PayMongoService _payMongoService = PayMongoService();
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String? _checkoutUrl;
  String? _sourceId;
  bool _paymentInProgress = false;
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePayment();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  // Detect when user returns to app from GCash
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _paymentInProgress) {
      print('App resumed - checking payment status');
      _checkPaymentStatusNow();
    }
  }

  /// Initialize PayMongo payment source
  Future<void> _initializePayment() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      print('Initializing PayMongo GCash payment...');
      
      // Create GCash payment source via PayMongo
      final result = await _payMongoService.createGCashSource(
        amount: widget.amount,
        orderId: widget.orderId,
        userId: widget.userId,
        orderDetails: widget.orderDetails,
      );

      if (result['success'] == true) {
        setState(() {
          _checkoutUrl = result['checkoutUrl'];
          _sourceId = result['sourceId'];
          _isLoading = false;
        });
        
        print('Payment source created: $_sourceId');
        print('Checkout URL: $_checkoutUrl');
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = result['error'] ?? 'Failed to initialize payment';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  /// Open GCash app with payment link
  Future<void> _openGCashApp() async {
    if (_checkoutUrl == null) return;

    setState(() {
      _paymentInProgress = true;
    });

    try {
      final Uri gcashUri = Uri.parse(_checkoutUrl!);
      
      print('Opening GCash app with URL: $_checkoutUrl');
      
      // Try to launch the URL (this will open GCash app if installed)
      final bool launched = await launchUrl(
        gcashUri,
        mode: LaunchMode.externalApplication, // Open in external app (GCash)
      );

      if (launched) {
        print('GCash app opened successfully');
        
        // Start checking payment status periodically
        _startPaymentStatusCheck();
        
        // Show instructions dialog
        if (mounted) {
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              _showPaymentInProgressDialog();
            }
          });
        }
      } else {
        print('Failed to open GCash app');
        setState(() {
          _paymentInProgress = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open GCash app. Please install GCash.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Error opening GCash app: $e');
      setState(() {
        _paymentInProgress = false;
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

  /// Show dialog while payment is in progress
  void _showPaymentInProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Waiting for Payment',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complete your payment in the GCash app.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Instructions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('1. Log in to your GCash account'),
                    Text('2. Review payment details'),
                    Text('3. Confirm payment'),
                    Text('4. Return to this app'),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'We\'ll automatically detect when payment is complete.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _statusCheckTimer?.cancel();
                Navigator.of(context).pop(); // Close dialog
                setState(() {
                  _paymentInProgress = false;
                });
              },
              child: Text('Cancel Payment'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _checkPaymentStatusNow();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('I\'ve Paid'),
            ),
          ],
        ),
      ),
    );
  }

  /// Start checking payment status periodically
  void _startPaymentStatusCheck() {
    // Check every 3 seconds
    _statusCheckTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      await _checkPaymentStatusNow();
    });
  }

  /// Check payment status now
  Future<void> _checkPaymentStatusNow() async {
    if (_sourceId == null) return;

    try {
      print('Checking payment status for source: $_sourceId');
      
      final statusResult = await _payMongoService.checkPaymentStatus(_sourceId!);
      
      if (statusResult['success'] == true) {
        final status = statusResult['status'];
        print('Payment status: $status');
        
        if (status == 'chargeable') {
          // Payment successful!
          _statusCheckTimer?.cancel();
          _handlePaymentSuccess();
        } else if (status == 'cancelled' || status == 'failed') {
          // Payment failed
          _statusCheckTimer?.cancel();
          _handlePaymentFailed(status);
        }
        // If status is still 'pending', keep checking
      }
    } catch (e) {
      print('Error checking payment status: $e');
    }
  }

  /// Handle successful payment
  void _handlePaymentSuccess() {
    _statusCheckTimer?.cancel();
    
    if (!mounted) return;
    
    // Close any open dialogs
    Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/paymongo_gcash');
      
    // Show success dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Payment Successful!',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your GCash payment has been processed successfully!',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount Paid',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '₱${widget.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 8),
                  Divider(),
                  SizedBox(height: 4),
                  Text(
                    'Order ID: ${widget.orderId}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    'Payment Method: GCash',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Your order will be processed shortly.',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(true); // Return to previous screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const CheckoutScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('View Orders'),
          ),
        ],
      ),
    );
  }

  /// Handle failed payment
  void _handlePaymentFailed(String status) {
    _statusCheckTimer?.cancel();
    
    if (!mounted) return;
    
    // Close any open dialogs
    Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/paymongo_gcash');
      
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Payment Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status == 'cancelled'
                  ? 'You cancelled the payment.'
                  : 'Your GCash payment could not be processed.',
            ),
            SizedBox(height: 12),
            Text(
              'Please try again or use a different payment method.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(false); // Return to checkout
            },
            child: Text('Back to Checkout'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              setState(() {
                _paymentInProgress = false;
              });
              _initializePayment(); // Retry
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GCash Payment'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            if (_paymentInProgress) {
              _showCancelConfirmation();
            } else {
              Navigator.of(context).pop(false);
            }
          },
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingView();
    } else if (_hasError) {
      return _buildErrorView();
    } else {
      return _buildReadyView();
    }
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'Preparing GCash Payment...',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 64),
            SizedBox(height: 24),
            Text(
              'Payment Initialization Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _initializePayment,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text('Back to Checkout'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // GCash Logo
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 64,
                  color: Colors.blue,
                ),
                SizedBox(height: 16),
                Text(
                  'GCash Payment',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 24),
          
          // Amount
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Amount to Pay',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '₱${widget.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  widget.orderDetails['productName'] ?? 'Order',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          SizedBox(height: 24),
          
          // Instructions
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'How to Pay',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _buildInstructionStep(
                  '1',
                  'Click "Open GCash" button below',
                ),
                _buildInstructionStep(
                  '2',
                  'GCash app will open automatically',
                ),
                _buildInstructionStep(
                  '3',
                  'Log in to your GCash account',
                ),
                _buildInstructionStep(
                  '4',
                  'Review and confirm payment',
                ),
                _buildInstructionStep(
                  '5',
                  'Return to this app after payment',
                ),
              ],
            ),
          ),
          
          SizedBox(height: 24),
          
          // Open GCash Button
          ElevatedButton(
            onPressed: _paymentInProgress ? null : _openGCashApp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet, size: 28),
                SizedBox(width: 12),
                Text(
                  _paymentInProgress ? 'Payment in Progress...' : 'Open GCash App',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Note
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.yellow.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.yellow.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Make sure GCash app is installed on your phone',
                    style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Payment?'),
        content: Text(
          'Are you sure you want to cancel this payment? Your order will remain unpaid.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
            },
            child: Text('Continue Payment'),
          ),
          ElevatedButton(
            onPressed: () {
              _statusCheckTimer?.cancel();
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(false); // Return to checkout
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
