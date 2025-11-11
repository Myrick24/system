# 💬 Cooperative Chat System - Implementation Guide

## Overview
This document explains how to implement functional conversations between:
1. **Seller → Cooperative** (Farmers can chat with their assigned cooperative)
2. **Buyer → Cooperative** (Customers can chat with cooperatives for support)

The system creates a separate chat collection (`cooperative_chats`) from the existing buyer-seller chats to maintain clear separation and organization.

---

## 📁 Files Created

### 1. **`lib/screens/cooperative_chat_screen.dart`**
**Purpose:** Individual chat conversation screen

**Features:**
- Real-time messaging with Firestore
- Separate message bubbles for sender/receiver
- Unread message tracking
- Timestamp display
- Chat type indicator (seller or buyer conversation)
- Auto-scroll to bottom on new messages

**Parameters:**
```dart
CooperativeChatScreen({
  required String chatId,           // Unique chat identifier
  required String otherPartyName,   // Cooperative or user name
  required String cooperativeId,    // Cooperative user ID
  required String userId,           // Current user ID (seller/buyer)
  required bool isCooperative,      // true if logged-in user is cooperative
  required String chatType,         // 'seller-cooperative' or 'buyer-cooperative'
})
```

---

### 2. **`lib/services/cooperative_chat_service.dart`**
**Purpose:** Helper service to create and manage chats

**Methods:**

#### `startSellerCooperativeChat()`
```dart
await CooperativeChatService.startSellerCooperativeChat(
  context: context,
  cooperativeId: 'coop_id_123',
  cooperativeName: 'San Pedro Cooperative',
);
```
- Creates or opens seller-cooperative chat
- Automatically navigates to chat screen

#### `startBuyerCooperativeChat()`
```dart
await CooperativeChatService.startBuyerCooperativeChat(
  context: context,
  cooperativeId: 'coop_id_123',
  cooperativeName: 'San Pedro Cooperative',
);
```
- Creates or opens buyer-cooperative chat
- Automatically navigates to chat screen

#### `getSellerCooperativeInfo(sellerId)`
- Retrieves cooperative info from seller's profile
- Returns `{cooperativeId, cooperativeName}`

#### `getProductCooperativeInfo(productId)`
- Retrieves cooperative info from product data
- Returns `{cooperativeId, cooperativeName}`

#### `getUnreadCooperativeMessagesCount()`
- Stream of unread message count
- For badge indicators

---

### 3. **`lib/screens/cooperative_messages_screen.dart`**
**Purpose:** List all cooperative chats

**For Cooperative Users:**
- Two tabs: "Sellers" and "Buyers"
- Shows all seller conversations
- Shows all buyer conversations
- Unread message badges

**For Sellers/Buyers:**
- Shows their chats with cooperatives
- Simple list view

---

## 🗄️ Database Structure

### Collection: `cooperative_chats`

Each chat document contains:

```json
{
  "chatId": "auto_generated_id",
  "cooperativeId": "coop_user_id",
  "userId": "seller_or_buyer_id",
  "chatType": "seller-cooperative" | "buyer-cooperative",
  "cooperativeName": "San Pedro Cooperative",
  "userName": "Juan Dela Cruz",
  "createdAt": Timestamp,
  "lastMessage": "Last message text",
  "lastMessageTimestamp": Timestamp,
  "lastSenderId": "user_id_who_sent_last_message",
  "unreadUserCount": 0,
  "unreadCooperativeCount": 2
}
```

### Sub-collection: `cooperative_chats/{chatId}/messages`

Each message document:

```json
{
  "messageId": "auto_generated_id",
  "text": "Hello, I have a question about delivery",
  "senderId": "user_id",
  "timestamp": Timestamp,
  "isRead": false
}
```

---

## 🔌 Integration Steps

### Step 1: Add Chat Button for Sellers

In any seller screen (e.g., seller dashboard, product screen):

