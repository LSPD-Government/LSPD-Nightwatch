-- LSPD Nightwatch shared database setup
-- Run this entire file once in Supabase SQL Editor for project yxnzhhlribtiqhtqfoky.

create extension if not exists pgcrypto;

create table if not exists public.nightwatch_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  display_name text not null default 'Detective',
  rank text not null default 'Detective Division',
  callsign text not null default '',
  assignment text not null default 'Detectives',
  status text not null default 'Active',
  created_at timestamptz not null default now()
);

create table if not exists public.nightwatch_records (
  id uuid primary key default gen_random_uuid(),
  record_type text not null check (record_type in ('cases','warrants','rico','corruption','suspects','gangs','intelligence')),
  data jsonb not null default '{}'::jsonb,
  created_by uuid not null references auth.users(id),
  author text not null default 'Detective',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.nightwatch_record_members (
  record_id uuid not null references public.nightwatch_records(id) on delete cascade,
  user_id uuid not null references public.nightwatch_profiles(id) on delete cascade,
  added_by uuid not null references auth.users(id),
  added_at timestamptz not null default now(),
  primary key (record_id,user_id)
);

create index if not exists nightwatch_records_type_created_idx on public.nightwatch_records(record_type, created_at desc);
create index if not exists nightwatch_record_members_user_idx on public.nightwatch_record_members(user_id);

create or replace function public.nightwatch_can_access_record(record_uuid uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.nightwatch_records r
    where r.id = record_uuid
      and (r.created_by = auth.uid()
        or exists (select 1 from public.nightwatch_record_members m where m.record_id = r.id and m.user_id = auth.uid()))
  );
$$;

create or replace function public.nightwatch_is_record_owner(record_uuid uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.nightwatch_records r where r.id = record_uuid and r.created_by = auth.uid());
$$;

create or replace function public.nightwatch_new_profile()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.nightwatch_profiles(id,email,display_name)
  values (new.id, coalesce(new.email,''), coalesce(new.raw_user_meta_data->>'display_name', split_part(coalesce(new.email,'Detective'),'@',1)))
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists nightwatch_auth_user_created on auth.users;
create trigger nightwatch_auth_user_created after insert on auth.users
for each row execute procedure public.nightwatch_new_profile();

insert into public.nightwatch_profiles(id,email,display_name)
select id, coalesce(email,''), coalesce(raw_user_meta_data->>'display_name', split_part(coalesce(email,'Detective'),'@',1))
from auth.users
on conflict (id) do update set email=excluded.email;

alter table public.nightwatch_profiles enable row level security;
alter table public.nightwatch_records enable row level security;
alter table public.nightwatch_record_members enable row level security;

drop policy if exists "Nightwatch profiles visible to signed-in officers" on public.nightwatch_profiles;
create policy "Nightwatch profiles visible to signed-in officers"
on public.nightwatch_profiles for select to authenticated using (true);

drop policy if exists "Officers update their own profile" on public.nightwatch_profiles;
create policy "Officers update their own profile"
on public.nightwatch_profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "Officers read shared and assigned records" on public.nightwatch_records;
create policy "Officers read shared and assigned records"
on public.nightwatch_records for select to authenticated
using (record_type not in ('rico','corruption') or public.nightwatch_can_access_record(id));

drop policy if exists "Officers create records as themselves" on public.nightwatch_records;
create policy "Officers create records as themselves"
on public.nightwatch_records for insert to authenticated
with check (created_by = auth.uid());

drop policy if exists "Creators and assigned investigators update records" on public.nightwatch_records;
create policy "Creators and assigned investigators update records"
on public.nightwatch_records for update to authenticated
using (created_by = auth.uid() or public.nightwatch_can_access_record(id))
with check (created_by = auth.uid() or public.nightwatch_can_access_record(id));

drop policy if exists "Only creators delete records" on public.nightwatch_records;
create policy "Only creators delete records"
on public.nightwatch_records for delete to authenticated
using (created_by = auth.uid());

drop policy if exists "Investigators view their case assignments" on public.nightwatch_record_members;
create policy "Investigators view their case assignments"
on public.nightwatch_record_members for select to authenticated
using (public.nightwatch_can_access_record(record_id));

drop policy if exists "Case creators manage investigator access" on public.nightwatch_record_members;
create policy "Case creators manage investigator access"
on public.nightwatch_record_members for insert to authenticated
with check (public.nightwatch_is_record_owner(record_id) and added_by = auth.uid());

drop policy if exists "Case creators remove investigator access" on public.nightwatch_record_members;
create policy "Case creators remove investigator access"
on public.nightwatch_record_members for delete to authenticated
using (public.nightwatch_is_record_owner(record_id));

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.nightwatch_records to authenticated;
grant select, insert, update, delete on public.nightwatch_record_members to authenticated;
grant select, update on public.nightwatch_profiles to authenticated;

-- Public/anonymous access is intentionally not granted. Invite officers through
-- Supabase Authentication > Users; do not enable public sign-ups.
