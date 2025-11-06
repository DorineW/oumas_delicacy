-- Drop and recreate the trigger function to ensure it only uses auth_id
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Recreate the function (no references to users.id)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  meta JSONB;
  user_name TEXT;
  user_phone TEXT;
  user_role TEXT;
BEGIN
  meta := NEW.raw_user_meta_data;

  -- Extract metadata safely
  user_name := COALESCE(meta->>'name', '');
  user_phone := COALESCE(meta->>'phone', NULL);
  user_role := COALESCE(meta->>'role', 'customer');

  -- Upsert into public.users using ONLY auth_id (no id column)
  INSERT INTO public.users (auth_id, email, name, phone, role, created_at, updated_at)
  VALUES (NEW.id, NEW.email, user_name, user_phone, user_role, NOW(), NOW())
  ON CONFLICT (auth_id)
  DO UPDATE SET
    email = EXCLUDED.email,
    name = COALESCE(NULLIF(EXCLUDED.name, ''), public.users.name),
    phone = COALESCE(EXCLUDED.phone, public.users.phone),
    role = COALESCE(EXCLUDED.role, public.users.role),
    updated_at = NOW();

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'handle_new_user failed for %: %', NEW.id, SQLERRM;
  RETURN NEW;  -- allow auth user to be created even if profile insert fails
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Recreate the trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Verify no 'id' column exists in public.users
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='users' AND column_name='id'
  ) THEN
    RAISE EXCEPTION 'public.users still has an id column. Drop it: ALTER TABLE public.users DROP COLUMN id;';
  END IF;
END
$$;
