# Real System Notifications Guide

## Overview
This guide explains how to test and verify real Android system notifications that appear as floating popups and in the notification tray, even when the app is in the background or closed.

## What Are Real System Notifications?

Real system notifications are:
- **Floating popups** that appear at the top of the screen temporarily
- **Persistent entries** in the Android notification tray/panel
- **Visible even when the app is closed** or in the background
- **Interactive** - users can tap them to open the app
- **System-managed** - controlled by Android's notification system

## How to Test System Notifications

### Method 1: Direct System Notification Button
1. Open the app
2. On the splash screen, tap **"Test System Notification"** (orange button)
3. **Immediately press the home button** or switch to another app
4. You should see a floating notification popup appear
5. Check your notification tray by swiping down from the top

### Method 2: Notification Test Screen
1. Open the app
2. Tap "Test Notifications" button
3. In the test screen, tap **"Direct System Notification"**
4. **Immediately minimize the app or switch to another app**
5. You should see the notification popup

### Method 3: Background Testing
1. Open the app and trigger any test notification
2. **Put the app in background** (home button)
3. **Wait for the notification to appear**
4. **Close the app completely** (recent apps → swipe up)
5. Trigger another notification (if you have a way to send from outside)

## What You Should See

### ✅ Correct Behavior (Real System Notifications):
- **Floating popup** appears at top of screen for 3-5 seconds
- **Notification sound** plays (if enabled)
- **Vibration** occurs (if enabled)
- **LED light** blinks (on supported devices)
- **Notification appears in tray** when you swipe down
- **Notification shows even when app is closed/backgrounded**
- **Badge count** updates on app icon (on supported launchers)

### ❌ Wrong Behavior (In-App Notifications):
- Notification only shows inside the app
- No floating popup when app is backgrounded
- Nothing appears in notification tray
- No notification when app is closed

## Testing Scenarios

### Scenario 1: App in Foreground
1. Open app
2. Trigger notification
3. **Expected**: Floating popup appears immediately

### Scenario 2: App in Background
1. Open app
2. Press home button (app goes to background)
3. Trigger notification (from test screen timer or external)
4. **Expected**: Floating popup appears over current screen

### Scenario 3: App Completely Closed
1. Open app
2. Close app completely (recent apps → swipe up)
3. Trigger notification (if possible from external source)
4. **Expected**: Floating popup appears

## Troubleshooting

### If notifications don't appear as floating popups:

1. **Check notification permissions**:
   - Go to Android Settings → Apps → Harvest App → Notifications
   - Ensure "Show notifications" is enabled
   - Ensure "Pop on screen" or "Alert style" is set to "Pop up"

2. **Check Do Not Disturb**:
   - Ensure Do Not Disturb is disabled
   - Or add Harvest App to DND exceptions

3. **Check notification channel settings**:
   - In app notification settings
   - Ensure "Harvest App Notifications" channel has highest importance

4. **Device-specific issues**:
   - Some devices (Samsung, Xiaomi, etc.) have aggressive battery optimization
   - Go to Settings → Battery → App optimization → Harvest App → Don't optimize

### If notifications only show in app:

This means the notification is being displayed as an in-app notification instead of a system notification. Check:

1. **Code implementation**: Ensure using `flutter_local_notifications` correctly
2. **Channel importance**: Must be `Importance.max` for floating popups
3. **Android permissions**: Check AndroidManifest.xml has all required permissions

## Configuration Details

### Current Implementation:
- **Channel ID**: `harvest_app_channel`
- **Importance**: `Importance.max` (for floating popups)
- **Priority**: `Priority.max` 
- **Features**: Sound, vibration, LED lights, auto-cancel
- **Permissions**: Full screen intent, system alert window

### Key Android Permissions:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

## Verification Checklist

- [ ] Floating popup appears when app is in foreground
- [ ] Floating popup appears when app is in background
- [ ] Notification appears in notification tray
- [ ] Notification sound plays
- [ ] Device vibrates
- [ ] LED light blinks (if device supports it)
- [ ] Notification is dismissible by swiping
- [ ] Tapping notification opens the app
- [ ] Multiple notifications stack properly
- [ ] Badge count updates on app icon

## Next Steps

If system notifications are working correctly:
1. ✅ Test all notification types (order updates, product alerts, etc.)
2. ✅ Verify role-based notifications work
3. ✅ Test Firebase Cloud Messaging integration
4. ✅ Test background/terminated app notification delivery
5. ✅ Add server-side FCM sending capabilities (optional)

If notifications are still not working as expected, please provide:
- Device model and Android version
- Screenshot of notification settings
- Description of what you see vs. what you expect
- Console logs when triggering notifications

## Important Notes

- **Real system notifications require proper Android permissions**
- **Channel importance must be maximum for floating popups**
- **Some devices have aggressive battery optimization that can block notifications**
- **Notifications work differently in debug vs release builds**
- **FCM requires proper Firebase project setup for production**
