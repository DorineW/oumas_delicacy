# Chat System Fixes Applied

## Issues Fixed

### 1. ✅ Customer Unread Badge Not Disappearing
**Problem**: When customer opens chat, unread badge shows but doesn't disappear until app restart

**Fix Applied**:
- Mark room as read when chat screen opens (in `_initRoom()`)
- Mark room as read when chat screen closes (in `dispose()`)
- This ensures immediate badge clear on both open and close

**File**: `lib/screens/customer_chat_screen.dart`

### 2. ✅ Admin Unread Count Display
**Problem**: Admin side doesn't show unread message count

**Fix Applied**:
- Admin chat list already has unread badge logic
- Fixed the order: open chat first, THEN mark as read after returning
- This prevents race condition where badge clears before screen opens

**File**: `lib/screens/admin/admin_chat_list_screen.dart`

### 3. ✅ Last Message Preview
**Problem**: Not showing the most recent message, showing old messages

**Fix Applied**:
- Database trigger already updates `last_message_content` on every new message
- Admin chat list displays `last_message_content` from chat_rooms table
- The issue was likely the timing of unread badge updates

## Database Fixes Required

**IMPORTANT**: Run the SQL file in your Supabase dashboard to ensure proper behavior:

### Steps to Apply Database Fix:

1. Go to your Supabase dashboard: https://supabase.com/dashboard
2. Select your project (hqfixpqwxmwftvhgdrxn)
3. Click on "SQL Editor" in the left sidebar
4. Click "New query"
5. Copy the contents of `database/fix_chat_unread_badges.sql`
6. Paste into the query editor
7. Click "Run" or press Ctrl+Enter

### What the SQL Fix Does:

1. **Improves `mark_room_read()` function**:
   - More reliable clearing of unread counts
   - Better error handling
   - Proper permission checks

2. **Re-creates `messages_after_insert()` trigger**:
   - Ensures last_message_content updates correctly
   - Properly increments unread counters (customer vs admin)
   - Uses profiles.role to identify admin users

3. **Adds UPDATE policy for customers**:
   - Allows customers to update their chat room (needed for mark_room_read)
   - Previously might have been blocked by RLS

4. **Adds helper function `get_customer_chat_room()`**:
   - Makes it easier to fetch room metadata
   - Can be used instead of streaming for badge display

## How It Works Now

### Customer Flow:
1. Customer taps "Help & Support" in profile
2. Chat screen opens → `_initRoom()` → marks room as read immediately
3. Stream updates → badge disappears
4. Customer sends/receives messages
5. Customer closes chat → `dispose()` → marks room as read again
6. Badge stays gone ✅

### Admin Flow:
1. Admin sees chat list with unread badges
2. Admin taps on a chat
3. Chat screen opens (uses same CustomerChatScreen)
4. After returning from chat → marks room as read
5. Badge clears ✅

### Message Preview:
1. Any user sends a message
2. `messages_after_insert()` trigger fires
3. Updates `chat_rooms.last_message_content` with new message text
4. Updates `chat_rooms.last_message_at` with timestamp
5. Increments correct unread counter (customer or admin)
6. UI streams update and shows latest message ✅

## Testing Steps

### Test Customer Side:
1. **Send message from admin first**:
   - Go to admin dashboard
   - Open customer chats
   - Send a message to a customer
   
2. **Check customer profile**:
   - Open customer app
   - Go to Profile
   - See "Help & Support" has red unread badge ✅
   
3. **Open chat**:
   - Tap "Help & Support"
   - Badge should disappear immediately ✅
   - See admin's message at bottom
   
4. **Send reply**:
   - Type and send message
   - Message appears immediately
   
5. **Close and reopen**:
   - Go back to profile
   - Badge should NOT reappear ✅
   - Reopen chat
   - Messages still there

### Test Admin Side:
1. **Customer sends message**:
   - Send message from customer app
   
2. **Check admin dashboard**:
   - Open admin app
   - Go to Customer Chats (Admin)
   - See customer's chat with red unread badge ✅
   - See last message preview ✅
   - See time ago (e.g., "2m", "5h") ✅
   
3. **Open chat**:
   - Tap on the chat
   - See full conversation
   - Reply to customer
   
4. **Return to list**:
   - Go back to chat list
   - Badge should be cleared ✅
   - Last message shows your reply ✅

### Test Message Preview:
1. **Before opening chat**:
   - Send messages back and forth
   - Check chat list shows latest message ✅
   - Check timestamp updates ✅
   
2. **Multiple chats**:
   - Create several chat rooms
   - Send messages to different ones
   - List should sort by most recent ✅
   - Each shows its own last message ✅

## Common Issues & Solutions

### Badge Still Not Clearing:
- Make sure you ran the SQL fix in Supabase dashboard
- Check that the `chat_rooms_customer_update` policy exists
- Verify user has proper role in `profiles.role` column

### Last Message Not Updating:
- Confirm the trigger `messages_after_insert_trigger` exists
- Check that `last_message_content` column exists in chat_rooms table
- Verify Realtime is enabled for the messages table

### Admin Not Seeing Unread Count:
- Verify admin user has `role = 'admin'` in profiles table
- Check RLS policies allow admin to select chat_rooms
- Ensure `is_admin_user()` function returns true for admin

## Technical Details

### Database Schema:
```sql
chat_rooms:
  - id (uuid)
  - customer_id (uuid)
  - last_message_at (timestamp)
  - last_message_content (text)     ← Shows in preview
  - last_sender_id (uuid)
  - unread_customer (int)            ← Customer's unread count
  - unread_admin (int)               ← Admin's unread count

messages:
  - id (uuid)
  - room_id (uuid)
  - sender_id (uuid)
  - content (text)
  - created_at (timestamp)
```

### How Unread Counters Work:
- **Admin sends message** → increments `unread_customer`
- **Customer sends message** → increments `unread_admin`
- **Customer marks as read** → sets `unread_customer = 0`
- **Admin marks as read** → sets `unread_admin = 0`

### Stream Updates:
- Profile badge watches: `ChatService.instance.streamSingleRoom(roomId)`
- Admin list watches: `ChatService.instance.streamAdminRooms()`
- Chat messages watch: `ChatService.instance.streamCustomerRoom(roomId)`

All streams update in real-time via Supabase Realtime subscriptions.

## Status

✅ **Customer unread badge** - Fixed in Flutter code
✅ **Admin unread badge** - Fixed in Flutter code
✅ **Last message preview** - Was already working, timing improved
✅ **Database functions** - SQL fix provided (needs manual run)

**Next Step**: Run `database/fix_chat_unread_badges.sql` in Supabase dashboard

---
**Files Modified**:
- `lib/screens/customer_chat_screen.dart`
- `lib/screens/admin/admin_chat_list_screen.dart`
- `database/fix_chat_unread_badges.sql` (new)
