# Push Notifications Implementation Guide

This document provides a comprehensive guide on how push notifications are implemented in the Harvest App and how to use them effectively.

## Overview

The Harvest App now includes a complete push notification system using Firebase Cloud Messaging (FCM) and Flutter Local Notifications. The system supports:

- Real-time push notifications
- Local notifications when app is in foreground
- Role-based notification targeting
- Topic-based subscriptions
- Customizable notification preferences
- Rich notification content with actions

## Architecture

### Core Components

1. **PushNotificationService** (`lib/services/push_notification_service.dart`)
   - Handles FCM initialization and configuration
   - Manages notification permissions
   - Processes incoming messages
   - Handles background and foreground notifications

2. **NotificationManager** (`lib/services/notification_manager.dart`)
   - Provides high-level methods for sending different types of notifications
   - Handles role-based notification logic
   - Manages topic subscriptions

3. **UI Components**
   - `NotificationListScreen` - Displays user's notifications
   - `NotificationSettingsScreen` - Manages notification preferences
   - `NotificationTestScreen` - Testing and debugging tool

## Features

### Notification Types

1. **Order Updates**
   - Order status changes
   - Delivery confirmations
   - Order cancellations

2. **Product Notifications**
   - New product alerts (for buyers)
   - Product approval/rejection (for farmers)
   - Low stock alerts (for farmers)

3. **Payment Notifications**
   - Payment received confirmations
   - Payment sent confirmations
   - Payment failures

4. **Market Updates**
   - Price changes
   - Market trends
   - Commodity updates

5. **System Notifications**
   - Welcome messages
   - Announcements
   - Reminders
   - Farming tips

### Role-Based Targeting

- **Farmers**: Product approvals, low stock alerts, market updates, farming tips
- **Buyers**: New products, order updates, deals
- **Cooperatives**: Admin updates, member activities
- **All Users**: Announcements, system updates

## Setup Instructions

### 1. Dependencies

The following dependencies are already added to `pubspec.yaml`:

```yaml
dependencies:
  firebase_messaging: ^14.7.10
  flutter_local_notifications: ^16.3.2
```

### 2. Android Configuration

The Android manifest has been updated with necessary permissions:

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

### 3. Firebase Configuration

Ensure your Firebase project has:
- Cloud Messaging enabled
- APNs certificates configured (for iOS)
- Server key available for backend integration

### 4. Initialization

Push notifications are automatically initialized in `main.dart`:

```dart
await PushNotificationService.initialize();
```

## Usage Examples

### Sending Notifications

#### Welcome Notification
```dart
await NotificationManager.sendWelcomeNotification(
  userId: 'user123',
  userName: 'John Doe',
  userRole: 'farmer',
);
```

#### Order Update
```dart
await NotificationManager.sendOrderUpdateNotification(
  userId: 'user123',
  orderId: 'ORDER-456',
  status: 'Delivered',
  customerName: 'Jane Smith',
);
```

#### New Product Alert
```dart
await NotificationManager.sendNewProductNotification(
  productId: 'PROD-789',
  productName: 'Fresh Tomatoes',
  sellerName: 'Green Farm',
  category: 'Vegetables',
);
```

#### Payment Notification
```dart
await NotificationManager.sendPaymentNotification(
  userId: 'user123',
  orderId: 'ORDER-456',
  amount: 25.99,
  isReceived: true,
);
```

### Topic Subscriptions

#### Subscribe to Role-Based Topics
```dart
await NotificationManager.subscribeToRoleBasedTopics('farmer');
```

#### Subscribe to Specific Topics
```dart
await PushNotificationService.subscribeToTopic('market_updates');
await PushNotificationService.subscribeToTopic('new_products');
```

### Managing User Preferences

Users can customize their notification preferences through the settings screen:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => NotificationSettingsScreen(userRole: 'farmer'),
  ),
);
```

## Testing

Use the `NotificationTestScreen` to test different notification types:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const NotificationTestScreen(),
  ),
);
```

## Integration Points

### Authentication Flow

When users sign up or log in, subscribe them to relevant topics:

```dart
// After successful authentication
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  await NotificationManager.subscribeToRoleBasedTopics(userRole);
  
  // Send welcome notification for new users
  await NotificationManager.sendWelcomeNotification(
    userId: user.uid,
    userName: user.displayName ?? 'User',
    userRole: userRole,
  );
}
```

### Order Management

Integrate with your order system to send updates:

```dart
// When order status changes
await NotificationManager.sendOrderUpdateNotification(
  userId: order.buyerId,
  orderId: order.id,
  status: newStatus,
);
```

### Product Management

Notify relevant users about product changes:

```dart
// When product is approved
await NotificationManager.sendProductApprovalNotification(
  sellerId: product.sellerId,
  productName: product.name,
  isApproved: true,
);

// When new product is added
await NotificationManager.sendNewProductNotification(
  productId: product.id,
  productName: product.name,
  sellerName: seller.name,
  category: product.category,
);
```

## Best Practices

1. **Permission Handling**
   - Always check notification permissions before sending
   - Gracefully handle permission denials
   - Provide clear explanations for why notifications are needed

2. **Message Content**
   - Keep titles concise and descriptive
   - Include relevant action items in the message
   - Use consistent formatting across notification types

3. **Frequency Management**
   - Respect user preferences
   - Avoid sending too many notifications
   - Group related notifications when possible

4. **Performance**
   - Use batching for multiple notifications
   - Handle background processing efficiently
   - Clean up old notifications regularly

## Troubleshooting

### Common Issues

1. **Notifications not received**
   - Check Firebase configuration
   - Verify FCM token is saved correctly
   - Ensure app has notification permissions

2. **Background notifications not working**
   - Verify background message handler is configured
   - Check device battery optimization settings
   - Ensure proper Android service configuration

3. **iOS notifications not working**
   - Verify APNs certificates are configured
   - Check iOS notification permissions
   - Ensure proper iOS configuration

### Debug Tools

1. Use `NotificationTestScreen` to test different scenarios
2. Check FCM token in notification settings
3. Monitor Firebase Console for delivery status
4. Use device logs to debug notification issues

## Security Considerations

1. **Token Management**
   - Securely store FCM tokens
   - Refresh tokens when they expire
   - Remove tokens when users log out

2. **Message Validation**
   - Validate notification content server-side
   - Sanitize user-generated content
   - Implement rate limiting

3. **Privacy**
   - Respect user privacy preferences
   - Allow users to opt-out of notifications
   - Handle sensitive information appropriately

## Future Enhancements

1. **Rich Notifications**
   - Add images and action buttons
   - Implement notification grouping
   - Support for custom sounds

2. **Analytics**
   - Track notification delivery rates
   - Monitor user engagement
   - A/B test notification content

3. **Advanced Targeting**
   - Location-based notifications
   - Behavioral targeting
   - Personalized content

## Server-Side Implementation

For production use, you'll need a backend service to send notifications using Firebase Admin SDK:

```javascript
// Example Node.js implementation
const admin = require('firebase-admin');

async function sendNotification(token, title, body, data) {
  const message = {
    token: token,
    notification: {
      title: title,
      body: body,
    },
    data: data,
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('Successfully sent message:', response);
  } catch (error) {
    console.log('Error sending message:', error);
  }
}
```

This completes the push notification implementation for the Harvest App. The system is now ready for production use with proper testing and server-side integration.
