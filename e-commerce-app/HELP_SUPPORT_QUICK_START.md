# Help & Support - Quick Start Guide

## 🚀 How to Test the New Help & Support System

### Step 1: Access Help & Support
1. Open the app
2. Navigate to the **Account** tab (bottom navigation)
3. Scroll down to **Account Settings**
4. Tap on **Help & Support**

### Step 2: Explore the Main Hub
You'll see:
- **Search bar** at the top
- **4 Quick Action cards**:
  - Live Chat (blue)
  - FAQ (orange)
  - Contact Us (purple)
  - My Tickets (teal) - shows count of open tickets
- **Popular Topics** section
- **Contact Information** section

### Step 3: Try the FAQ System
1. Tap on **FAQ** quick action or any popular topic
2. Browse different categories using the chips at top
3. Try searching: "How do I track my order"
4. Tap on any question to expand the answer
5. Clear search to see all FAQs again

### Step 4: Submit a Support Ticket
1. Tap on **Contact Us**
2. Select a category (e.g., "Order Issue")
3. Enter subject: "Test ticket submission"
4. Enter message: "This is a test message to check if the ticket system works properly"
5. Tap **Submit Ticket**
6. Check for success notification
7. Go back to main hub

### Step 5: View Your Tickets
1. Tap on **My Tickets** quick action
2. You should see your test ticket
3. Tap on the ticket to view full details
4. Note the ticket ID, status, and timestamp
5. Try filtering by **Open** or **Closed**

### Step 6: Try Live Chat
1. Go back to main hub
2. Tap on **Live Chat**
3. Wait for welcome message from Support Bot
4. Type: "How do I track my order?"
5. Wait for auto-reply (1 second delay)
6. Try other keywords:
   - "payment issue"
   - "I want to become a seller"
   - "forgot password"
7. Each should trigger different auto-replies
8. Tap ⋮ menu > End Chat when done

### Step 7: Test Contact Methods
1. Go back to main hub
2. Scroll to "Other Ways to Reach Us"
3. **Hotline**: Tap to open phone dialer (if on mobile)
4. **Email**: Tap to open email app
5. **Facebook**: Tap to open Facebook (external browser)

### Step 8: Test Search
1. From main hub, type in search bar: "order"
2. Press Enter or search button
3. Should navigate to FAQ screen with search results
4. Try different searches

## 📱 What You Should See

### Main Hub Features:
✅ Clean green gradient header
✅ Search bar with placeholder
✅ 4 colorful quick action cards
✅ Badge on "My Tickets" showing open ticket count
✅ 4 popular topic cards with icons
✅ 3 contact method cards (phone, email, social)
✅ All cards are tappable with ripple effect

### FAQ Screen Features:
✅ Search bar at top
✅ Category filter chips (All, Orders, Payment, Seller, Account)
✅ List of expandable FAQ items
✅ Smooth expand/collapse animation
✅ "No results" state when search has no matches
✅ Clean white cards with shadows

### Contact Us Features:
✅ Gradient header with support icon
✅ 7 category pills to select from
✅ Selected category highlights in green
✅ Subject and message input fields
✅ Form validation (subject min 5, message min 20 chars)
✅ Info box with response time estimate
✅ Green submit button
✅ Loading indicator when submitting
✅ Success message and auto-close

### My Tickets Features:
✅ Filter tabs: All, Open, Closed
✅ Ticket cards showing:
  - Status badge (color-coded)
  - Category tag
  - Ticket ID (8 characters)
  - Subject (bold)
  - Message preview (2 lines)
  - Creation timestamp
  - Reply count (if any)
✅ Tap ticket to see full details in bottom sheet
✅ "No tickets" empty state
✅ Real-time updates (try submitting ticket in another tab)

### Live Chat Features:
✅ Chat header with "Support Team" subtitle
✅ Welcome message on first load
✅ Message bubbles (grey for support, green for you)
✅ Different avatar icons (agent vs user)
✅ Relative timestamps (Just now, 2m ago, etc.)
✅ Message input with send button
✅ Auto-scroll to latest message
✅ Auto-replies after 1 second
✅ Menu option to end chat

## 🎨 UI Elements to Notice

