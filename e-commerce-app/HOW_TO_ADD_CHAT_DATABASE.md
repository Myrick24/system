# 🗄️ How to Add Cooperative Chat Database to Firestore

## Quick Answer

**The database is created AUTOMATICALLY** when users start using the chat feature! You don't need to manually create it.

However, if you want to test it or create sample data, follow the steps below.

---

## Method 1: Automatic Creation (Recommended) ✅

### When Database is Created:

1. **When a seller starts a chat:**
   ```dart
   await CooperativeChatService.startSellerCooperativeChat(
     context: context,
     cooperativeId: 'coop_123',
     cooperativeName: 'San Pedro Cooperative',
   );
   ```
   → Creates `cooperative_chats` collection with a new document

2. **When a buyer starts a chat:**
   ```dart
   await CooperativeChatService.startBuyerCooperativeChat(
     context: context,
     cooperativeId: 'coop_123',
     cooperativeName: 'San Pedro Cooperative',
   );
   ```
   → Creates `cooperative_chats` collection with a new document

3. **When first message is sent:**
   → Creates `messages` sub-collection under the chat document

### What Gets Created:

```
Firestore Database
└── cooperative_chats (collection)
    └── {auto-generated-id} (document)
        ├── cooperativeId: "coop_123"
        ├── userId: "seller_or_buyer_id"
        ├── chatType: "seller-cooperative"
        ├── cooperativeName: "San Pedro Cooperative"
        ├── userName: "Juan Dela Cruz"
        ├── createdAt: Timestamp
        ├── lastMessage: ""
        ├── lastMessageTimestamp: Timestamp
        ├── lastSenderId: ""
        ├── unreadUserCount: 0
        ├── unreadCooperativeCount: 0
        └── messages (sub-collection)
            └── {auto-generated-id} (document)
                ├── text: "Hello!"
                ├── senderId: "user_id"
                ├── timestamp: Timestamp
                └── isRead: false
```

---

## Method 2: Using Test Screen (For Testing) 🧪

### Step 1: Add Test Screen to Your App

Open any screen (e.g., seller dashboard) and add a button:

```dart
// Add import
import 'package:your_app/screens/test_cooperative_chat_screen.dart';

// Add button
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TestCooperativeChatScreen(),
      ),
    );
  },
  child: const Text('Test Chat Database'),
)
```

### Step 2: Run the Test Screen

1. Run your app
2. Navigate to the test screen
3. Click **"Create Test Database"**
4. Check Firebase Console to see the created data

---

## Method 3: Firebase Console (Manual) 🖱️

### Step 1: Open Firebase Console

1. Go to https://console.firebase.google.com
2. Select your project
3. Click "Firestore Database" in left menu

### Step 2: Create Collection

1. Click **"Start collection"**
2. Collection ID: `cooperative_chats`
3. Click **"Next"**

### Step 3: Add First Document

1. Document ID: Leave as **"Auto-ID"**
2. Add fields:

| Field Name | Type | Value |
|------------|------|-------|
| cooperativeId | string | coop_123 |
| userId | string | user_456 |
| chatType | string | seller-cooperative |
| cooperativeName | string | San Pedro Cooperative |
| userName | string | Juan Dela Cruz |
| createdAt | timestamp | (current time) |
| lastMessage | string | Hello! |
| lastMessageTimestamp | timestamp | (current time) |
| lastSenderId | string | user_456 |
| unreadUserCount | number | 0 |
| unreadCooperativeCount | number | 1 |

3. Click **"Save"**

### Step 4: Add Sub-collection (Messages)

1. Click on the document you just created
2. Click **"Start collection"**
3. Collection ID: `messages`
4. Click **"Next"**
5. Add first message:

| Field Name | Type | Value |
|------------|------|-------|
| text | string | Hello, I have a question |
| senderId | string | user_456 |
| timestamp | timestamp | (current time) |
| isRead | boolean | false |

6. Click **"Save"**

---

## Method 4: Using Firestore REST API 🔧

```javascript
// Using Firebase Admin SDK or REST API
const admin = require('firebase-admin');
const db = admin.firestore();

// Create a chat
const chatRef = await db.collection('cooperative_chats').add({
  cooperativeId: 'coop_123',
  userId: 'user_456',
  chatType: 'seller-cooperative',
  cooperativeName: 'San Pedro Cooperative',
  userName: 'Juan Dela Cruz',
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  lastMessage: '',
  lastMessageTimestamp: admin.firestore.FieldValue.serverTimestamp(),
  lastSenderId: '',
  unreadUserCount: 0,
  unreadCooperativeCount: 0
});

// Add a message
await chatRef.collection('messages').add({
  text: 'Hello!',
  senderId: 'user_456',
  timestamp: admin.firestore.FieldValue.serverTimestamp(),
  isRead: false
});
```

