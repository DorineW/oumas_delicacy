


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."handle_new_auth_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  resolved_name text;
BEGIN
  -- Resolve name: prefer raw_user_meta_data->>'name', else concat first_name/last_name, else NULL
  resolved_name := NULLIF(NEW.raw_user_meta_data ->> 'name', '');
  IF resolved_name IS NULL THEN
    IF (NEW.raw_user_meta_data ? 'first_name') OR (NEW.raw_user_meta_data ? 'last_name') THEN
      resolved_name := trim(
        COALESCE(NEW.raw_user_meta_data ->> 'first_name', '') || ' ' ||
        COALESCE(NEW.raw_user_meta_data ->> 'last_name', '')
      );
      IF resolved_name = '' THEN
        resolved_name := NULL;
      END IF;
    END IF;
  END IF;

  -- Optional debug logging (uncomment during testing)
  -- RAISE NOTICE 'Creating profile for auth.user % (email=%)', NEW.id, NEW.email;

  -- Insert into public.users only if a profile doesn't already exist
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE auth_id = NEW.id) THEN
    INSERT INTO public.users (auth_id, email, name, phone, created_at)
    VALUES (
      NEW.id,
      NEW.email,
      resolved_name,
      NULLIF(NEW.raw_user_meta_data ->> 'phone', ''),
      now()
    );
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_auth_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
  RAISE LOG 'handle_new_user failed: %', SQLERRM;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."profiles_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  DELETE FROM public.users WHERE auth_id = OLD.id;
  RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."profiles_delete"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."profiles_insert"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.users (auth_id, email, name, phone, role)
  VALUES (NEW.id, NEW.email, NEW.name, NEW.phone, NEW.role)
  ON CONFLICT (auth_id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    phone = EXCLUDED.phone,
    role = EXCLUDED.role;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."profiles_insert"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."profiles_update"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE public.users SET
    email = NEW.email,
    name = NEW.name,
    phone = NEW.phone,
    role = NEW.role
  WHERE auth_id = OLD.id;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."profiles_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_auth_id"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF NEW.auth_id IS NULL THEN
    NEW.auth_id := (SELECT auth.uid());
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_auth_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_order_timestamps"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.status = 'delivered' AND (OLD.status IS DISTINCT FROM 'delivered' OR OLD.delivered_at IS NULL) THEN
      NEW.delivered_at = COALESCE(NEW.delivered_at, NOW());
    END IF;
    IF NEW.status = 'cancelled' AND (OLD.status IS DISTINCT FROM 'cancelled' OR OLD.cancelled_at IS NULL) THEN
      NEW.cancelled_at = COALESCE(NEW.cancelled_at, NOW());
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_order_timestamps"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_user_email_on_update"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  UPDATE public.users
     SET email = NEW.email, updated_at = NOW()
   WHERE auth_id = NEW.id;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_user_email_on_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."favorites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_auth_id" "uuid" NOT NULL,
    "product_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."favorites" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid",
    "name" "text" NOT NULL,
    "category" "text",
    "quantity" numeric DEFAULT 0 NOT NULL,
    "unit" "text",
    "low_stock_threshold" numeric DEFAULT 0,
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."inventory_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."locations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_auth_id" "uuid",
    "name" "text",
    "address" "jsonb",
    "lat" numeric,
    "lon" numeric,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."locations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."menu_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid",
    "name" "text" NOT NULL,
    "description" "text",
    "price" numeric(12,2) DEFAULT 0 NOT NULL,
    "available" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "category" "text" DEFAULT 'Main Course'::"text" NOT NULL,
    "meal_weight" "text" DEFAULT 'Medium'::"text" NOT NULL,
    "image_url" "text",
    CONSTRAINT "meal_weight_check" CHECK (("meal_weight" = ANY (ARRAY['Light'::"text", 'Medium'::"text", 'Heavy'::"text"])))
);


