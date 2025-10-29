import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSupportScreen extends StatefulWidget {
  const ChatSupportScreen({Key? key}) : super(key: key);

  @override
  State<ChatSupportScreen> createState() => _ChatSupportScreenState();
}

class _ChatSupportScreenState extends State<ChatSupportScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  
  String? _chatSessionId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeChatSession();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChatSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Check if user has an active chat session
      final existingSession = await _firestore
          .collection('chat_sessions')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (existingSession.docs.isNotEmpty) {
        setState(() {
          _chatSessionId = existingSession.docs.first.id;
          _isLoading = false;
        });
      } else {
        // Create new chat session
        final userData = await _firestore.collection('users').doc(user.uid).get();
        final userName = userData.data()?['name'] ?? 'User';
        
        final newSession = await _firestore.collection('chat_sessions').add({
          'userId': user.uid,
          'userName': userName,
          'userEmail': user.email,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageAt': FieldValue.serverTimestamp(),
        });

        // Send welcome message
        await _firestore
            .collection('chat_sessions')
            .doc(newSession.id)
            .collection('messages')
            .add({
          'text': 'Hello! Welcome to AgriMart Support. How can we help you today?',
          'senderId': 'system',
          'senderName': 'Support Bot',
          'timestamp': FieldValue.serverTimestamp(),
          'isSupport': true,
        });

        setState(() {
          _chatSessionId = newSession.id;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error initializing chat: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatSessionId == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userData = await _firestore.collection('users').doc(user.uid).get();
      final userName = userData.data()?['name'] ?? 'User';

      // Send message
      await _firestore
          .collection('chat_sessions')
          .doc(_chatSessionId)
          .collection('messages')
          .add({
        'text': text,
        'senderId': user.uid,
        'senderName': userName,
        'timestamp': FieldValue.serverTimestamp(),
        'isSupport': false,
      });

      // Update session
      await _firestore.collection('chat_sessions').doc(_chatSessionId).update({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': text,
      });

      _messageController.clear();

      // Auto-scroll to bottom
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      // Send auto-reply after 1 second (simulating support response)
      Future.delayed(const Duration(seconds: 1), () {
        _sendAutoReply(text);
      });
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendAutoReply(String userMessage) async {
    if (_chatSessionId == null) return;

    String reply = _generateAutoReply(userMessage.toLowerCase());

    try {
      await _firestore
          .collection('chat_sessions')
          .doc(_chatSessionId)
          .collection('messages')
          .add({
        'text': reply,
        'senderId': 'support',
        'senderName': 'Support Agent',
        'timestamp': FieldValue.serverTimestamp(),
        'isSupport': true,
      });

      // Auto-scroll to bottom
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Error sending auto-reply: $e');
    }
  }

  String _generateAutoReply(String message) {
    // Simple keyword-based auto-reply system
    if (message.contains('order') || message.contains('delivery')) {
      return 'For order and delivery inquiries, you can track your orders in the "My Orders" section. If you need specific help with an order, please provide your order ID.';
    } else if (message.contains('payment') || message.contains('refund')) {
      return 'For payment and refund issues, please note that we process refunds within 3-5 business days. If you need immediate assistance, please provide your transaction details.';
    } else if (message.contains('seller') || message.contains('register')) {
      return 'To become a seller, go to the Account tab and click "Become a Seller". The approval process takes 1-3 business days. Do you need help with the registration process?';
    } else if (message.contains('account') || message.contains('login') || message.contains('password')) {
      return 'For account-related issues, you can reset your password on the login screen. If you need further assistance, please describe your specific problem.';
    } else {
      return 'Thank you for your message. A support agent will respond to you shortly. In the meantime, you can check our FAQ section for quick answers to common questions.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Live Chat'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      );
    }

    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Live Chat'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Please login to use live chat'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Chat'),
            Text(
              'Support Team',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showChatOptions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _chatSessionId == null
                ? const Center(child: Text('Failed to initialize chat'))
                : StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('chat_sessions')
                        .doc(_chatSessionId)
                        .collection('messages')
                        .orderBy('timestamp', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final messages = snapshot.data!.docs;

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final messageData = messages[index].data() as Map<String, dynamic>;
                          final isSupport = messageData['isSupport'] ?? false;
                          final text = messageData['text'] ?? '';
                          final senderName = messageData['senderName'] ?? 'Unknown';
                          final timestamp = messageData['timestamp'] as Timestamp?;

                          return _buildMessageBubble(
                            text: text,
                            isSupport: isSupport,
                            senderName: senderName,
                            timestamp: timestamp,
                          );
                        },
                      );
                    },
                  ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isSupport,
    required String senderName,
    Timestamp? timestamp,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isSupport ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSupport) ...[
            CircleAvatar(
              backgroundColor: Colors.green.shade100,
              child: Icon(Icons.support_agent, color: Colors.green.shade700, size: 20),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isSupport ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSupport ? Colors.grey.shade200 : Colors.green,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isSupport ? 4 : 16),
                      bottomRight: Radius.circular(isSupport ? 16 : 4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isSupport)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            senderName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      Text(
                        text,
                        style: TextStyle(
                          color: isSupport ? Colors.black : Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (timestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                    child: Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!isSupport) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Icon(Icons.person, color: Colors.blue.shade700, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.close, color: Colors.red),
                title: const Text('End Chat'),
                onTap: () {
                  Navigator.pop(context);
                  _endChat();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _endChat() async {
    if (_chatSessionId == null) return;

    try {
      await _firestore.collection('chat_sessions').doc(_chatSessionId).update({
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error ending chat: $e');
    }
  }
}
