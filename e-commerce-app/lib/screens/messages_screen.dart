import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_detail_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  bool _isLoading = true;
  bool _isSeller = false;
  String? _sellerId;
  TabController? _tabController;
  Map<String, String> _userNames = {}; // Cache for user names
  Map<String, String> _sellerNames = {}; // Cache for seller names

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _getCurrentUser();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    setState(() {
      _isLoading = true;
    });

    _currentUser = _auth.currentUser;

    if (_currentUser != null) {
      try {
        print('DEBUG: Checking user role for UID: ${_currentUser!.uid}');
        
        // First check the users collection for seller role
        final userDoc = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .get();
            
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          print('DEBUG: User data found: ${userData['role']}');
          if (userData['role'] == 'seller') {
            setState(() {
              _isSeller = true;
              _sellerId = _currentUser!.uid;
            });
            print('DEBUG: User is seller (from users collection)');
            setState(() {
              _isLoading = false;
            });
            return;
          }
        } else {
          print('DEBUG: No user document found in users collection');
        }

        // Fallback: Check if user is registered as a seller by email
        print('DEBUG: Checking sellers collection by email: ${_currentUser!.email}');
        final sellerQuery = await _firestore
            .collection('sellers')
            .where('email', isEqualTo: _currentUser!.email)
            .limit(1)
            .get();
            
        if (sellerQuery.docs.isNotEmpty) {
          final sellerData = sellerQuery.docs.first.data();
          final sellerStatus = sellerData['status'] as String?;
          
          print('DEBUG: Found seller document with status: $sellerStatus');
          
          // Only mark as seller if they are approved
          if (sellerStatus == 'approved') {
            setState(() {
              _isSeller = true;
              _sellerId = _currentUser!.uid; // Use Firebase Auth user ID
            });
            print('DEBUG: User is approved seller (from sellers collection)');
          } else {
            print('DEBUG: User is not an approved seller (status: $sellerStatus)');
          }
        } else {
          print('DEBUG: User is not a seller');
        }
      } catch (e) {
        print('Error checking seller status: $e');
      }
    }

    setState(() {
      _isLoading = false;
    });
  }
  
  // Function to get user name from Firestore
  Future<String> _getUserName(String userId) async {
    // First check if we already have this user name in cache
    if (_userNames.containsKey(userId)) {
      return _userNames[userId]!;
    }
    
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        
        // Try to get the best available name
        String? name = userData['fullName'];
        
        if (name == null || name.isEmpty) {
          name = userData['name'];
        }
        
        if (name == null || name.isEmpty) {
          name = userData['displayName'];
        }
        
        if (name == null || name.isEmpty) {
          // Try to combine first and last name
          final firstName = userData['firstName'];
          final lastName = userData['lastName'];
          if (firstName != null && firstName.isNotEmpty) {
            name = firstName;
            if (lastName != null && lastName.isNotEmpty) {
              name = name! + ' $lastName';
            }
          }
        }
        
        if (name == null || name.isEmpty) {
          // Fallback to email username
          final email = userData['email'];
          if (email != null && email.isNotEmpty) {
            name = email.toString().split('@').first;
            // Capitalize first letter
            if (name.isNotEmpty) {
              name = name[0].toUpperCase() + name.substring(1);
            }
          }
        }
        
        // Final fallback
        name ??= 'Customer';
        
        // Store in cache for future use
        _userNames[userId] = name;
        print('DEBUG: Retrieved user name for $userId: $name');
        return name;
      } else {
        print('DEBUG: No user document found for userId: $userId');
      }
    } catch (e) {
      print('Error fetching user name for userId: $userId, error: $e');
    }
    
    return 'Customer';
  }
  
  // Function to get seller name from Firestore
  Future<String> _getSellerName(String sellerId) async {
    // First check if we already have this seller name in cache
    if (_sellerNames.containsKey(sellerId)) {
      return _sellerNames[sellerId]!;
    }
    
    try {
      String? name;
      
      // First try to get seller info from users collection (if they have seller role)
      final userDoc = await _firestore.collection('users').doc(sellerId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (userData['role'] == 'seller') {
          // Get personal name from user profile
          name = userData['fullName'];
          
          if (name == null || name.isEmpty) {
            name = userData['name'];
          }
          
          if (name == null || name.isEmpty) {
            name = userData['displayName'];
          }
          
          if (name == null || name.isEmpty) {
            // Try to combine first and last name
            final firstName = userData['firstName'];
            final lastName = userData['lastName'];
            if (firstName != null && firstName.isNotEmpty) {
              name = firstName;
              if (lastName != null && lastName.isNotEmpty) {
                name = name! + ' $lastName';
              }
            }
          }
          
          if (name != null && name.isNotEmpty) {
            _sellerNames[sellerId] = name;
            print('DEBUG: Retrieved seller name from users collection for $sellerId: $name');
            return name;
          }
        }
      }
      
      // Fallback: Try to get seller by direct document ID in sellers collection
      DocumentSnapshot sellerDoc = await _firestore.collection('sellers').doc(sellerId).get();
      
      // If not found by direct ID, try searching by userId field
      if (!sellerDoc.exists) {
        final sellerQuery = await _firestore
            .collection('sellers')
            .where('userId', isEqualTo: sellerId)
            .limit(1)
            .get();
            
        if (sellerQuery.docs.isNotEmpty) {
          sellerDoc = sellerQuery.docs.first;
        }
      }
      
      if (sellerDoc.exists) {
        final sellerData = sellerDoc.data() as Map<String, dynamic>;
        
        // Prioritize personal name fields first
        name = sellerData['fullName'];
        
        if (name == null || name.isEmpty) {
          name = sellerData['name'];
        }
        
        if (name == null || name.isEmpty) {
          name = sellerData['displayName'];
        }
        
        if (name == null || name.isEmpty) {
          // Try to combine first and last name
          final firstName = sellerData['firstName'];
          final lastName = sellerData['lastName'];
          if (firstName != null && firstName.isNotEmpty) {
            name = firstName;
            if (lastName != null && lastName.isNotEmpty) {
              name = name! + ' $lastName';
            }
          }
        }
        
        // Only if no personal name is found, use business name
        if (name == null || name.isEmpty) {
          name = sellerData['businessName'] ?? 
                sellerData['companyName'] ?? 
                sellerData['storeName'];
        }
        
        // If still no name, try email
        if (name == null || name.isEmpty) {
          final email = sellerData['email'];
          if (email != null && email.isNotEmpty) {
            name = email.toString().split('@').first;
            // Capitalize first letter
            if (name.isNotEmpty) {
              name = name[0].toUpperCase() + name.substring(1);
            }
          }
        }
        
        // Final fallback
        name ??= 'Seller';
                     
        // Store in cache for future use
        _sellerNames[sellerId] = name;
        print('DEBUG: Retrieved seller name from sellers collection for $sellerId: $name');
        return name;
      } else {
        print('DEBUG: No seller document found for sellerId: $sellerId');
      }
    } catch (e) {
      print('Error fetching seller name for sellerId: $sellerId, error: $e');
    }
    
    return 'Seller';
  }

  // Helper function to determine who sent the last message
  String _getLastMessageSender(Map<String, dynamic> chatData) {
    final lastSenderId = chatData['lastSenderId'] as String?;
    
    if (lastSenderId == null) return '';
    
    if (lastSenderId == _currentUser!.uid) {
      return 'You: ';
    } else {
      // The other party sent it
      if (_isSeller) {
        return 'Customer: ';
      } else {
        return 'Seller: ';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green,
          title: const Text(
            'Messages',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green,
          title: const Text(
            'Messages',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please login to view messages',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text(
                  'Login',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Recent Chats'),
            Tab(text: 'All Contacts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Recent Chats Tab
          _buildChatsList(recentOnly: true),
          
          // All Contacts Tab
          _buildChatsList(recentOnly: false),
        ],
      ),
    );
  }

  Widget _buildChatsList({required bool recentOnly}) {
    Query chatsQuery;
    
    if (_isSeller) {
      // Seller view - show chats where they are the seller
      print('DEBUG: Building seller chats query with sellerId: $_sellerId');
      
      // Use simple query without timestamp filter to avoid index issues
      chatsQuery = _firestore.collection('chats')
          .where('sellerId', isEqualTo: _sellerId);
    } else {
      // Customer view - show chats where they are the customer
      print('DEBUG: Building customer chats query with customerId: ${_currentUser!.uid}');
      print('DEBUG: Current user is NOT a seller, querying as customer');
      
      // Use simple query without timestamp filter to avoid index issues
      chatsQuery = _firestore.collection('chats')
          .where('customerId', isEqualTo: _currentUser!.uid);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: chatsQuery.snapshots().timeout(
        const Duration(seconds: 10),
        onTimeout: (sink) {
          print('DEBUG: Query timeout after 10 seconds');
          sink.addError('Query timeout. Please check your internet connection.');
        },
      ),
      builder: (context, snapshot) {
        print('DEBUG: StreamBuilder state: ${snapshot.connectionState}');
        if (snapshot.hasError) {
          print('DEBUG: StreamBuilder error: ${snapshot.error}');
          print('DEBUG: Error details: ${snapshot.error.runtimeType}');
        }
        if (snapshot.hasData) {
          print('DEBUG: StreamBuilder data: ${snapshot.data?.docs.length} documents');
          final docs = snapshot.data?.docs ?? [];
          for (int i = 0; i < docs.length; i++) {
            final chatData = docs[i].data() as Map<String, dynamic>;
            print('Chat $i: isSeller=$_isSeller, customerId=${chatData['customerId']}, sellerId=${chatData['sellerId']}, currentUserId=${_currentUser!.uid}');
          }
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _isSeller ? 'Loading seller messages...' : 'Loading customer messages...',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading messages',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      // Trigger rebuild to retry
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final chats = snapshot.data?.docs ?? [];
        
        // Filter for recent chats on client side if needed
        List<QueryDocumentSnapshot> filteredChats = chats;
        if (recentOnly) {
          final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
          filteredChats = chats.where((chat) {
            final chatData = chat.data() as Map<String, dynamic>;
            final timestamp = chatData['lastMessageTimestamp'] as Timestamp?;
            if (timestamp == null) return false;
            return timestamp.toDate().isAfter(thirtyDaysAgo);
          }).toList();
        }
        
        // Sort the chats by lastMessageTimestamp manually
        filteredChats.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          
          final aTime = (aData['lastMessageTimestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bTime = (bData['lastMessageTimestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
          
          return bTime.compareTo(aTime); // Descending order (newest first)
        });

        if (filteredChats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  recentOnly ? 'No recent messages' : 'No messages yet',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredChats.length,
          itemBuilder: (context, index) {
            final chatData = filteredChats[index].data() as Map<String, dynamic>;
            final chatId = filteredChats[index].id;
            
            // Determine if we need to fetch customer or seller info
            final otherPartyId = _isSeller 
                ? chatData['customerId'] as String 
                : chatData['sellerId'] as String;
            
            // Debug logging
            print('Chat $index: isSeller=$_isSeller, otherPartyId=$otherPartyId, chatData keys: ${chatData.keys.toList()}');
            
            final Future<String> otherPartyNameFuture = _isSeller
                ? _getUserName(otherPartyId)
                : _getSellerName(otherPartyId);

            final lastMessage = chatData['lastMessage'] as String? ?? 'No messages yet';
            final lastMessageTime = (chatData['lastMessageTimestamp'] as Timestamp?)?.toDate();
            final formattedTime = lastMessageTime != null 
                ? _formatChatTime(lastMessageTime) 
                : '';
            final unreadCount = _isSeller 
                ? chatData['unreadSellerCount'] as int? ?? 0 
                : chatData['unreadCustomerCount'] as int? ?? 0;
            
            // Get product information if available
            final productData = chatData['product'] as Map<String, dynamic>?;
            final productName = productData?['name'] ?? productData?['title'];
            final productId = chatData['productId'] as String?;
            
            return FutureBuilder<String>(
              future: otherPartyNameFuture,
              builder: (context, nameSnapshot) {
                if (nameSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    title: Text('Loading...'),
                  );
                }

                final userName = nameSnapshot.data ?? (_isSeller ? 'Customer' : 'Seller');
                
                // Add role indicator for clarity
                final roleIndicator = _isSeller 
                    ? '👤 ' // Customer icon for sellers viewing customers
                    : '🏪 '; // Store icon for customers viewing sellers
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _isSeller ? Colors.blue : Colors.green,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        roleIndicator,
                        style: const TextStyle(fontSize: 14),
                      ),
                      Expanded(
                        child: Text(
                          userName,
                          style: TextStyle(
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: unreadCount > 0 ? Colors.green : Colors.grey,
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show product name if available
                      if (productName != null && productName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            'Re: $productName',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.blue,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      // Last message with sender indicator
                      Row(
                        children: [
                          Expanded(
                            child: RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: [
                                  // Show who sent the last message
                                  TextSpan(
                                    text: _getLastMessageSender(chatData),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                                    ),
                                  ),
                                  TextSpan(
                                    text: lastMessage,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                      color: unreadCount > 0 ? Colors.black : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailScreen(
                          chatId: chatId,
                          otherPartyName: userName,
                          sellerId: chatData['sellerId'] as String,
                          customerId: chatData['customerId'] as String,
                          isSeller: _isSeller,
                          product: productData,
                          productId: productId,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatChatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      // Today, show time
      return DateFormat('h:mm a').format(time);
    } else if (messageDate == yesterday) {
      // Yesterday
      return 'Yesterday';
    } else if (now.difference(time).inDays < 7) {
      // Within last week, show day name
      return DateFormat('E').format(time);
    } else {
      // Older, show date
      return DateFormat('M/d/yy').format(time);
    }
  }
}