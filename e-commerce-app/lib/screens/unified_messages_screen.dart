import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'messages_screen.dart';

/// Unified Messages Screen that shows different tabs based on user role
/// - Buyer: Shows Cooperative and Seller tabs
/// - Seller: Shows Cooperative and Buyer tabs
/// - Cooperative: Shows Buyer and Seller tabs
class UnifiedMessagesScreen extends StatefulWidget {
  const UnifiedMessagesScreen({Key? key}) : super(key: key);

  @override
  State<UnifiedMessagesScreen> createState() => _UnifiedMessagesScreenState();
}

class _UnifiedMessagesScreenState extends State<UnifiedMessagesScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  String _userRole = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserRole();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userRole = userData['role'] ?? 'buyer';
            _isLoading = false;
          });
        } else {
          setState(() {
            _userRole = 'buyer';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user role: $e');
      setState(() {
        _userRole = 'buyer';
        _isLoading = false;
      });
    }
  }

  List<Tab> _getTabs() {
    if (_userRole == 'buyer') {
      return const [
        Tab(icon: Icon(Icons.store), text: 'Cooperative'),
        Tab(icon: Icon(Icons.person), text: 'Seller'),
      ];
    } else if (_userRole == 'seller') {
      return const [
        Tab(icon: Icon(Icons.store), text: 'Cooperative'),
        Tab(icon: Icon(Icons.shopping_bag), text: 'Buyer'),
      ];
    } else if (_userRole == 'cooperative') {
      return const [
        Tab(icon: Icon(Icons.shopping_bag), text: 'Buyer'),
        Tab(icon: Icon(Icons.person), text: 'Seller'),
      ];
    } else {
      // Default to buyer view
      return const [
        Tab(icon: Icon(Icons.store), text: 'Cooperative'),
        Tab(icon: Icon(Icons.person), text: 'Seller'),
      ];
    }
  }

  List<Widget> _getTabViews() {
    if (_userRole == 'buyer') {
      return [
        _buildBuyerCooperativeTab(),
        const MessagesScreen(), // Buyer-Seller messages
      ];
    } else if (_userRole == 'seller') {
      return [
        _buildSellerCooperativeTab(),
        const MessagesScreen(), // Seller-Buyer messages
      ];
    } else if (_userRole == 'cooperative') {
      return [
        _buildCooperativeBuyerTab(),
        _buildCooperativeSellerTab(),
      ];
    } else {
      // Default to buyer view
      return [
        _buildBuyerCooperativeTab(),
        const MessagesScreen(),
      ];
    }
  }

  Widget _buildBuyerCooperativeTab() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Please log in to view messages'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('cooperative_chats')
          .where('userId', isEqualTo: userId)
          .where('chatType', isEqualTo: 'buyer-cooperative')
          .orderBy('lastMessageTimestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No cooperative messages yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final chatDoc = snapshot.data!.docs[index];
            final chatData = chatDoc.data() as Map<String, dynamic>;
            final cooperativeName =
                chatData['cooperativeName'] ?? 'Cooperative';
            final lastMessage = chatData['lastMessage'] ?? '';
            final unreadCount = chatData['unreadUserCount'] ?? 0;

            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.store, color: Colors.white),
              ),
              title: Text(cooperativeName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: unreadCount > 0
                  ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadCount',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    )
                  : null,
              onTap: () {
                // Navigate to cooperative chat
                Navigator.pushNamed(
                  context,
                  '/cooperative_chat',
                  arguments: {
                    'chatId': chatDoc.id,
                    'cooperativeName': cooperativeName,
                    'cooperativeId': chatData['cooperativeId'],
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSellerCooperativeTab() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Please log in to view messages'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('cooperative_chats')
          .where('userId', isEqualTo: userId)
          .where('chatType', isEqualTo: 'seller-cooperative')
          .orderBy('lastMessageTimestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No cooperative messages yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final chatDoc = snapshot.data!.docs[index];
            final chatData = chatDoc.data() as Map<String, dynamic>;
            final cooperativeName =
                chatData['cooperativeName'] ?? 'Cooperative';
            final lastMessage = chatData['lastMessage'] ?? '';
            final unreadCount = chatData['unreadUserCount'] ?? 0;

            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.store, color: Colors.white),
              ),
              title: Text(cooperativeName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: unreadCount > 0
                  ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadCount',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    )
                  : null,
              onTap: () {
                // Navigate to cooperative chat
                Navigator.pushNamed(
                  context,
                  '/cooperative_chat',
                  arguments: {
                    'chatId': chatDoc.id,
                    'cooperativeName': cooperativeName,
                    'cooperativeId': chatData['cooperativeId'],
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCooperativeBuyerTab() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Please log in to view messages'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('cooperative_chats')
          .where('cooperativeId', isEqualTo: userId)
          .where('chatType', isEqualTo: 'buyer-cooperative')
          .orderBy('lastMessageTimestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No buyer messages yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final chatDoc = snapshot.data!.docs[index];
            final chatData = chatDoc.data() as Map<String, dynamic>;
            final userName = chatData['userName'] ?? 'Buyer';
            final lastMessage = chatData['lastMessage'] ?? '';
            final unreadCount = chatData['unreadCooperativeCount'] ?? 0;

            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.shopping_bag, color: Colors.white),
              ),
              title: Text(userName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: unreadCount > 0
                  ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadCount',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    )
                  : null,
              onTap: () {
                // Navigate to cooperative chat
                Navigator.pushNamed(
                  context,
                  '/cooperative_chat',
                  arguments: {
                    'chatId': chatDoc.id,
                    'userName': userName,
                    'userId': chatData['userId'],
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCooperativeSellerTab() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Please log in to view messages'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('cooperative_chats')
          .where('cooperativeId', isEqualTo: userId)
          .where('chatType', isEqualTo: 'seller-cooperative')
          .orderBy('lastMessageTimestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No seller messages yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final chatDoc = snapshot.data!.docs[index];
            final chatData = chatDoc.data() as Map<String, dynamic>;
            final userName = chatData['userName'] ?? 'Seller';
            final lastMessage = chatData['lastMessage'] ?? '';
            final unreadCount = chatData['unreadCooperativeCount'] ?? 0;

            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(userName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: unreadCount > 0
                  ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadCount',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    )
                  : null,
              onTap: () {
                // Navigate to cooperative chat
                Navigator.pushNamed(
                  context,
                  '/cooperative_chat',
                  arguments: {
                    'chatId': chatDoc.id,
                    'userName': userName,
                    'userId': chatData['userId'],
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _getTabs(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _getTabViews(),
      ),
    );
  }
}
