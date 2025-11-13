-- Safety check: profiles without matching auth.users
select p.id, p.email
from public.profiles p
left join auth.users u on u.id = p.id
where u.id is null;

-- Abort FK add if above returns rows. Otherwise, add FK once.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.profiles p
    LEFT JOIN auth.users u ON u.id = p.id
    WHERE u.id IS NULL
  ) THEN
    RAISE EXCEPTION 'Cannot add FK: some profiles.id do not exist in auth.users. Fix those first.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND constraint_type = 'FOREIGN KEY'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_id_fk_auth_users
      FOREIGN KEY (id) REFERENCES auth.users(id)
      ON DELETE CASCADE;
  END IF;
END $$;

-- Helper: admin check based on profiles.role = 'admin'
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS boolean
LANGUAGE sql STABLE
AS $$
  SELECT COALESCE(
    (SELECT role = 'admin' FROM public.profiles WHERE id = auth.uid()),
    false
  );
$$;

-- Optional index for chat room sorting
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public' AND indexname = 'chat_rooms_last_message_at_idx'
  ) THEN
    CREATE INDEX chat_rooms_last_message_at_idx
      ON public.chat_rooms (last_message_at DESC NULLS LAST);
  END IF;
END $$;

-- Trigger: derive admin-ness via profiles.role
-- Add columns for last message preview if missing
ALTER TABLE public.chat_rooms
  ADD COLUMN IF NOT EXISTS last_message_content text,
  ADD COLUMN IF NOT EXISTS last_sender_id uuid; -- nullable by default

-- Ensure FK constraint on last_sender_id (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'chat_rooms_last_sender_id_fkey'
  ) THEN
    BEGIN
      ALTER TABLE public.chat_rooms
        ADD CONSTRAINT chat_rooms_last_sender_id_fkey
        FOREIGN KEY (last_sender_id) REFERENCES auth.users(id) ON DELETE SET NULL;
    EXCEPTION WHEN duplicate_object THEN
      -- race condition safety; ignore if created concurrently
      NULL;
    END;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.messages_after_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_is_admin boolean;
BEGIN
  SELECT (role = 'admin') INTO v_is_admin
  FROM public.profiles
  WHERE id = NEW.sender_id;

  -- Single write updating all metadata and unread counters
  UPDATE public.chat_rooms
     SET last_message_at      = NEW.created_at,
         last_message_content = NEW.content,
         last_sender_id       = NEW.sender_id,
         unread_customer      = CASE WHEN COALESCE(v_is_admin,false) THEN COALESCE(unread_customer,0)+1 ELSE unread_customer END,
         unread_admin         = CASE WHEN NOT COALESCE(v_is_admin,false) THEN COALESCE(unread_admin,0)+1 ELSE unread_admin END
   WHERE id = NEW.room_id;

  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'messages_after_insert_trigger'
  ) THEN
    CREATE TRIGGER messages_after_insert_trigger
    AFTER INSERT ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION public.messages_after_insert();
  END IF;
END $$;

-- RPC: mark room read for current participant (admin or customer)
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

  IF NOT v_is_admin AND v_customer_id <> auth.uid() THEN
    RAISE EXCEPTION 'Not allowed to mark this room read';
  END IF;

  IF v_is_admin THEN
    UPDATE public.chat_rooms SET unread_admin = 0 WHERE id = p_room_id;
  ELSE
    UPDATE public.chat_rooms SET unread_customer = 0 WHERE id = p_room_id AND customer_id = auth.uid();
  END IF;
END;
$$;

-- RLS enable (only if not already enabled in your setup)
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages   ENABLE ROW LEVEL SECURITY;

-- Minimal policies (only run if missing in your project)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='chat_rooms' AND policyname='chat_rooms_customer_select') THEN
    CREATE POLICY chat_rooms_customer_select ON public.chat_rooms
      FOR SELECT USING (auth.uid() = customer_id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='chat_rooms' AND policyname='chat_rooms_admin_select') THEN
    CREATE POLICY chat_rooms_admin_select ON public.chat_rooms
      FOR SELECT USING (public.is_admin_user());
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='chat_rooms' AND policyname='chat_rooms_customer_insert') THEN
    CREATE POLICY chat_rooms_customer_insert ON public.chat_rooms
      FOR INSERT WITH CHECK (auth.uid() = customer_id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='chat_rooms' AND policyname='chat_rooms_admin_update') THEN
    CREATE POLICY chat_rooms_admin_update ON public.chat_rooms
      FOR UPDATE USING (public.is_admin_user()) WITH CHECK (public.is_admin_user());
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='messages' AND policyname='messages_select') THEN
    CREATE POLICY messages_select ON public.messages
      FOR SELECT USING (
        EXISTS (
          SELECT 1 FROM public.chat_rooms r
          WHERE r.id = room_id
            AND (r.customer_id = auth.uid() OR public.is_admin_user())
        )
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='messages' AND policyname='messages_insert') THEN
    CREATE POLICY messages_insert ON public.messages
      FOR INSERT WITH CHECK (
        sender_id = auth.uid() AND EXISTS (
          SELECT 1 FROM public.chat_rooms r
          WHERE r.id = room_id
            AND (r.customer_id = auth.uid() OR public.is_admin_user())
        )
      );
  END IF;
END $$;

-- Realtime reminder: add `messages` to the `supabase` publication
-- Dashboard: Database -> Replication -> Publications -> supabase -> add `messages`

-- Idempotent publication setup and fixups
DO $$
BEGIN
  -- If a typo publication 'supabse' exists and 'supabase' does not, rename it
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabse')
     AND NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase') THEN
    EXECUTE 'ALTER PUBLICATION supabse RENAME TO supabase';
  END IF;

  -- Create the standard Supabase publication if missing
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase') THEN
    EXECUTE 'CREATE PUBLICATION supabase FOR TABLE NONE';
  END IF;
END $$;

-- Ensure messages is included in the publication (no-op if already present)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase' AND schemaname = 'public' AND tablename = 'messages'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase ADD TABLE public.messages';
  END IF;
END $$;
