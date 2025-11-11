# 🎯 Quick Implementation Examples

## How to Add Chat Buttons to Your App

This guide shows **exactly where** to add the chat functionality in your existing screens.

---

## 1️⃣ For Sellers

### A. Add to Seller Dashboard

**File:** `lib/screens/seller/seller_main_dashboard.dart`

**Where:** In the dashboard cards section

```dart
// Add this import at the top
import '../services/cooperative_chat_service.dart';

// Add this card in your build method
Card(
  elevation: 2,
  child: InkWell(
    onTap: () async {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final cooperativeId = userData['cooperativeId'] as String?;
            
            if (cooperativeId != null) {
              final coopDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(cooperativeId)
                  .get();
              
              if (coopDoc.exists) {
                final cooperativeName = coopDoc.data()?['name'] ?? 'Cooperative';
                
                await CooperativeChatService.startSellerCooperativeChat(
                  context: context,
                  cooperativeId: cooperativeId,
                  cooperativeName: cooperativeName,
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('You are not assigned to a cooperative yet'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    },
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.support_agent,
              color: Colors.green,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact Cooperative',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Chat with your cooperative support',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    ),
  ),
)
```

---

### B. Add Floating Action Button

**File:** Any seller screen

```dart
// Add this import
import '../services/cooperative_chat_service.dart';

Scaffold(
  // ... your existing code
  floatingActionButton: FloatingActionButton.extended(
    onPressed: () async {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
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
      }
    },
    backgroundColor: Colors.green,
    icon: const Icon(Icons.chat),
    label: const Text('Chat with Coop'),
  ),
)
```

---

## 2️⃣ For Buyers

### A. Add to Product Details Screen

**File:** `lib/screens/buyer/product_details_screen.dart`

**Where:** Near the "Buy Now" or "Add to Cart" buttons

```dart
// Add this import at the top
import '../services/cooperative_chat_service.dart';

// Add this button
ElevatedButton.icon(
  icon: const Icon(Icons.chat_bubble_outline),
  label: const Text('Ask Cooperative'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.orange,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 48),
  ),
  onPressed: () async {
    try {
      final coopInfo = await CooperativeChatService
          .getProductCooperativeInfo(widget.productId);
      
      if (coopInfo != null) {
        await CooperativeChatService.startBuyerCooperativeChat(
          context: context,
          cooperativeId: coopInfo['cooperativeId']!,
          cooperativeName: coopInfo['cooperativeName']!,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cooperative information not available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  },
)
```

---

### B. Add to Buyer Home Screen

**File:** `lib/screens/buyer/buyer_home_content.dart`

**Where:** In the app bar or as a floating button

```dart
// Add this import
import '../services/cooperative_chat_service.dart';

// Option 1: Add to AppBar actions
AppBar(
  title: const Text('Products'),
  actions: [
    IconButton(
      icon: const Icon(Icons.support_agent),
      tooltip: 'Contact Cooperative',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CooperativeMessagesScreen(),
          ),
        );
      },
    ),
  ],
)

// Option 2: Add as Help Card
Card(
  child: ListTile(
    leading: const Icon(Icons.help_outline, color: Colors.blue),
    title: const Text('Need Help?'),
    subtitle: const Text('Chat with cooperative support'),
    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    onTap: () async {
      // Get cooperative from first available product
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();
      
      if (productsSnapshot.docs.isNotEmpty) {
        final productId = productsSnapshot.docs.first.id;
        final coopInfo = await CooperativeChatService
            .getProductCooperativeInfo(productId);
        
        if (coopInfo != null) {
          await CooperativeChatService.startBuyerCooperativeChat(
            context: context,
            cooperativeId: coopInfo['cooperativeId']!,
            cooperativeName: coopInfo['cooperativeName']!,
          );
        }
      }
    },
  ),
)
```

---

## 3️⃣ For Cooperative Dashboard

### Add Messages Tab

**File:** `lib/screens/cooperative/coop_dashboard.dart`

**Where:** In the navigation drawer or bottom navigation

