import 'package:flutter/material.dart';
import '../services/realtime_notification_service.dart';

/// Badge widget that shows unread notification count in real-time
class RealtimeNotificationBadge extends StatelessWidget {
  final Widget child;
  final Color? badgeColor;
  final Color? textColor;

  const RealtimeNotificationBadge({
    Key? key,
    required this.child,
    this.badgeColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: RealtimeNotificationService.unreadCountStream,
      initialData: 0,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        if (count == 0) {
          return child;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: badgeColor ?? Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Center(
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Floating notification banner that appears when new notifications arrive
class RealtimeNotificationBanner extends StatefulWidget {
  const RealtimeNotificationBanner({Key? key}) : super(key: key);

  @override
  State<RealtimeNotificationBanner> createState() =>
      _RealtimeNotificationBannerState();
}

class _RealtimeNotificationBannerState
    extends State<RealtimeNotificationBanner>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  AnimationController? _animationController;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _listenToNotifications();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeOut,
    ));
  }

  void _listenToNotifications() {
    RealtimeNotificationService.notificationStream.listen((notification) {
      _showNotificationBanner(notification);
    });
  }

  void _showNotificationBanner(Map<String, dynamic> notification) {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: SlideTransition(
          position: _slideAnimation!,
          child: Material(
            color: Colors.transparent,
            child: _NotificationCard(
              title: notification['title'] ?? 'New Notification',
              message: notification['body'] ?? '',
              onTap: () {
                _removeOverlay();
                // Handle tap - navigate to notifications screen
              },
              onDismiss: _removeOverlay,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animationController!.forward();

    // Auto dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      _removeOverlay();
    });
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _animationController!.reverse().then((_) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      });
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _NotificationCard extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.title,
    required this.message,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Snackbar-style notification at the bottom
class RealtimeNotificationSnackbar {
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.notifications_active,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: onTap != null
            ? SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: onTap,
              )
            : null,
      ),
    );
  }
}