```dart
import '../services/cooperative_chat_service.dart';

// In your widget
ElevatedButton.icon(
  icon: const Icon(Icons.chat),
  label: const Text('Chat with Cooperative'),
  onPressed: () async {
    // Get seller's cooperative info
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final cooperativeId = userData['cooperativeId'] as String?;
        
        if (cooperativeId != null) {
          // Get cooperative name
          final coopDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(cooperativeId)
              .get();
          
          final cooperativeName = coopDoc.data()?['name'] ?? 'Cooperative';
          
          // Start chat
          await CooperativeChatService.startSellerCooperativeChat(
            context: context,
            cooperativeId: cooperativeId,
            cooperativeName: cooperativeName,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are not assigned to a cooperative'),
            ),
          );
        }
      }
    }
  },
)
```

---

### Step 2: Add Chat Button for Buyers

In buyer screens (e.g., product details, order screen):

```dart
import '../services/cooperative_chat_service.dart';

// Get cooperative from product
FloatingActionButton(
  child: const Icon(Icons.chat),
  onPressed: () async {
    final coopInfo = await CooperativeChatService
        .getProductCooperativeInfo(productId);
    
    if (coopInfo != null) {
      await CooperativeChatService.startBuyerCooperativeChat(
        context: context,
        cooperativeId: coopInfo['cooperativeId']!,
        cooperativeName: coopInfo['cooperativeName']!,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cooperative not found for this product'),
        ),
      );
    }
  },
)
```

---

### Step 3: Add Messages Screen to Navigation

#### For Cooperative Dashboard

```dart
import '../screens/cooperative_messages_screen.dart';

// In cooperative dashboard navigation
ListTile(
  leading: const Icon(Icons.chat, color: Colors.green),
  title: const Text('Messages'),
  trailing: StreamBuilder<int>(
    stream: CooperativeChatService.getUnreadCooperativeMessagesCount(),
    builder: (context, snapshot) {
      final count = snapshot.data ?? 0;
      if (count == 0) return const SizedBox();
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$count',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
    },
  ),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CooperativeMessagesScreen(),
      ),
    );
  },
)
```

#### For Seller/Buyer Navigation

```dart
// Add to bottom navigation or drawer
BottomNavigationBarItem(
  icon: Badge(
    label: StreamBuilder<int>(
      stream: CooperativeChatService.getUnreadCooperativeMessagesCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Text('$count');
      },
    ),
    child: const Icon(Icons.chat),
  ),
  label: 'Messages',
)
```

---

## 🎯 Usage Examples

### Example 1: Seller Opens Chat from Dashboard

```dart
// In seller_main_dashboard.dart
Card(
  child: ListTile(
    leading: const Icon(Icons.support_agent, color: Colors.green),
    title: const Text('Contact Cooperative'),
    subtitle: const Text('Get support from your cooperative'),
    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    onTap: () async {
      final currentUser = FirebaseAuth.instance.currentUser;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      
      final cooperativeId = userDoc.data()?['cooperativeId'];
      
      if (cooperativeId != null) {
        final coopDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(cooperativeId)
            .get();
        
        final cooperativeName = coopDoc.data()?['name'] ?? 'Cooperative';
        
        await CooperativeChatService.startSellerCooperativeChat(
          context: context,
          cooperativeId: cooperativeId,
          cooperativeName: cooperativeName,
        );
      }
    },
  ),
)
```

---

### Example 2: Buyer Opens Chat from Product

```dart
// In product_details_screen.dart
ElevatedButton.icon(
  icon: const Icon(Icons.help_outline),
  label: const Text('Ask Cooperative'),
  onPressed: () async {
    final coopInfo = await CooperativeChatService
        .getProductCooperativeInfo(widget.productId);
    
    if (coopInfo != null) {
      await CooperativeChatService.startBuyerCooperativeChat(
        context: context,
        cooperativeId: coopInfo['cooperativeId']!,
        cooperativeName: coopInfo['cooperativeName']!,
      );
    }
  },
)
```

---

### Example 3: Cooperative Views All Messages

```dart
// In coop_dashboard.dart
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CooperativeMessagesScreen(),
      ),
    );
  },
  child: const Text('View All Messages'),
)
```

---

## 🔔 Notifications Integration

### Option 1: Show Unread Badge

```dart
StreamBuilder<int>(
  stream: CooperativeChatService.getUnreadCooperativeMessagesCount(),
  builder: (context, snapshot) {
    final count = snapshot.data ?? 0;
    return Badge(
      label: Text('$count'),
      isLabelVisible: count > 0,
      child: IconButton(
        icon: const Icon(Icons.message),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CooperativeMessagesScreen(),
            ),
          );
        },
      ),
    );
  },
)
```

