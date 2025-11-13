-- Chat schema: chat_rooms, messages, and basic RLS policies

create extension if not exists "uuid-ossp";

create table if not exists public.chat_rooms (
  id uuid primary key default uuid_generate_v4(),
  customer_id uuid not null references auth.users(id) on delete cascade,
  admin_id uuid references auth.users(id) on delete set null,
  last_message_at timestamp with time zone,
  status text default 'open',
  unread_customer int default 0,
  unread_admin int default 0,
  created_at timestamp with time zone default now()
);

create table if not exists public.messages (
  id uuid primary key default uuid_generate_v4(),
  room_id uuid not null references public.chat_rooms(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  is_admin boolean not null default false,
  created_at timestamp with time zone default now()
);

create index if not exists messages_room_id_created_at_idx
  on public.messages (room_id, created_at desc);

alter table public.chat_rooms enable row level security;
alter table public.messages enable row level security;

-- Profiles is assumed to exist with is_admin boolean (id references auth.users)
-- Example policy helpers
create or replace function public.is_admin_user() returns boolean language sql stable as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

-- chat_rooms policies
create policy if not exists chat_rooms_customer_select on public.chat_rooms
  for select using (auth.uid() = customer_id);

create policy if not exists chat_rooms_admin_select on public.chat_rooms
  for select using (public.is_admin_user());

create policy if not exists chat_rooms_customer_insert on public.chat_rooms
  for insert with check (auth.uid() = customer_id);

create policy if not exists chat_rooms_admin_update on public.chat_rooms
  for update using (public.is_admin_user()) with check (public.is_admin_user());

-- messages policies
create policy if not exists messages_select on public.messages
  for select using (
    exists (
      select 1 from public.chat_rooms r
      where r.id = room_id
        and (r.customer_id = auth.uid() or public.is_admin_user())
    )
  );

create policy if not exists messages_insert on public.messages
  for insert with check (
    sender_id = auth.uid() and exists (
      select 1 from public.chat_rooms r
      where r.id = room_id
        and (r.customer_id = auth.uid() or public.is_admin_user())
    )
  );

-- Realtime: ensure messages are in the supabase publication
-- In the dashboard: Database -> Replication -> Publications -> supabase -> add messages
