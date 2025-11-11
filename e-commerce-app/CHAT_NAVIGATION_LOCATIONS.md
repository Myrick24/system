# Cooperative Chat Navigation - Implementation Guide

This document shows exactly where chat navigation has been added in your app.

## 📍 Navigation Locations

### 1. **Seller Dashboard** 
**File:** `lib/screens/seller/seller_main_dashboard.dart`

**Location:** After the alerts section, before quantity selector  
**Button:** "Contact Cooperative" Card  
**Action:** Opens chat with the cooperative the seller is assigned to

```dart
// Card with blue "Contact Cooperative" button
Card(
  child: InkWell(
    onTap: () async {
      // Fetches seller's cooperativeId
      // Gets cooperative name
      // Calls CooperativeChatService.startSellerCooperativeChat()
    },
    child: Row(
      children: [
        Icon(Icons.support_agent), // Support agent icon
        Text('Contact Cooperative'),
        Text('Get help and support from your cooperative'),
      ],
    ),
  ),
)
```

**What it does:**
- Reads current seller's `cooperativeId` from Firestore
- Retrieves cooperative name
- Opens `CooperativeChatScreen` with `chatType: 'seller'`
- Shows error if seller not assigned to cooperative

---

### 2. **Buyer Product Details Screen**
**File:** `lib/screens/buyer/product_details_screen.dart`

**Location:** Below seller info card, above quantity selector  
**Button:** "Need Help?" Card  
**Action:** Opens chat with the product's cooperative

```dart
// Card with blue "Need Help?" button
Card(
  child: InkWell(
    onTap: () async {
      // Gets product's sellerId
      // Fetches seller's cooperativeId
      // Gets cooperative name
      // Calls CooperativeChatService.startBuyerCooperativeChat()
    },
    child: Row(
      children: [
        Icon(Icons.support_agent), // Support agent icon
        Text('Need Help?'),
        Text('Contact the cooperative for support'),
      ],
    ),
  ),
)
```

**What it does:**
- Gets seller ID from product data
- Reads seller's `cooperativeId` from Firestore
- Retrieves cooperative name
- Opens `CooperativeChatScreen` with `chatType: 'buyer'`
- Shows error if seller not part of cooperative

---

### 3. **Cooperative Dashboard**
**File:** `lib/screens/cooperative/coop_dashboard.dart`

**Location:** AppBar actions (top right)  
**Button:** Chat icon button  
**Action:** Opens messages screen showing all conversations

```dart
AppBar(
  title: Text('Cooperative Dashboard'),
  actions: [
    IconButton(
      icon: Icon(Icons.chat), // Chat bubble icon
      tooltip: 'Messages',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CooperativeMessagesScreen(),
          ),
        );
      },
    ),
  ],
)
```

**What it does:**
- Opens `CooperativeMessagesScreen`
- Shows two tabs: "Seller Messages" and "Buyer Messages"
- Displays all chat conversations for the cooperative
- Shows unread message counts

---

## 🎯 User Flows

### Seller → Cooperative Chat
```
1. Seller opens Seller Dashboard
2. Scrolls to "Contact Cooperative" card
3. Taps card
4. System fetches seller's cooperativeId
5. System gets cooperative name
6. Chat screen opens with cooperative
7. Seller can send messages
```

### Buyer → Cooperative Chat
```
1. Buyer browses products
2. Opens product details
3. Scrolls to "Need Help?" card
4. Taps card
5. System gets product seller's cooperativeId
6. System gets cooperative name
7. Chat screen opens with cooperative
8. Buyer can ask questions
```

### Cooperative Viewing Messages
```
1. Cooperative opens Cooperative Dashboard
2. Taps chat icon (top right)
3. CooperativeMessagesScreen opens
4. Two tabs shown:
   - Seller Messages (all seller chats)
   - Buyer Messages (all buyer chats)
5. Unread badges show new messages
6. Tap any chat to open conversation
```

---

## 🗂️ Database Structure

All chats are stored in the `cooperative_chats` collection:

```
cooperative_chats/{chatId}
├── cooperativeId: "coop_id_123"
├── userId: "seller_or_buyer_id"
├── userName: "John Seller"
├── chatType: "seller" or "buyer"
├── createdAt: Timestamp
├── lastMessage: "Latest message text"
├── lastMessageTimestamp: Timestamp
├── lastSenderId: "who_sent_last_message"
├── unreadCooperativeCount: 2
├── unreadUserCount: 0
└── messages (sub-collection)
    └── {messageId}
        ├── senderId: "user_id"
        ├── senderName: "John Doe"
        ├── message: "Hello!"
        ├── timestamp: Timestamp
        └── read: false
```

