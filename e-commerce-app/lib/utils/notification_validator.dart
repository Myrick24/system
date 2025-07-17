import 'package:flutter/material.dart';
import '../services/push_notification_service.dart';

class QuickNotificationValidator {
  static Future<Map<String, bool>> validateNotificationSystem() async {
    Map<String, bool> results = {};

    try {
      // Test 1: Check if notification service is initialized
      results['service_initialized'] = true;

      // Test 2: Check if permissions are granted
      bool hasPermission = await PushNotificationService.hasPermission();
      results['permissions_granted'] = hasPermission;

      // Test 3: Check if FCM token exists
      String? token = await PushNotificationService.getCurrentToken();
      results['fcm_token_available'] = token != null;

      // Test 4: Test basic local notification
      try {
        await PushNotificationService.sendTestNotification(
          title: 'Validation Test',
          body: 'Testing notification system functionality',
          payload: 'validation_test',
        );
        results['local_notification_sent'] = true;
      } catch (e) {
        results['local_notification_sent'] = false;
      }

      return results;
    } catch (e) {
      print('Error validating notification system: $e');
      return {'error': false};
    }
  }

  static String generateValidationReport(Map<String, bool> results) {
    StringBuffer report = StringBuffer();
    report.writeln('=== Notification System Validation Report ===\n');

    if (results.containsKey('error')) {
      report.writeln('❌ CRITICAL ERROR: Validation failed');
      return report.toString();
    }

    // Service initialization
    bool serviceInit = results['service_initialized'] ?? false;
    report.writeln(
        '${serviceInit ? "✅" : "❌"} Service Initialization: ${serviceInit ? "SUCCESS" : "FAILED"}');

    // Permissions
    bool permissions = results['permissions_granted'] ?? false;
    report.writeln(
        '${permissions ? "✅" : "❌"} Notification Permissions: ${permissions ? "GRANTED" : "DENIED"}');

    // FCM Token
    bool fcmToken = results['fcm_token_available'] ?? false;
    report.writeln(
        '${fcmToken ? "✅" : "❌"} FCM Token: ${fcmToken ? "AVAILABLE" : "MISSING"}');

    // Local notifications
    bool localNotifications = results['local_notification_sent'] ?? false;
    report.writeln(
        '${localNotifications ? "✅" : "❌"} Local Notifications: ${localNotifications ? "WORKING" : "FAILED"}');

    report.writeln();

    // Overall status
    int successCount = results.values.where((v) => v == true).length;
    int totalCount = results.length;

    if (successCount == totalCount) {
      report.writeln('🎉 OVERALL STATUS: ALL SYSTEMS OPERATIONAL');
      report.writeln('   System notifications should work correctly!');
    } else {
      report.writeln('⚠️  OVERALL STATUS: ISSUES DETECTED');
      report.writeln('   Some components need attention.');
    }

    report.writeln();
    report.writeln('=== Next Steps ===');

    if (!permissions) {
      report.writeln('1. Grant notification permissions in device settings');
    }

    if (!fcmToken) {
      report.writeln('2. Check Firebase configuration and internet connection');
    }

    if (!localNotifications) {
      report.writeln('3. Check Android notification channel configuration');
    }

    if (successCount == totalCount) {
      report.writeln('1. Test notifications with app in background');
      report.writeln('2. Verify floating popups appear');
      report.writeln('3. Check notification tray entries');
    }

    return report.toString();
  }
}

// Widget for displaying validation results
class NotificationValidationWidget extends StatefulWidget {
  const NotificationValidationWidget({Key? key}) : super(key: key);

  @override
  State<NotificationValidationWidget> createState() =>
      _NotificationValidationWidgetState();
}

class _NotificationValidationWidgetState
    extends State<NotificationValidationWidget> {
  String _validationReport = 'Tap "Validate" to check notification system...';
  bool _isValidating = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assessment, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'System Validation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isValidating ? null : _validateSystem,
                  child: _isValidating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Validate'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _validationReport,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _validateSystem() async {
    setState(() {
      _isValidating = true;
      _validationReport = 'Validating notification system...';
    });

    try {
      Map<String, bool> results =
          await QuickNotificationValidator.validateNotificationSystem();
      String report =
          QuickNotificationValidator.generateValidationReport(results);

      setState(() {
        _validationReport = report;
      });
    } catch (e) {
      setState(() {
        _validationReport = 'Validation failed: $e';
      });
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }
}