ALTER TABLE "public"."menu_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_auth_id" "uuid",
    "type" "text",
    "payload" "jsonb",
    "seen" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."order_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "product_id" "uuid",
    "inventory_item_id" "uuid",
    "name" "text" NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "unit_price" numeric(12,2) DEFAULT 0 NOT NULL,
    "total_price" numeric(12,2) DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."order_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_auth_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "subtotal" numeric(12,2) DEFAULT 0 NOT NULL,
    "delivery_fee" numeric(12,2) DEFAULT 0 NOT NULL,
    "tax" numeric(12,2) DEFAULT 0 NOT NULL,
    "total" numeric(12,2) DEFAULT 0 NOT NULL,
    "delivery_address" "jsonb",
    "placed_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "delivered_at" timestamp with time zone,
    "cancelled_at" timestamp with time zone
);


ALTER TABLE "public"."orders" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."order_statistics" AS
 SELECT "date"("placed_at") AS "order_day",
    ("count"(*))::integer AS "total_orders",
    COALESCE("sum"("total"), (0)::numeric) AS "total_revenue",
        CASE
            WHEN ("count"(*) = 0) THEN (0)::numeric
            ELSE "avg"("total")
        END AS "avg_order_value",
    ("count"(
        CASE
            WHEN ("status" = 'delivered'::"text") THEN 1
            ELSE NULL::integer
        END))::integer AS "completed_orders",
    ("count"(
        CASE
            WHEN ("status" = 'cancelled'::"text") THEN 1
            ELSE NULL::integer
        END))::integer AS "cancelled_orders"
   FROM "public"."orders" "o"
  GROUP BY ("date"("placed_at"))
  ORDER BY ("date"("placed_at")) DESC;


ALTER VIEW "public"."order_statistics" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payment_methods" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_auth_id" "uuid" NOT NULL,
    "provider" "text" NOT NULL,
    "provider_customer_id" "text",
    "provider_method_id" "text",
    "card_last4" "text",
    "card_brand" "text",
    "exp_month" integer,
    "exp_year" integer,
    "is_default" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."payment_methods" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_auth_id" "uuid",
    "product_id" "uuid",
    "rating" smallint,
    "body" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "reviews_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."reviews" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."popular_menu_items" AS
 SELECT "oi"."name" AS "item_name",
    ("count"(*))::integer AS "order_count",
    COALESCE("sum"("oi"."quantity"), (0)::bigint) AS "total_quantity_sold",
    COALESCE("sum"(("oi"."unit_price" * ("oi"."quantity")::numeric)), (0)::numeric) AS "total_revenue",
    "round"(COALESCE("avg"("r"."rating"), (0)::numeric), 2) AS "avg_rating",
    ("count"("r"."id"))::integer AS "rating_count"
   FROM (("public"."order_items" "oi"
     JOIN "public"."orders" "o" ON (("oi"."order_id" = "o"."id")))
     LEFT JOIN "public"."reviews" "r" ON (("oi"."product_id" = "r"."product_id")))
  WHERE ("o"."status" = 'delivered'::"text")
  GROUP BY "oi"."name"
  ORDER BY COALESCE("sum"("oi"."quantity"), (0)::bigint) DESC;


ALTER VIEW "public"."popular_menu_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "price" numeric(10,2) NOT NULL,
    "category" "text" NOT NULL,
    "description" "text" DEFAULT ''::"text",
    "available" boolean DEFAULT true NOT NULL,
    "image" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "auth_id" "uuid" NOT NULL,
    "email" "text",
    "name" "text",
    "phone" "text",
    "role" "text" DEFAULT 'customer'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."users" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."profiles" AS
 SELECT "auth_id" AS "id",
    "email",
    "name",
    "phone",
    "role"
   FROM "public"."users";