---

## 🔒 Security Rules

Firestore rules deployed to allow access:

```javascript
// Cooperative chats
match /cooperative_chats/{chatId} {
  allow read: if request.auth != null && 
    (resource.data.userId == request.auth.uid || 
     resource.data.cooperativeId == request.auth.uid);
  
  allow create: if request.auth != null && 
    request.resource.data.userId == request.auth.uid;
  
  allow update: if request.auth != null && 
    (resource.data.userId == request.auth.uid || 
     resource.data.cooperativeId == request.auth.uid);
  
  // Messages sub-collection
  match /messages/{messageId} {
    allow read: if request.auth != null;
    allow create: if request.auth != null;
    allow update: if request.auth != null;
  }
}
```

---

## 📱 UI Elements

### Seller Button Style
- **Icon:** `Icons.support_agent` (headset with person)
- **Color:** Blue (`Colors.blue.shade700`)
- **Background:** Blue tint (`Colors.blue.shade50`)
- **Style:** Card with rounded corners
- **Text:** "Contact Cooperative" + subtitle

### Buyer Button Style
- **Icon:** `Icons.support_agent` (headset with person)
- **Color:** Blue (`Colors.blue.shade700`)
- **Background:** Blue tint (`Colors.blue.shade50`)
- **Style:** Card with rounded corners, blue border
- **Text:** "Need Help?" + subtitle

### Cooperative Button Style
- **Icon:** `Icons.chat` (chat bubble)
- **Color:** White (AppBar default)
- **Location:** AppBar top right
- **Tooltip:** "Messages"

---

## ✅ Testing Checklist

- [ ] **Seller can contact cooperative**
  - Open seller dashboard
  - Tap "Contact Cooperative" button
  - Verify chat opens with correct cooperative name
  - Send test message
  
- [ ] **Buyer can contact cooperative**
  - Browse products
  - Open any product details
  - Tap "Need Help?" button
  - Verify chat opens with product's cooperative
  - Send test message
  
- [ ] **Cooperative can view messages**
  - Open cooperative dashboard
  - Tap chat icon (top right)
  - Verify "Seller Messages" tab shows seller chats
  - Verify "Buyer Messages" tab shows buyer chats
  - Tap a chat and verify it opens
  - Send reply message
  
- [ ] **Unread counts work**
  - Send message as seller
  - Check cooperative sees unread badge
  - Open chat as cooperative
  - Verify unread count updates
  
- [ ] **Error handling**
  - Test with seller not assigned to cooperative
  - Test with product from seller without cooperative
  - Verify appropriate error messages

---

## 🚀 Quick Start

1. **Deploy Security Rules** (if not done)
   ```bash
   cd e-commerce-app
   firebase deploy --only firestore:rules
   ```

2. **Test Seller → Cooperative**
   - Login as a seller
   - Go to dashboard
   - Click "Contact Cooperative"

3. **Test Buyer → Cooperative**
   - Login as a buyer
   - Browse products
   - Open product details
   - Click "Need Help?"

4. **Test Cooperative Messages**
   - Login as cooperative
   - Open cooperative dashboard
   - Click chat icon (top right)

---

## 📚 Related Documentation

- `COOPERATIVE_CHAT_IMPLEMENTATION.md` - Full technical implementation details
- `COOPERATIVE_CHAT_QUICK_START.md` - Code examples and usage
- `HOW_TO_ADD_CHAT_DATABASE.md` - Database setup guide

---

## 🎨 Visual Reference

### Seller Dashboard - Contact Cooperative Button
```
┌─────────────────────────────────────┐
│  [📞]  Contact Cooperative          │
│        Get help and support from    │
│        your cooperative          [>]│
└─────────────────────────────────────┘
```

### Buyer Product Details - Need Help Button
```
┌─────────────────────────────────────┐
│  [📞]  Need Help?                   │
│        Contact the cooperative for  │
│        support                    [>]│
└─────────────────────────────────────┘
```

### Cooperative Dashboard - Chat Icon
```
┌──────────────────────────────────────┐
│  Cooperative Dashboard         [💬]  │
└──────────────────────────────────────┘
```

---

**Last Updated:** Current implementation  
**Status:** ✅ Fully Implemented and Ready to Test
