-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS auth_user_created_trigger ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;

DROP FUNCTION IF EXISTS public.handle_auth_user_created();
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.sync_user_email_on_update();

-- Recreate the single unified trigger function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  meta JSONB;
  user_name TEXT;
  user_phone TEXT;
  user_role TEXT;
BEGIN
  meta := NEW.raw_user_meta_data;

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
  RAISE LOG 'handle_new_user failed for auth.users.id=%: %', NEW.id, SQLERRM;
  RETURN NEW;  -- allow auth user to be created even if profile insert fails
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Recreate the trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Recreate email sync trigger
CREATE OR REPLACE FUNCTION public.sync_user_email_on_update()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.users
     SET email = NEW.email,
         updated_at = NOW()
   WHERE auth_id = NEW.id;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'sync_user_email_on_update failed for auth.users.id=%: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER on_auth_user_updated
  AFTER UPDATE OF email ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.sync_user_email_on_update();

-- Verify no lingering references to users.id
DO $$
DECLARE
  bad_funcs TEXT;
BEGIN
  SELECT string_agg(p.proname, ', ')
    INTO bad_funcs
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
   WHERE p.prosrc ILIKE '%users.id%'
     AND n.nspname = 'public';

  IF bad_funcs IS NOT NULL THEN
    RAISE WARNING 'Functions still reference users.id: %', bad_funcs;
  END IF;
END
$$;