ALTER VIEW "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."rider_earnings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "rider_id" "uuid" NOT NULL,
    "order_id" "uuid",
    "amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "earned_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."rider_earnings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."riders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "auth_id" "uuid",
    "name" "text",
    "phone" "text",
    "vehicle" "text",
    "is_available" boolean DEFAULT true NOT NULL,
    "last_seen_at" timestamp with time zone,
    "location_lat" numeric(10,7),
    "location_lon" numeric(10,7),
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."riders" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."rider_performance" AS
 SELECT "r"."auth_id" AS "rider_id",
    "r"."name" AS "rider_name",
    (COALESCE("count"(DISTINCT "re"."order_id"), (0)::bigint))::integer AS "total_deliveries",
    COALESCE("sum"("re"."amount"), (0)::numeric) AS "total_earnings",
    COALESCE("sum"("re"."amount"), (0)::numeric) AS "total_value_delivered",
    (COALESCE("sum"(
        CASE
            WHEN ("o"."status" = 'delivered'::"text") THEN 1
            ELSE 0
        END), (0)::bigint))::integer AS "successful_deliveries"
   FROM (("public"."riders" "r"
     LEFT JOIN "public"."rider_earnings" "re" ON (("r"."auth_id" = "re"."rider_id")))
     LEFT JOIN "public"."orders" "o" ON (("re"."order_id" = "o"."id")))
  GROUP BY "r"."auth_id", "r"."name"
  ORDER BY ((COALESCE("count"(DISTINCT "re"."order_id"), (0)::bigint))::integer) DESC;


ALTER VIEW "public"."rider_performance" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stock_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "inventory_item_id" "uuid" NOT NULL,
    "change" numeric NOT NULL,
    "reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."stock_history" OWNER TO "postgres";


ALTER TABLE ONLY "public"."favorites"
    ADD CONSTRAINT "favorites_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."favorites"
    ADD CONSTRAINT "favorites_user_auth_id_product_id_key" UNIQUE ("user_auth_id", "product_id");



