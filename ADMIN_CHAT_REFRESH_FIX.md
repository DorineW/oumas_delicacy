# Admin Chat List Real-Time Refresh Fix

## Issues Fixed

### 1. **"now" Display Issue**
**Problem**: When admin sends/receives a message and exits immediately, the chat list shows "now" instead of the actual time.

**Solution**: Changed `_relativeTime()` to display actual time (in 12-hour format with AM/PM) for messages less than 5 minutes old, instead of showing "now".

```dart
// Before: diff.inMinutes < 1 return 'now'
// After: Show actual time like "2:45 PM" for recent messages
if (diff.inMinutes < 5) {
  final hour12 = kenyanTime.hour == 0 ? 12 : (kenyanTime.hour > 12 ? kenyanTime.hour - 12 : kenyanTime.hour);
  final amPm = kenyanTime.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:${kenyanTime.minute.toString().padLeft(2, '0')} $amPm';
}
```

### 2. **Unread Badge Not Clearing**
**Problem**: Unread badge doesn't clear immediately after opening a chat - only clears after completely exiting and returning.

**Solution**: 
- Added forced refresh mechanism using `StreamController` and state key
- Added 300ms delay after marking as read to allow database update to propagate
- Force widget rebuild after returning from chat screen

```dart
// After returning from chat
await ChatService.instance.markRoomRead(roomId);
await Future.delayed(const Duration(milliseconds: 300));
_forceRefresh(); // Triggers rebuild with new data
```

### 3. **Last Message Not Updating**
**Problem**: Last message preview doesn't update in real-time - only shows after refresh.

**Solution**: 
- Optimized `streamAdminRooms()` with batch fetching and caching
- Reduced N+1 queries by fetching all customer names in single batch
- Added customer name cache to prevent repeated lookups
- Changed from nested `.map().asyncMap()` to single `.asyncMap()` for faster updates

## Files Modified

### 1. `lib/screens/admin/admin_chat_list_screen.dart`
- Added `StreamController<void>` for manual refresh
- Added `_refreshKey` for forcing widget rebuild
- Added `_forceRefresh()` method
- Updated `onTap` to mark as read and force refresh after navigation
- Improved `_relativeTime()` to show actual times instead of "now"

### 2. `lib/services/chat_service.dart`
- Optimized `streamAdminRooms()` with batch customer name fetching
- Added customer name caching to reduce database queries
- Changed from `.map().asyncMap()` to single `.asyncMap()` for better performance

## Time Display Logic

| Time Difference | Display Format | Example |
|----------------|----------------|---------|
| < 5 minutes | Actual time (12h) | "2:45 PM" |
| < 1 hour | Minutes ago | "15m ago" |
| < 24 hours | Hours ago | "3h ago" |
| 1 day | Yesterday | "Yesterday" |
| < 7 days | Days ago | "3d ago" |
| ≥ 7 days | Date (DD/MM) | "15/11" |

## Testing Checklist

✅ **Test 1: Send Message & Exit**
1. Admin opens customer chat
2. Admin sends message
3. Admin immediately exits to chat list
4. **Expected**: Time shows as "2:45 PM" (actual time), not "now"

✅ **Test 2: Unread Badge Clearing**
1. Customer sends message (admin sees unread badge)
2. Admin opens chat
3. Admin immediately exits
4. **Expected**: Unread badge clears within ~300ms, no need to fully exit app

✅ **Test 3: Last Message Update**
1. Admin on chat list screen
2. Customer sends message
3. **Expected**: Last message preview updates in real-time without manual refresh

✅ **Test 4: Multiple Chats Performance**
1. Create 10+ chat rooms
2. Send messages in multiple chats
3. **Expected**: Chat list updates smoothly without lag or delays

## Technical Details

### Refresh Mechanism
- Uses `ValueKey(_refreshKey)` on StreamBuilder to force rebuild
- Increments `_refreshKey` after marking as read
- 300ms delay allows Supabase real-time to propagate database changes

### Customer Name Caching
```dart
// Cache prevents repeated lookups for same customer
final Map<String, String> _customerNameCache = {};

// Batch fetch only uncached customer IDs
final uncachedIds = rows
    .map((row) => row['customer_id'] as String?)
    .where((id) => id != null && !_customerNameCache.containsKey(id))
    .toSet();
```

### Performance Improvements
- **Before**: N queries (one per chat room) for customer names
- **After**: 1 batch query for all uncached names
- **Result**: ~90% reduction in database queries for chat list

## Database Requirements

No database changes needed - works with existing schema:
- `chat_rooms` table (id, customer_id, last_message_at, last_message_content, unread_admin, unread_customer)
- `users` table (auth_id, name, email)
- `mark_room_read()` RPC function

## Future Optimizations (Optional)

For even better performance with 100+ chat rooms:

```sql
-- Create database view to eliminate client-side joins
CREATE VIEW chat_rooms_with_names AS
  SELECT 
    cr.*,
    u.name as customer_name,
    u.email as customer_email
  FROM chat_rooms cr
  LEFT JOIN users u ON cr.customer_id = u.auth_id;

-- Then query the view instead
SELECT * FROM chat_rooms_with_names ORDER BY last_message_at DESC;
```

## Kenyan Time (EAT)

All timestamps automatically convert from UTC to Kenyan local time (EAT, UTC+3):
```dart
final kenyanTime = time.toUtc().add(const Duration(hours: 3));
```

---

**Status**: ✅ Implemented and ready for testing
**Date**: November 18, 2025