### Colors:
- **Green**: Primary color (buttons, selected states)
- **Orange**: Open ticket status
- **Blue**: Chat, info elements, in-progress status
- **Purple**: Contact category
- **Teal**: Tickets category
- **Red**: Badge counters, urgent items

### Icons:
- 💬 Live Chat: chat_bubble_outline
- ❓ FAQ: help_outline
- ✉️ Contact: email_outlined
- 📋 Tickets: history
- 📱 Phone: phone
- 📧 Email: email
- 📱 Social: facebook

### Animations:
- Card ripple effects on tap
- Smooth page transitions
- FAQ expand/collapse
- Auto-scroll in chat
- Loading spinners
- Bottom sheet slide up

## 🧪 Test Scenarios

### Scenario 1: New User Needs Help
1. User browses FAQ first
2. Can't find answer
3. Submits support ticket
4. Checks ticket status
5. Gets response (simulated)

### Scenario 2: Urgent Issue
1. User taps Live Chat
2. Describes issue
3. Gets instant auto-reply
4. Continues conversation
5. Issue resolved, ends chat

### Scenario 3: Follow-up on Ticket
1. User submitted ticket yesterday
2. Opens My Tickets
3. Finds specific ticket
4. Reads admin response
5. Replies if needed

### Scenario 4: Quick Answer
1. User has simple question
2. Searches FAQ
3. Finds exact answer
4. Problem solved in 10 seconds

## 🐛 Common Issues & Solutions

### Issue: "Please login to use live chat"
**Solution**: Make sure you're logged in. Go to Account > Login

### Issue: Can't submit ticket
**Solution**: Check that subject is 5+ chars and message is 20+ chars

### Issue: No tickets showing
**Solution**: Make sure you've submitted at least one ticket while logged in

### Issue: Chat not loading
**Solution**: Check internet connection and Firebase configuration

### Issue: Phone/Email links not working
**Solution**: 
- On emulator: May not work as expected
- On real device: Should open dialer/email app
- On web: May need browser permissions

## 📊 Firebase Data to Check

After testing, verify in Firebase Console:

### Collections Created:
1. **support_tickets**: Your test tickets
2. **chat_sessions**: Your chat sessions
3. **notifications**: Ticket submission notifications

### Example Ticket Document:
```
support_tickets/abc123xyz
  userId: "user_id_here"
  userName: "Your Name"
  userEmail: "your@email.com"
  category: "order"
  subject: "Test ticket"
  message: "Test message..."
  status: "open"
  priority: "normal"
  createdAt: [timestamp]
  responses: []
```

### Example Chat Session:
```
chat_sessions/xyz789abc
  userId: "user_id_here"
  status: "active"
  lastMessage: "Latest message..."
  
  messages/msg123
    text: "Hello!"
    senderId: "user_id"
    isSupport: false
    timestamp: [timestamp]
```

## ✅ Completion Checklist

Test all these features:
- [ ] Navigate to Help & Support from Account
- [ ] View main hub with all sections
- [ ] Search FAQs from main hub
- [ ] Browse FAQ categories
- [ ] Expand/collapse FAQ items
- [ ] Submit a support ticket
- [ ] View ticket in My Tickets
- [ ] Open ticket details
- [ ] Filter tickets (All/Open/Closed)
- [ ] Start live chat
- [ ] Send chat messages
- [ ] Receive auto-replies
- [ ] End chat session
- [ ] Test phone link
- [ ] Test email link
- [ ] Test social link
- [ ] Test popular topic shortcuts
- [ ] Verify badge count on My Tickets
- [ ] Check notifications after ticket submission

## 🎉 Success Criteria

Your Help & Support system is working if:
✅ All screens load without errors
✅ Forms validate properly
✅ Tickets are saved to Firebase
✅ Live chat messages appear in real-time
✅ Auto-replies work with keywords
✅ Ticket history shows submitted tickets
✅ Filters and search work correctly
✅ UI is smooth and responsive
✅ Navigation flows naturally
✅ Contact methods launch correctly

## 📝 Next Steps

After testing:
1. Customize FAQ content for your specific needs
2. Update contact information (phone, email, social)
3. Consider building admin panel to manage tickets
4. Add more sophisticated chatbot responses
5. Implement push notifications for ticket updates
6. Add analytics to track support metrics

Enjoy your new professional Help & Support system! 🚀