ALTER TABLE ONLY "public"."inventory_items"
    ADD CONSTRAINT "inventory_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."locations"
    ADD CONSTRAINT "locations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."menu_items"
    ADD CONSTRAINT "menu_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payment_methods"
    ADD CONSTRAINT "payment_methods_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "profiles_auth_id_unique" UNIQUE ("auth_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("auth_id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."rider_earnings"
    ADD CONSTRAINT "rider_earnings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."riders"
    ADD CONSTRAINT "riders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stock_history"
    ADD CONSTRAINT "stock_history_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_favorites_user_auth" ON "public"."favorites" USING "btree" ("user_auth_id");



CREATE INDEX "idx_favorites_user_auth_id" ON "public"."favorites" USING "btree" ("user_auth_id");



CREATE INDEX "idx_inventory_items_product_id" ON "public"."inventory_items" USING "btree" ("product_id");



CREATE INDEX "idx_locations_lat_lon" ON "public"."locations" USING "btree" ("lat", "lon");



CREATE INDEX "idx_locations_owner_auth" ON "public"."locations" USING "btree" ("owner_auth_id");



CREATE INDEX "idx_locations_owner_auth_id" ON "public"."locations" USING "btree" ("owner_auth_id");



CREATE INDEX "idx_menu_items_category" ON "public"."menu_items" USING "btree" ("category");



CREATE INDEX "idx_menu_items_product" ON "public"."menu_items" USING "btree" ("product_id");



CREATE INDEX "idx_notifications_seen" ON "public"."notifications" USING "btree" ("seen");



CREATE INDEX "idx_notifications_user_auth" ON "public"."notifications" USING "btree" ("user_auth_id");



CREATE INDEX "idx_notifications_user_auth_id" ON "public"."notifications" USING "btree" ("user_auth_id");



CREATE INDEX "idx_order_items_order_id" ON "public"."order_items" USING "btree" ("order_id");



CREATE INDEX "idx_order_items_product_id" ON "public"."order_items" USING "btree" ("product_id");



CREATE INDEX "idx_orders_placed_at" ON "public"."orders" USING "btree" ("placed_at");



CREATE INDEX "idx_orders_status" ON "public"."orders" USING "btree" ("status");



CREATE INDEX "idx_orders_user_auth" ON "public"."orders" USING "btree" ("user_auth_id");



CREATE INDEX "idx_orders_user_auth_id" ON "public"."orders" USING "btree" ("user_auth_id");



CREATE INDEX "idx_payment_methods_user_auth_default" ON "public"."payment_methods" USING "btree" ("user_auth_id", "is_default");



CREATE INDEX "idx_payment_methods_user_auth_id" ON "public"."payment_methods" USING "btree" ("user_auth_id");



CREATE INDEX "idx_products_available" ON "public"."products" USING "btree" ("available");



CREATE INDEX "idx_products_category" ON "public"."products" USING "btree" ("category");



CREATE INDEX "idx_profiles_auth_id" ON "public"."users" USING "btree" ("auth_id");



CREATE INDEX "idx_profiles_email" ON "public"."users" USING "btree" ("email");



CREATE INDEX "idx_reviews_product" ON "public"."reviews" USING "btree" ("product_id");



CREATE INDEX "idx_reviews_product_id" ON "public"."reviews" USING "btree" ("product_id");



CREATE INDEX "idx_reviews_user_auth" ON "public"."reviews" USING "btree" ("user_auth_id");



CREATE INDEX "idx_reviews_user_auth_id" ON "public"."reviews" USING "btree" ("user_auth_id");



CREATE INDEX "idx_rider_earnings_rider" ON "public"."rider_earnings" USING "btree" ("rider_id");



CREATE INDEX "idx_riders_auth_id" ON "public"."riders" USING "btree" ("auth_id");



CREATE INDEX "idx_riders_is_available" ON "public"."riders" USING "btree" ("is_available");



CREATE INDEX "idx_stock_history_inventory_item" ON "public"."stock_history" USING "btree" ("inventory_item_id");



CREATE OR REPLACE TRIGGER "profiles_delete_trig" INSTEAD OF DELETE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."profiles_delete"();



CREATE OR REPLACE TRIGGER "profiles_insert_trig" INSTEAD OF INSERT ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."profiles_insert"();



CREATE OR REPLACE TRIGGER "profiles_update_trig" INSTEAD OF UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."profiles_update"();



CREATE OR REPLACE TRIGGER "set_auth_id_trigger" BEFORE INSERT ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."set_auth_id"();



CREATE OR REPLACE TRIGGER "set_updated_at_trigger" BEFORE UPDATE ON "public"."favorites" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at_trigger" BEFORE UPDATE ON "public"."inventory_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at_trigger" BEFORE UPDATE ON "public"."locations" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at_trigger" BEFORE UPDATE ON "public"."menu_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at_trigger" BEFORE UPDATE ON "public"."notifications" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at_trigger" BEFORE UPDATE ON "public"."order_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at_trigger" BEFORE UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at_trigger" BEFORE UPDATE ON "public"."payment_methods" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at_trigger" BEFORE UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at_trigger" BEFORE UPDATE ON "public"."reviews" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at_trigger" BEFORE UPDATE ON "public"."rider_earnings" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at_trigger" BEFORE UPDATE ON "public"."riders" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at_trigger" BEFORE UPDATE ON "public"."stock_history" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_inventory_items_updated_at" BEFORE UPDATE ON "public"."inventory_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_order_timestamps" BEFORE UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."set_order_timestamps"();



CREATE OR REPLACE TRIGGER "trg_orders_updated_at" BEFORE UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "update_products_updated_at" BEFORE UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_profiles_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."favorites"
    ADD CONSTRAINT "favorites_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."favorites"
    ADD CONSTRAINT "favorites_user_auth_id_fkey" FOREIGN KEY ("user_auth_id") REFERENCES "public"."users"("auth_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."locations"
    ADD CONSTRAINT "fk_locations_owner_user_auth" FOREIGN KEY ("owner_auth_id") REFERENCES "public"."users"("auth_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "fk_orders_user_auth" FOREIGN KEY ("user_auth_id") REFERENCES "public"."users"("auth_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."inventory_items"
    ADD CONSTRAINT "inventory_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."menu_items"
    ADD CONSTRAINT "menu_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_auth_id_fkey" FOREIGN KEY ("user_auth_id") REFERENCES "public"."users"("auth_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_inventory_item_id_fkey" FOREIGN KEY ("inventory_item_id") REFERENCES "public"."inventory_items"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."payment_methods"
    ADD CONSTRAINT "payment_methods_user_auth_id_fkey" FOREIGN KEY ("user_auth_id") REFERENCES "public"."users"("auth_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "profiles_auth_id_fkey" FOREIGN KEY ("auth_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_user_auth_id_fkey" FOREIGN KEY ("user_auth_id") REFERENCES "public"."users"("auth_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."rider_earnings"
    ADD CONSTRAINT "rider_earnings_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."rider_earnings"
    ADD CONSTRAINT "rider_earnings_rider_id_fkey" FOREIGN KEY ("rider_id") REFERENCES "public"."riders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."riders"
    ADD CONSTRAINT "riders_auth_id_fkey" FOREIGN KEY ("auth_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."stock_history"
    ADD CONSTRAINT "stock_history_inventory_item_id_fkey" FOREIGN KEY ("inventory_item_id") REFERENCES "public"."inventory_items"("id") ON DELETE CASCADE;



CREATE POLICY "Admins can manage riders" ON "public"."riders" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."auth_id" = "auth"."uid"()) AND ("users"."role" = 'admin'::"text")))));



CREATE POLICY "Allow public read access to menu items" ON "public"."menu_items" FOR SELECT USING (true);



CREATE POLICY "Anyone can view inventory" ON "public"."inventory_items" FOR SELECT USING (true);



CREATE POLICY "Anyone can view products" ON "public"."products" FOR SELECT USING (true);



CREATE POLICY "Only admins can modify inventory" ON "public"."inventory_items" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."auth_id" = "auth"."uid"()) AND ("users"."role" = 'admin'::"text")))));