---

## 🧪 Testing Checklist

### Seller-Cooperative Chat
- [ ] Seller can open chat with their cooperative
- [ ] Messages sent by seller appear on right side
- [ ] Messages sent by cooperative appear on left side
- [ ] Unread count updates correctly
- [ ] Chat persists after closing and reopening
- [ ] Timestamps display correctly
- [ ] Multiple sellers can chat with same cooperative

### Buyer-Cooperative Chat
- [ ] Buyer can open chat from product
- [ ] Buyer can open chat from order
- [ ] Messages send and receive correctly
- [ ] Unread count updates for buyer
- [ ] Multiple buyers can chat with same cooperative

### Cooperative Side
- [ ] Cooperative sees "Sellers" and "Buyers" tabs
- [ ] Can view all seller conversations
- [ ] Can view all buyer conversations
- [ ] Unread badges show correctly
- [ ] Can reply to any conversation
- [ ] Conversations sorted by most recent

### Edge Cases
- [ ] Chat works when user has no cooperative assigned (error message)
- [ ] Chat works when product has no cooperative (error message)
- [ ] Empty state shows when no messages
- [ ] Loading state shows while fetching data

---

## 🎨 UI Customization

### Change Chat Colors

In `cooperative_chat_screen.dart`:

```dart
// Change bubble color for sent messages
color: isMe ? Colors.blue : Colors.grey.shade200,

// Change accent color
backgroundColor: Colors.blue, // Change from Colors.green
```

### Add Custom Icons

```dart
// Use different icons for sellers vs buyers
Icon(
  chatType == 'seller-cooperative' 
    ? Icons.agriculture 
    : Icons.shopping_cart,
)
```

---

## 📊 Analytics & Insights

### Track Chat Metrics

```dart
// Count total seller chats
final sellerChats = await FirebaseFirestore.instance
    .collection('cooperative_chats')
    .where('chatType', isEqualTo: 'seller-cooperative')
    .count()
    .get();

// Count total buyer chats
final buyerChats = await FirebaseFirestore.instance
    .collection('cooperative_chats')
    .where('chatType', isEqualTo: 'buyer-cooperative')
    .count()
    .get();

// Get most active users
final chats = await FirebaseFirestore.instance
    .collection('cooperative_chats')
    .orderBy('lastMessageTimestamp', descending: true)
    .limit(10)
    .get();
```

---

## 🚀 Future Enhancements

### Planned Features
- 📎 File/image attachments
- 🔔 Push notifications for new messages
- ✅ Read receipts
- ⌨️ Typing indicators
- 🔍 Search messages
- 📌 Pin important conversations
- 🗑️ Delete conversations
- 📱 In-app notifications

### Advanced Features
- 🤖 Auto-responses for common questions
- 📊 Chat analytics dashboard
- 👥 Group chats (multiple cooperatives)
- 🌐 Multi-language support
- 📞 Voice/video calls integration

---

## ⚠️ Important Notes

1. **Firestore Security Rules Required:**
   ```javascript
   match /cooperative_chats/{chatId} {
     allow read, write: if request.auth != null && 
       (resource.data.userId == request.auth.uid || 
        resource.data.cooperativeId == request.auth.uid);
     
     match /messages/{messageId} {
       allow read, write: if request.auth != null;
     }
   }
   ```

2. **Index Required:**
   - Collection: `cooperative_chats`
   - Fields: `cooperativeId` (Ascending), `chatType` (Ascending), `lastMessageTimestamp` (Descending)

3. **Performance:**
   - Messages are paginated automatically by Firestore
   - Consider implementing pagination for chats list if > 100 conversations

---

## 📝 Summary

This cooperative chat system provides:
- ✅ Separate chat collection from buyer-seller chats
- ✅ Support for seller and buyer conversations with cooperatives
- ✅ Real-time messaging
- ✅ Unread message tracking
- ✅ Easy integration with existing screens
- ✅ Scalable architecture

**Next Steps:**
1. Add chat buttons to seller screens
2. Add chat buttons to buyer screens
3. Add messages screen to cooperative dashboard
4. Test all conversation flows
5. Add Firestore security rules
6. Create required indexes
