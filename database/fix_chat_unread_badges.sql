-- Fix chat unread badge issues
-- This ensures unread badges clear properly and last messages display correctly

-- 1. Ensure the trigger correctly identifies admin users
-- The existing trigger relies on profiles.role = 'admin', let's verify it exists

-- 2. Add an RPC function to get customer's room with all metadata for the badge
CREATE OR REPLACE FUNCTION public.get_customer_chat_room()
RETURNS TABLE (
  id uuid,
  customer_id uuid,
  admin_id uuid,
  last_message_at timestamp with time zone,
  status text,
  unread_customer int,
  unread_admin int,
  created_at timestamp with time zone,
  last_message_content text,
  last_sender_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT cr.*
  FROM public.chat_rooms cr
  WHERE cr.customer_id = auth.uid()
  LIMIT 1;
END;
$$;

-- 3. Improve the mark_room_read function to be more reliable
CREATE OR REPLACE FUNCTION public.mark_room_read(p_room_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin boolean := public.is_admin_user();
  v_customer_id uuid;
BEGIN
  SELECT customer_id INTO v_customer_id
  FROM public.chat_rooms
  WHERE id = p_room_id;

  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Room % not found', p_room_id;
  END IF;

  -- Allow both admin and the room's customer to mark as read
  IF NOT v_is_admin AND v_customer_id <> auth.uid() THEN
    RAISE EXCEPTION 'Not allowed to mark this room read';
  END IF;

  -- Update the appropriate unread counter
  IF v_is_admin THEN
    UPDATE public.chat_rooms 
    SET unread_admin = 0 
    WHERE id = p_room_id;
  ELSE
    UPDATE public.chat_rooms 
    SET unread_customer = 0 
    WHERE id = p_room_id AND customer_id = auth.uid();
  END IF;
  
  -- Log for debugging (optional, comment out in production)
  RAISE NOTICE 'mark_room_read: room=%, is_admin=%, customer=%, caller=%', 
    p_room_id, v_is_admin, v_customer_id, auth.uid();
END;
$$;

-- 4. Verify the trigger is correctly updating last_message fields
-- Re-create the trigger function to ensure it's working properly
CREATE OR REPLACE FUNCTION public.messages_after_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_is_admin boolean := false;
BEGIN
  -- Check if sender is admin based on profiles.role
  SELECT COALESCE((role = 'admin'), false) INTO v_is_admin
  FROM public.profiles
  WHERE id = NEW.sender_id;

  -- Update chat room with new message metadata and increment unread counters
  UPDATE public.chat_rooms
  SET 
    last_message_at = NEW.created_at,
    last_message_content = NEW.content,
    last_sender_id = NEW.sender_id,
    -- If admin sent message, increment customer's unread count
    unread_customer = CASE 
      WHEN v_is_admin THEN COALESCE(unread_customer, 0) + 1 
      ELSE unread_customer 
    END,
    -- If customer sent message, increment admin's unread count
    unread_admin = CASE 
      WHEN NOT v_is_admin THEN COALESCE(unread_admin, 0) + 1 
      ELSE unread_admin 
    END
  WHERE id = NEW.room_id;

  RETURN NEW;
END;
$$;

-- 5. Ensure the trigger exists
DROP TRIGGER IF EXISTS messages_after_insert_trigger ON public.messages;
CREATE TRIGGER messages_after_insert_trigger
AFTER INSERT ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.messages_after_insert();

-- 6. Add a policy to allow customers to update their chat room (to mark as read)
DROP POLICY IF EXISTS chat_rooms_customer_update ON public.chat_rooms;
CREATE POLICY chat_rooms_customer_update ON public.chat_rooms
  FOR UPDATE 
  USING (auth.uid() = customer_id OR public.is_admin_user())
  WITH CHECK (auth.uid() = customer_id OR public.is_admin_user());

-- 7. Test query to check unread counts (run this to verify)
-- SELECT 
--   cr.id,
--   cr.customer_id,
--   u.name as customer_name,
--   cr.last_message_content,
--   cr.last_message_at,
--   cr.unread_customer,
--   cr.unread_admin
-- FROM chat_rooms cr
-- LEFT JOIN profiles u ON u.id = cr.customer_id
-- ORDER BY cr.last_message_at DESC NULLS LAST;
