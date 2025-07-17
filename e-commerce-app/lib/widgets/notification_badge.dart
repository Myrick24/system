import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationBadge extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final int? count; // Manual count override

  const NotificationBadge({
    Key? key,
    required this.child,
    this.onTap,
    this.count,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If manual count is provided, use static badge
    if (count != null) {
      return _buildStaticBadge();
    }

    // Otherwise, use dynamic badge
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return GestureDetector(
        onTap: onTap,
        child: child,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.docs.length ?? 0;
        return _buildBadgeWithCount(unreadCount);
      },
    );
  }

  Widget _buildStaticBadge() {
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: child,
        ),
        if (count! > 0)
          Positioned(
            right: 0,
            top: 0,
            child: _buildBadgeContainer(count!),
          ),
      ],
    );
  }

  Widget _buildBadgeWithCount(int unreadCount) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: child,
        ),
        if (unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: _buildBadgeContainer(unreadCount),
          ),
      ],
    );
  }

  Widget _buildBadgeContainer(int badgeCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      constraints: const BoxConstraints(
        minWidth: 20,
        minHeight: 20,
      ),
      child: Text(
        badgeCount > 99 ? '99+' : badgeCount.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