---

## Verification Steps ✔️

### 1. Check Firebase Console

1. Go to Firestore Database
2. Look for `cooperative_chats` collection
3. Expand it to see documents
4. Click a document to see its sub-collection `messages`

### 2. Use the App

1. Run the app
2. Log in as a seller
3. Click "Contact Cooperative"
4. Send a message
5. Check Firebase Console - you should see the new data!

### 3. Use Test Screen

1. Navigate to Test Cooperative Chat Screen
2. Click "Verify Structure"
3. Check console output for confirmation

---

## Required Firestore Security Rules 🔒

Add these rules in Firebase Console → Firestore Database → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Cooperative chats
    match /cooperative_chats/{chatId} {
      // Allow read/write if user is part of the chat
      allow read, write: if request.auth != null && 
        (resource.data.userId == request.auth.uid || 
         resource.data.cooperativeId == request.auth.uid);
      
      // Messages sub-collection
      match /messages/{messageId} {
        allow read, write: if request.auth != null;
      }
    }
  }
}
```

**Don't forget to publish the rules!**

---

## Required Firestore Indexes 📊

The app will prompt you to create indexes when needed, but you can create them manually:

### Index 1: Chat List for Cooperatives

- **Collection:** `cooperative_chats`
- **Fields:**
  1. `cooperativeId` (Ascending)
  2. `chatType` (Ascending)
  3. `lastMessageTimestamp` (Descending)

### Index 2: Chat List for Users

- **Collection:** `cooperative_chats`
- **Fields:**
  1. `userId` (Ascending)
  2. `lastMessageTimestamp` (Descending)

### How to Create Indexes:

1. Go to Firebase Console → Firestore Database → Indexes
2. Click **"Create Index"**
3. Enter the collection and fields above
4. Click **"Create"**

Or just run the app - Firebase will show an error with a link to auto-create the index!

---

## Example Data Structure 📋

Here's what a complete chat looks like in Firestore:

```json
{
  "cooperative_chats": {
    "chat_abc123": {
      "cooperativeId": "coop_sanpedro",
      "userId": "seller_juan",
      "chatType": "seller-cooperative",
      "cooperativeName": "San Pedro Cooperative",
      "userName": "Juan Dela Cruz",
      "createdAt": "2025-11-12T10:30:00Z",
      "lastMessage": "Thank you for your help!",
      "lastMessageTimestamp": "2025-11-12T11:45:00Z",
      "lastSenderId": "seller_juan",
      "unreadUserCount": 0,
      "unreadCooperativeCount": 1,
      
      "messages": {
        "msg_001": {
          "text": "Hello, I have a question about my product",
          "senderId": "seller_juan",
          "timestamp": "2025-11-12T10:31:00Z",
          "isRead": true
        },
        "msg_002": {
          "text": "Hi! How can I help you?",
          "senderId": "coop_sanpedro",
          "timestamp": "2025-11-12T10:35:00Z",
          "isRead": true
        },
        "msg_003": {
          "text": "Thank you for your help!",
          "senderId": "seller_juan",
          "timestamp": "2025-11-12T11:45:00Z",
          "isRead": false
        }
      }
    }
  }
}
```

---

## Common Issues & Solutions 🔧

### Issue: "Collection doesn't exist"
**Solution:** It's normal! The collection is created when first data is added. Just use the chat feature once.

### Issue: "Permission denied"
**Solution:** Add the Firestore security rules shown above.

### Issue: "Query requires an index"
**Solution:** Click the link in the error message, or create indexes manually as shown above.

### Issue: "Can't find cooperative"
**Solution:** Make sure:
- Cooperative user exists in `users` collection
- User has `role: 'cooperative'`
- User has a `name` field

---

## Testing Checklist ✅

- [ ] Firebase project is configured
- [ ] Firestore is enabled in Firebase Console
- [ ] Security rules are added
- [ ] Seller can start a chat
- [ ] Buyer can start a chat
- [ ] Messages appear in real-time
- [ ] Unread counts update correctly
- [ ] Data appears in Firebase Console

---

## Summary

**You don't need to manually create the database!** 

Just:
1. ✅ Add the chat buttons to your app (see COOPERATIVE_CHAT_QUICK_START.md)
2. ✅ Add Firestore security rules
3. ✅ Use the chat feature
4. ✅ Database is automatically created!

The `cooperative_chats` collection and all documents are created automatically by the `CooperativeChatService` when users start conversations.

For testing purposes, use the `TestCooperativeChatScreen` to create sample data quickly! 🚀