```dart
// Add this import at the top
import '../cooperative_messages_screen.dart';

// Option 1: Add to Drawer
ListTile(
  leading: const Icon(Icons.chat, color: Colors.green),
  title: const Text('Messages'),
  subtitle: const Text('Seller & Buyer conversations'),
  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CooperativeMessagesScreen(),
      ),
    );
  },
)

// Option 2: Add as Dashboard Card
Card(
  elevation: 2,
  child: InkWell(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CooperativeMessagesScreen(),
        ),
      );
    },
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.blue,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'View seller & buyer conversations',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    ),
  ),
)
```

---

## 4️⃣ Add to Order Details Screen

### For Buyers to Contact Cooperative About Orders

**File:** `lib/screens/order_status_screen.dart`

```dart
// Add this import
import '../services/cooperative_chat_service.dart';

// Add this button in the order details
ElevatedButton.icon(
  icon: const Icon(Icons.support),
  label: const Text('Contact Cooperative'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.blue,
    foregroundColor: Colors.white,
  ),
  onPressed: () async {
    final productId = orderData['productId'];
    if (productId != null) {
      final coopInfo = await CooperativeChatService
          .getProductCooperativeInfo(productId);
      
      if (coopInfo != null) {
        await CooperativeChatService.startBuyerCooperativeChat(
          context: context,
          cooperativeId: coopInfo['cooperativeId']!,
          cooperativeName: coopInfo['cooperativeName']!,
        );
      }
    }
  },
)
```

---

## 🎨 Custom Styling Examples

### Green Theme (Match Your App)

```dart
// Use your app's green color
ElevatedButton.icon(
  icon: const Icon(Icons.chat),
  label: const Text('Chat with Cooperative'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.green,  // Your app color
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
  onPressed: () { /* ... */ },
)
```

### Outlined Button Style

```dart
OutlinedButton.icon(
  icon: const Icon(Icons.chat, color: Colors.green),
  label: const Text('Contact Support'),
  style: OutlinedButton.styleFrom(
    foregroundColor: Colors.green,
    side: const BorderSide(color: Colors.green, width: 2),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  ),
  onPressed: () { /* ... */ },
)
```

---

## 🔔 Add Unread Badge (Optional)

### Show Unread Count on Chat Button

```dart
// Add this import
import '../services/cooperative_chat_service.dart';

Badge(
  label: StreamBuilder<int>(
    stream: CooperativeChatService.getUnreadCooperativeMessagesCount(),
    builder: (context, snapshot) {
      final count = snapshot.data ?? 0;
      if (count == 0) return const SizedBox.shrink();
      return Text('$count');
    },
  ),
  child: IconButton(
    icon: const Icon(Icons.chat),
    onPressed: () {
      // Open messages screen
    },
  ),
)
```

---

## ✅ Quick Testing

After adding the buttons:

1. **As Seller:**
   - Click "Contact Cooperative" button
   - Send a test message
   - Check message appears in chat

2. **As Cooperative:**
   - Open Messages screen
   - See seller's message in "Sellers" tab
   - Reply to message

3. **As Buyer:**
   - Click "Ask Cooperative" button
   - Send a question
   - Check response from cooperative

---

## 📱 Recommended Placements

### Sellers Should Have Chat Access:
- ✅ Seller Dashboard (main screen)
- ✅ Products Screen (help with products)
- ✅ Orders Screen (order support)
- ✅ Settings/Profile (general support)

### Buyers Should Have Chat Access:
- ✅ Product Details (questions about product)
- ✅ Checkout Screen (delivery questions)
- ✅ Order Status (order issues)
- ✅ Home Screen (general inquiries)

### Cooperatives Should Have:
- ✅ Dashboard (main messages link)
- ✅ Notifications (message alerts)
- ✅ Bottom Navigation (quick access)

---

## 💡 Pro Tips

1. **Context Matters:** When opening chat from a product screen, consider passing product info to the chat
2. **Error Handling:** Always wrap chat calls in try-catch
3. **Loading States:** Show loading indicator while fetching cooperative info
4. **User Feedback:** Show success message after sending first message
5. **Accessibility:** Use clear labels like "Chat with Cooperative" not just icons

---

## 🆘 Troubleshooting

### "Cooperative not found"
- Check seller has `cooperativeId` in their user document
- Verify cooperative user exists in database

### "Can't send message"
- Check Firestore security rules allow writes
- Verify user is authenticated

### Messages not real-time
- Check Firestore index is created
- Verify StreamBuilder is used correctly

---

This guide should help you quickly add chat functionality to all the right places in your app! 🚀