CREATE POLICY "Only admins can modify products" ON "public"."products" USING ((EXISTS ( SELECT 1
   FROM "public"."users"
  WHERE (("users"."auth_id" = "auth"."uid"()) AND ("users"."role" = 'admin'::"text")))));



CREATE POLICY "Riders can update own profile" ON "public"."riders" FOR UPDATE USING (("auth"."uid"() = "auth_id"));



CREATE POLICY "Riders can view own profile" ON "public"."riders" FOR SELECT USING (("auth"."uid"() = "auth_id"));



CREATE POLICY "Users Insert Own" ON "public"."users" FOR INSERT WITH CHECK (("auth_id" = "auth"."uid"()));



CREATE POLICY "Users Select Own" ON "public"."users" FOR SELECT USING (("auth_id" = "auth"."uid"()));



CREATE POLICY "Users Service Role All" ON "public"."users" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Users Update Own" ON "public"."users" FOR UPDATE USING (("auth_id" = "auth"."uid"())) WITH CHECK (("auth_id" = "auth"."uid"()));



ALTER TABLE "public"."inventory_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notifications_insert_for_user" ON "public"."notifications" FOR INSERT TO "authenticated" WITH CHECK (("user_auth_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "notifications_select_own" ON "public"."notifications" FOR SELECT TO "authenticated" USING (("user_auth_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "orders_insert_own" ON "public"."orders" FOR INSERT TO "authenticated" WITH CHECK (("user_auth_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "orders_select_own" ON "public"."orders" FOR SELECT TO "authenticated" USING (("user_auth_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."payment_methods" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "payment_methods_insert" ON "public"."payment_methods" FOR INSERT TO "authenticated" WITH CHECK (("user_auth_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "payment_methods_select" ON "public"."payment_methods" FOR SELECT TO "authenticated" USING (("user_auth_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."riders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users_insert_own" ON "public"."users" FOR INSERT TO "authenticated" WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "auth_id") OR (("auth_id" IS NULL) AND (( SELECT "auth"."uid"() AS "uid") IS NOT NULL))));



CREATE POLICY "users_insert_self" ON "public"."users" FOR INSERT TO "authenticated" WITH CHECK (("auth_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "users_select_own" ON "public"."users" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "auth_id"));



CREATE POLICY "users_update_own" ON "public"."users" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "auth_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "auth_id"));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."notifications";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."profiles_delete"() TO "anon";
GRANT ALL ON FUNCTION "public"."profiles_delete"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."profiles_delete"() TO "service_role";



GRANT ALL ON FUNCTION "public"."profiles_insert"() TO "anon";
GRANT ALL ON FUNCTION "public"."profiles_insert"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."profiles_insert"() TO "service_role";



GRANT ALL ON FUNCTION "public"."profiles_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."profiles_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."profiles_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_auth_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_order_timestamps"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_order_timestamps"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_order_timestamps"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_user_email_on_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_user_email_on_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_user_email_on_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";


















GRANT ALL ON TABLE "public"."favorites" TO "anon";
GRANT ALL ON TABLE "public"."favorites" TO "authenticated";
GRANT ALL ON TABLE "public"."favorites" TO "service_role";



GRANT ALL ON TABLE "public"."inventory_items" TO "anon";
GRANT ALL ON TABLE "public"."inventory_items" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_items" TO "service_role";



GRANT ALL ON TABLE "public"."locations" TO "anon";
GRANT ALL ON TABLE "public"."locations" TO "authenticated";
GRANT ALL ON TABLE "public"."locations" TO "service_role";



GRANT ALL ON TABLE "public"."menu_items" TO "anon";
GRANT ALL ON TABLE "public"."menu_items" TO "authenticated";
GRANT ALL ON TABLE "public"."menu_items" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."order_items" TO "anon";
GRANT ALL ON TABLE "public"."order_items" TO "authenticated";
GRANT ALL ON TABLE "public"."order_items" TO "service_role";



GRANT ALL ON TABLE "public"."orders" TO "anon";
GRANT ALL ON TABLE "public"."orders" TO "authenticated";
GRANT ALL ON TABLE "public"."orders" TO "service_role";



GRANT ALL ON TABLE "public"."order_statistics" TO "anon";
GRANT ALL ON TABLE "public"."order_statistics" TO "authenticated";
GRANT ALL ON TABLE "public"."order_statistics" TO "service_role";



GRANT ALL ON TABLE "public"."payment_methods" TO "anon";
GRANT ALL ON TABLE "public"."payment_methods" TO "authenticated";
GRANT ALL ON TABLE "public"."payment_methods" TO "service_role";



GRANT ALL ON TABLE "public"."reviews" TO "anon";
GRANT ALL ON TABLE "public"."reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."reviews" TO "service_role";



GRANT ALL ON TABLE "public"."popular_menu_items" TO "anon";
GRANT ALL ON TABLE "public"."popular_menu_items" TO "authenticated";
GRANT ALL ON TABLE "public"."popular_menu_items" TO "service_role";



GRANT ALL ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."rider_earnings" TO "anon";
GRANT ALL ON TABLE "public"."rider_earnings" TO "authenticated";
GRANT ALL ON TABLE "public"."rider_earnings" TO "service_role";



GRANT ALL ON TABLE "public"."riders" TO "anon";
GRANT ALL ON TABLE "public"."riders" TO "authenticated";
GRANT ALL ON TABLE "public"."riders" TO "service_role";



GRANT ALL ON TABLE "public"."rider_performance" TO "anon";
GRANT ALL ON TABLE "public"."rider_performance" TO "authenticated";
GRANT ALL ON TABLE "public"."rider_performance" TO "service_role";



GRANT ALL ON TABLE "public"."stock_history" TO "anon";
GRANT ALL ON TABLE "public"."stock_history" TO "authenticated";
GRANT ALL ON TABLE "public"."stock_history" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































drop extension if exists "pg_net";

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER on_auth_user_updated AFTER UPDATE OF email ON auth.users FOR EACH ROW EXECUTE FUNCTION public.sync_user_email_on_update();


