import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Screen for chatting with cooperatives
/// Supports both Seller → Cooperative and Buyer → Cooperative conversations
class CooperativeChatScreen extends StatefulWidget {
  final String chatId;
  final String otherPartyName; // Cooperative name or user name
  final String cooperativeId;
  final String userId; // Current user (seller or buyer)
  final bool
      isCooperative; // true if current user is cooperative, false if seller/buyer
  final String chatType; // 'seller-cooperative' or 'buyer-cooperative'

  const CooperativeChatScreen({
    Key? key,
    required this.chatId,
    required this.otherPartyName,
    required this.cooperativeId,
    required this.userId,
    required this.isCooperative,
    required this.chatType,
  }) : super(key: key);

  @override
  State<CooperativeChatScreen> createState() => _CooperativeChatScreenState();
}

class _CooperativeChatScreenState extends State<CooperativeChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final chatDoc = await _firestore
          .collection('cooperative_chats')
          .doc(widget.chatId)
          .get();

      if (!chatDoc.exists) return;

      // Update unread count based on user type
      if (widget.isCooperative) {
        await _firestore
            .collection('cooperative_chats')
            .doc(widget.chatId)
            .update({'unreadCooperativeCount': 0});
      } else {
        await _firestore
            .collection('cooperative_chats')
            .doc(widget.chatId)
            .update({'unreadUserCount': 0});
      }

      // Mark all messages as read
      final batch = _firestore.batch();
      final messagesQuery = await _firestore
          .collection('cooperative_chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: _auth.currentUser!.uid)
          .get();

      for (final doc in messagesQuery.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final currentUserId = _auth.currentUser!.uid;
      final timestamp = FieldValue.serverTimestamp();

      // Get sender's name from users collection
      String senderName = 'User';
      try {
        final userDoc =
            await _firestore.collection('users').doc(currentUserId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          senderName = userData['name'] ?? userData['fullName'] ?? 'User';
        }
      } catch (e) {
        print('Error fetching user name: $e');
      }

      // Check if chat document exists
      final chatDoc = await _firestore
          .collection('cooperative_chats')
          .doc(widget.chatId)
          .get();

      if (!chatDoc.exists) {
        // Create new chat document
        await _firestore
            .collection('cooperative_chats')
            .doc(widget.chatId)
            .set({
          'cooperativeId': widget.cooperativeId,
          'userId': widget.userId,
          'chatType': widget.chatType,
          'createdAt': timestamp,
          'lastMessage': messageText,
          'lastMessageTimestamp': timestamp,
          'lastSenderId': currentUserId,
          'userName': senderName,
          'unreadUserCount': widget.isCooperative ? 1 : 0,
          'unreadCooperativeCount': widget.isCooperative ? 0 : 1,
        });
      } else {
        // Update existing chat document
        await _firestore
            .collection('cooperative_chats')
            .doc(widget.chatId)
            .update({
          'lastMessage': messageText,
          'lastMessageTimestamp': timestamp,
          'lastSenderId': currentUserId,
          'userName': senderName,
          widget.isCooperative ? 'unreadUserCount' : 'unreadCooperativeCount':
              FieldValue.increment(1),
        });
      }

      // Add message to subcollection
      await _firestore
          .collection('cooperative_chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'text': messageText,
        'senderId': currentUserId,
        'timestamp': timestamp,
        'isRead': false,
      });

      // Create push notification for the recipient
      final recipientId =
          widget.isCooperative ? widget.userId : widget.cooperativeId;
      final truncatedMessage = messageText.length > 100
          ? '${messageText.substring(0, 100)}...'
          : messageText;

      await _firestore.collection('cooperative_notifications').add({
        'userId': recipientId,
        'type': 'new_message',
        'title': '💬 New Message from $senderName',
        'body': truncatedMessage,
        'timestamp': timestamp,
        'isRead': false,
        'chatId': widget.chatId,
        'chatType': widget.chatType,
      });

      _messageController.clear();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherPartyName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.chatType == 'seller-cooperative'
                  ? 'Cooperative Support'
                  : 'Customer Support',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Chat type indicator banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.green.shade50,
            child: Row(
              children: [
                Icon(
                  widget.chatType == 'seller-cooperative'
                      ? Icons.storefront
                      : Icons.shopping_bag,
                  size: 16,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.chatType == 'seller-cooperative'
                        ? 'Seller-Cooperative Conversation'
                        : 'Buyer-Cooperative Conversation',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('cooperative_chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading messages: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a conversation!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Scroll to bottom when messages update
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageDoc = messages[index];
                    final messageData =
                        messageDoc.data() as Map<String, dynamic>;
                    final senderId = messageData['senderId'] as String;
                    final text = messageData['text'] as String;
                    final timestamp = messageData['timestamp'] as Timestamp?;
                    final isMe = senderId == _auth.currentUser!.uid;

                    return _buildMessageBubble(
                      text: text,
                      isMe: isMe,
                      timestamp: timestamp,
                    );
                  },
                );
              },
            ),
          ),

          // Message input area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  offset: const Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !_isSending,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
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
    required bool isMe,
    Timestamp? timestamp,
  }) {
    final timeString = timestamp != null
        ? DateFormat('h:mm a').format(timestamp.toDate())
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green.shade100,
              child: Icon(
                widget.isCooperative ? Icons.person : Icons.business,
                size: 18,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Colors.green : Colors.grey.shade200,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  if (timeString.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeString,
                      style: TextStyle(
                        color: isMe
                            ? Colors.white.withOpacity(0.7)
                            : Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green.shade700,
              child: Icon(
                widget.isCooperative ? Icons.business : Icons.person,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
