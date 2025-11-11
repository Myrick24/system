import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'cooperative_chat_screen.dart';

/// Screen showing all cooperative chat conversations
/// For cooperative users to manage seller and buyer conversations
class CooperativeMessagesScreen extends StatefulWidget {
  const CooperativeMessagesScreen({Key? key}) : super(key: key);

  @override
  State<CooperativeMessagesScreen> createState() =>
      _CooperativeMessagesScreenState();
}

class _CooperativeMessagesScreenState extends State<CooperativeMessagesScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  TabController? _tabController;
  bool _isLoading = true;
  bool _isCooperative = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkUserRole();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final role = userData['role'] as String?;
          setState(() {
            _isCooperative = role == 'cooperative';
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error checking user role: $e');
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    if (!_isCooperative) {
      // For non-cooperative users, show their single chat
      return Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: _buildUserChatsList(),
      );
    }

    // For cooperative users, show tabs
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooperative Messages'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: Icon(Icons.storefront),
              text: 'Sellers',
            ),
            Tab(
              icon: Icon(Icons.shopping_bag),
              text: 'Buyers',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCooperativeChatsList('seller-cooperative'),
          _buildCooperativeChatsList('buyer-cooperative'),
        ],
      ),
    );
  }

  /// Build chat list for cooperative users
  Widget _buildCooperativeChatsList(String chatType) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please log in to view messages'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('cooperative_chats')
          .where('cooperativeId', isEqualTo: currentUser.uid)
          .where('chatType', isEqualTo: chatType)
          .orderBy('lastMessageTimestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading chats: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }

        final chats = snapshot.data?.docs ?? [];

        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  chatType == 'seller-cooperative'
                      ? Icons.storefront_outlined
                      : Icons.shopping_bag_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  chatType == 'seller-cooperative'
                      ? 'No seller conversations yet'
                      : 'No buyer conversations yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chatDoc = chats[index];
            final chatData = chatDoc.data() as Map<String, dynamic>;
            return _buildChatTile(chatDoc.id, chatData, chatType);
          },
        );
      },
    );
  }

  /// Build chat list for regular users (sellers/buyers)
  Widget _buildUserChatsList() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please log in to view messages'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('cooperative_chats')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('lastMessageTimestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading chats: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }

        final chats = snapshot.data?.docs ?? [];

        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start chatting with your cooperative!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chatDoc = chats[index];
            final chatData = chatDoc.data() as Map<String, dynamic>;
            final chatType = chatData['chatType'] as String;
            return _buildChatTile(chatDoc.id, chatData, chatType);
          },
        );
      },
    );
  }

  Widget _buildChatTile(
      String chatId, Map<String, dynamic> chatData, String chatType) {
    final userName = chatData['userName'] as String? ?? 'User';
    final cooperativeName = chatData['cooperativeName'] as String? ?? 'Cooperative';
    final lastMessage = chatData['lastMessage'] as String? ?? '';
    final timestamp = chatData['lastMessageTimestamp'] as Timestamp?;
    final unreadCount = _isCooperative
        ? (chatData['unreadCooperativeCount'] as int? ?? 0)
        : (chatData['unreadUserCount'] as int? ?? 0);
    final cooperativeId = chatData['cooperativeId'] as String;
    final userId = chatData['userId'] as String;

    final displayName = _isCooperative ? userName : cooperativeName;
    final timeString = timestamp != null
        ? _formatTimestamp(timestamp.toDate())
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: unreadCount > 0 ? 2 : 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          radius: 28,
          child: Icon(
            _isCooperative
                ? (chatType == 'seller-cooperative'
                    ? Icons.storefront
                    : Icons.shopping_bag)
                : Icons.business,
            color: Colors.green.shade700,
            size: 28,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  fontWeight:
                      unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (timeString.isNotEmpty)
              Text(
                timeString,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                style: TextStyle(
                  color: unreadCount > 0
                      ? Colors.black87
                      : Colors.grey.shade600,
                  fontWeight:
                      unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CooperativeChatScreen(
                chatId: chatId,
                otherPartyName: displayName,
                cooperativeId: cooperativeId,
                userId: userId,
                isCooperative: _isCooperative,
                chatType: chatType,
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(date);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(date);
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}
