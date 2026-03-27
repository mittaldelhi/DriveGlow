-- ================================================================
-- DriveGlow Recovery SQL (Safe Full Rebuild)
-- Run this in Supabase SQL Editor if current DB is broken.
-- NOTE: This preserves existing user data when run.
-- NOTE: Uses CREATE TABLE IF NOT EXISTS to avoid data loss.
-- ================================================================

create extension if not exists pgcrypto;
grant usage on schema public to anon, authenticated, service_role;
grant all on schema public to postgres, service_role;

-- ============================================================
-- IMPORTANT: All DROP TABLE statements removed to preserve user data!
-- Tables will be created if they don't exist (CREATE TABLE IF NOT EXISTS)
-- ============================================================

-- ------------------------------------------------
-- 1) Core app tables
-- ------------------------------------------------

create table if not exists public.app_config (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.services (
  id text primary key default gen_random_uuid()::text,
  title text not null,
  description text not null default '',
  base_price numeric(10,2) not null default 0,
  icon_name text not null default 'local_car_wash',
  category text not null default 'Standard',
  is_available boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.service_pricing (
  id text primary key default gen_random_uuid()::text,
  name text not null,
  description text not null default '',
  price numeric(10,2) not null,
  category text not null default 'General',
  plan_type text not null default 'One-Time' check (plan_type in ('One-Time', 'Monthly', 'Yearly', 'Subscription')),
  image_url text,
  is_active boolean not null default true,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),

  -- Backward-compat columns used by older code paths
  service_name text generated always as (name) stored,
  tier text default 'ALL'
);

create table if not exists public.standard_services (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  price numeric(10,2) not null,
  category text not null default 'General',
  image_url text,
  is_active boolean not null default true,
  display_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  tier text not null default 'Silver',
  vehicle_category text not null default 'Sedan',
  duration text not null check (duration in ('Monthly', 'Yearly')),
  price numeric(10,2) not null,
  original_price numeric(10,2),
  frequency_limit text not null default '2 Washes/Month',
  description text not null default '',
  features text[] not null default array[]::text[],
  included_service_ids uuid[] not null default array[]::uuid[],
  is_featured boolean not null default false,
  is_active boolean not null default true,
  display_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default 'User',
  avatar_url text,
  membership_tier text not null default 'FREE',
  address text,
  gender text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_vehicles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  model text not null,
  license_plate text not null,
  color text not null,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  unique(user_id, license_plate)
);

create table if not exists public.bookings (
  id text primary key default gen_random_uuid()::text,
  user_id uuid not null references auth.users(id) on delete cascade,
  service_id text not null,
  vehicle_name text not null,
  vehicle_number text not null,
  appointment_date timestamptz not null,
  status text not null check (status in ('pending', 'confirmed', 'inProgress', 'completed', 'cancelled')),
  total_price numeric(10,2) not null default 0,
  qr_code_data text not null,
  check_in_time timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.service_feedback (
  id text primary key,
  booking_id text not null references public.bookings(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rating numeric(3,1) not null check (rating >= 0 and rating <= 5),
  comment text,
  tags text[] not null default array[]::text[],
  created_at timestamptz not null default now()
);

create table if not exists public.support_messages (
  id text primary key,
  chat_id text not null,
  sender_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  message text not null,
  is_from_support boolean not null default false,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------
-- 2) Staff tables
-- ------------------------------------------------

create table if not exists public.staff_roles (
  role_key text primary key,
  role_name text not null,
  created_at timestamptz not null default now()
);

insert into public.staff_roles (role_key, role_name)
values ('WASHER', 'Washer'), ('SUPERVISOR', 'Supervisor')
on conflict (role_key) do nothing;

create table if not exists public.staff_users (
  id uuid primary key references auth.users(id) on delete cascade,
  employee_id text not null unique,
  role_key text not null references public.staff_roles(role_key) default 'WASHER',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.attendance_logs (
  id uuid primary key default gen_random_uuid(),
  staff_user_id uuid not null references public.staff_users(id) on delete cascade,
  check_in_at timestamptz not null default now(),
  check_out_at timestamptz,
  location_code text not null default 'HQ1',
  created_at timestamptz not null default now()
);

create table if not exists public.service_logs (
  id uuid primary key default gen_random_uuid(),
  booking_id text references public.bookings(id) on delete set null,
  staff_user_id uuid not null references public.staff_users(id) on delete cascade,
  action text not null check (action in ('qr_scan', 'start', 'complete', 'no_show', 'invalid_scan')),
  action_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.job_assignments (
  id uuid primary key default gen_random_uuid(),
  booking_id text not null unique references public.bookings(id) on delete cascade,
  staff_user_id uuid references public.staff_users(id) on delete set null,
  token_no text,
  status text not null default 'waiting' check (status in ('waiting', 'in_progress', 'completed', 'no_show')),
  assigned_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------
-- 2.1) Grants (required in addition to RLS)
-- ------------------------------------------------

grant select on table
  public.app_config,
  public.services,
  public.service_pricing,
  public.standard_services,
  public.subscription_plans
to anon;

grant select, insert, update, delete on table
  public.app_config,
  public.services,
  public.service_pricing,
  public.standard_services,
  public.subscription_plans,
  public.user_profiles,
  public.user_vehicles,
  public.bookings,
  public.service_feedback,
  public.support_messages,
  public.staff_roles,
  public.staff_users,
  public.attendance_logs,
  public.service_logs,
  public.job_assignments
to authenticated;

-- ------------------------------------------------
-- 3) Indexes (IF NOT EXISTS to prevent errors on re-run)
-- ------------------------------------------------

create index if not exists idx_services_available on public.services(is_available);
create index if not exists idx_service_pricing_order on public.service_pricing(display_order);
create index if not exists idx_service_pricing_active on public.service_pricing(is_active);
create index if not exists idx_service_pricing_plan_type on public.service_pricing(plan_type);
create index if not exists idx_standard_services_order on public.standard_services(display_order);
create index if not exists idx_sub_plans_order on public.subscription_plans(display_order);
create index if not exists idx_sub_plans_duration on public.subscription_plans(duration);
create index if not exists idx_sub_plans_active on public.subscription_plans(is_active);
create index if not exists idx_sub_plans_included on public.subscription_plans using gin (included_service_ids);
create index if not exists idx_user_vehicles_user on public.user_vehicles(user_id);
create index if not exists idx_bookings_user on public.bookings(user_id);
create index if not exists idx_bookings_status on public.bookings(status);
create index if not exists idx_bookings_date on public.bookings(appointment_date);
create index if not exists idx_feedback_booking on public.service_feedback(booking_id);
create index if not exists idx_feedback_created_at on public.service_feedback(created_at desc);
create index if not exists idx_support_messages_user on public.support_messages(user_id, created_at);
create index if not exists idx_staff_users_role on public.staff_users(role_key, is_active);
create index if not exists idx_attendance_staff_day on public.attendance_logs(staff_user_id, check_in_at);
create index if not exists idx_service_logs_booking on public.service_logs(booking_id, created_at desc);
create index if not exists idx_job_assignments_status on public.job_assignments(status, assigned_at);

-- ------------------------------------------------
-- 4) Functions + triggers
-- ------------------------------------------------

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_user_profiles_updated_at on public.user_profiles;
create trigger trg_user_profiles_updated_at
before update on public.user_profiles
for each row execute function public.touch_updated_at();

drop trigger if exists trg_staff_users_updated_at on public.staff_users;
create trigger trg_staff_users_updated_at
before update on public.staff_users
for each row execute function public.touch_updated_at();

drop trigger if exists trg_job_assignments_updated_at on public.job_assignments;
create trigger trg_job_assignments_updated_at
before update on public.job_assignments
for each row execute function public.touch_updated_at();

create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_tier text;
begin
  v_name := coalesce(
    nullif(trim((new.raw_user_meta_data ->> 'full_name')), ''),
    split_part(coalesce(new.email, 'User'), '@', 1),
    'User'
  );

  v_tier := upper(coalesce(new.raw_user_meta_data ->> 'membership_tier', 'FREE'));

  insert into public.user_profiles (id, full_name, membership_tier)
  values (new.id, v_name, v_tier)
  on conflict (id) do update
  set
    full_name = coalesce(nullif(public.user_profiles.full_name, ''), excluded.full_name),
    membership_tier = coalesce(nullif(public.user_profiles.membership_tier, ''), excluded.membership_tier);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function public.handle_new_user_profile();

create or replace function public.is_admin_user()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select (
    exists (
      select 1 from public.user_profiles p
      where p.id = auth.uid() and upper(coalesce(p.membership_tier, '')) = 'ADMIN'
    )
    or upper(coalesce(auth.jwt() -> 'user_metadata' ->> 'membership_tier', '')) = 'ADMIN'
    or upper(coalesce(auth.jwt() -> 'app_metadata' ->> 'membership_tier', '')) = 'ADMIN'
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'admin@gmail.com'
  );
$$;

create or replace function public.is_staff_user()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select (
    exists (
      select 1 from public.user_profiles p
      where p.id = auth.uid() and upper(coalesce(p.membership_tier, '')) in ('STAFF', 'ADMIN')
    )
    or public.is_admin_user()
  );
$$;

create or replace function public.is_supervisor_user()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.staff_users s
    where s.id = auth.uid() and s.is_active = true and s.role_key = 'SUPERVISOR'
  ) or public.is_admin_user();
$$;

-- Staff RPCs
create or replace function public.promote_existing_user_to_staff(
  p_email text,
  p_full_name text,
  p_phone text default null,
  p_role text default 'WASHER',
  p_employee_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role text := upper(coalesce(p_role, 'WASHER'));
  v_employee_id text;
begin
  if not public.is_admin_user() then
    raise exception 'ADMIN_REQUIRED';
  end if;

  if v_role not in ('WASHER', 'SUPERVISOR') then
    raise exception 'INVALID_ROLE';
  end if;

  select u.id into v_user_id
  from auth.users u
  where lower(u.email) = lower(p_email)
  limit 1;

  if v_user_id is null then
    raise exception 'USER_NOT_FOUND';
  end if;

  insert into public.user_profiles (id, full_name, phone, membership_tier)
  values (v_user_id, coalesce(nullif(p_full_name, ''), 'Staff'), p_phone, 'STAFF')
  on conflict (id) do update set
    full_name = coalesce(nullif(excluded.full_name, ''), public.user_profiles.full_name),
    phone = excluded.phone,
    membership_tier = 'STAFF';

  v_employee_id := coalesce(
    nullif(p_employee_id, ''),
    'STF-' || upper(substr(replace(v_user_id::text, '-', ''), 1, 8))
  );

  insert into public.staff_users (id, employee_id, role_key, is_active)
  values (v_user_id, v_employee_id, v_role, true)
  on conflict (id) do update set
    role_key = excluded.role_key,
    is_active = true,
    employee_id = coalesce(public.staff_users.employee_id, excluded.employee_id);

  return v_user_id;
end;
$$;

create or replace function public.admin_update_staff_account(
  p_staff_user_id uuid,
  p_full_name text default null,
  p_phone text default null,
  p_role text default null,
  p_is_active boolean default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := upper(coalesce(p_role, 'WASHER'));
begin
  if not public.is_admin_user() then
    raise exception 'ADMIN_REQUIRED';
  end if;

  if p_role is not null and v_role not in ('WASHER', 'SUPERVISOR') then
    raise exception 'INVALID_ROLE';
  end if;

  update public.user_profiles
  set
    full_name = coalesce(nullif(p_full_name, ''), full_name),
    phone = coalesce(p_phone, phone),
    membership_tier = 'STAFF'
  where id = p_staff_user_id;

  update public.staff_users
  set
    role_key = coalesce(v_role, role_key),
    is_active = coalesce(p_is_active, is_active)
  where id = p_staff_user_id;
end;
$$;

create or replace function public.validate_qr_and_prepare_job(
  p_qr_code text,
  p_car_number text default null
)
returns table(
  valid boolean,
  error_code text,
  error_message text,
  booking_id text,
  customer_name text,
  car_number text,
  service_type text,
  subscription_plan text,
  remaining_wash_count integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings%rowtype;
  v_customer_name text;
begin
  if not public.is_staff_user() then
    return query select false, 'UNAUTHORIZED', 'Staff access required', null::text, null::text, null::text, null::text, null::text, null::int;
    return;
  end if;

  select * into v_booking
  from public.bookings b
  where b.qr_code_data = p_qr_code
  order by b.created_at desc
  limit 1;

  if v_booking.id is null then
    return query select false, 'INVALID_BOOKING', 'Booking not found', null::text, null::text, null::text, null::text, null::text, null::int;
    return;
  end if;

  if p_car_number is not null and trim(p_car_number) <> ''
     and upper(v_booking.vehicle_number) <> upper(trim(p_car_number)) then
    return query select false, 'CAR_MISMATCH', 'Car number does not match', v_booking.id, null::text, v_booking.vehicle_number, v_booking.service_id, null::text, null::int;
    return;
  end if;

  select up.full_name into v_customer_name from public.user_profiles up where up.id = v_booking.user_id;

  return query
  select
    true,
    null::text,
    null::text,
    v_booking.id,
    coalesce(v_customer_name, 'Customer'),
    v_booking.vehicle_number,
    v_booking.service_id,
    case when v_booking.service_id like 'subscription::%' then v_booking.service_id else null end,
    null::int;
end;
$$;

create or replace function public.start_staff_service(p_booking_id text)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff_user() then
    raise exception 'STAFF_REQUIRED';
  end if;

  update public.bookings
  set status = 'inProgress', check_in_time = now()
  where id = p_booking_id and status in ('pending', 'confirmed');

  if not found then
    raise exception 'BOOKING_NOT_STARTABLE';
  end if;

  insert into public.service_logs(booking_id, staff_user_id, action)
  values (p_booking_id, auth.uid(), 'start');

  insert into public.job_assignments(booking_id, staff_user_id, status, token_no)
  values (p_booking_id, auth.uid(), 'in_progress', 'SRV-' || upper(substr(replace(p_booking_id, '-', ''), 1, 8)))
  on conflict (booking_id) do update set
    staff_user_id = excluded.staff_user_id,
    status = excluded.status,
    updated_at = now();

  return 'OK';
end;
$$;

create or replace function public.complete_staff_service(p_booking_id text)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff_user() then
    raise exception 'STAFF_REQUIRED';
  end if;

  update public.bookings
  set status = 'completed', completed_at = now()
  where id = p_booking_id and status = 'inProgress';

  if not found then
    raise exception 'BOOKING_NOT_COMPLETABLE';
  end if;

  insert into public.service_logs(booking_id, staff_user_id, action)
  values (p_booking_id, auth.uid(), 'complete');

  update public.job_assignments
  set status = 'completed', updated_at = now()
  where booking_id = p_booking_id;

  return 'OK';
end;
$$;

create or replace function public.mark_staff_no_show(p_booking_id text)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_supervisor_user() then
    raise exception 'SUPERVISOR_REQUIRED';
  end if;

  update public.bookings
  set status = 'cancelled'
  where id = p_booking_id and status in ('pending', 'confirmed');

  if not found then
    raise exception 'BOOKING_NOT_WAITING';
  end if;

  insert into public.service_logs(booking_id, staff_user_id, action)
  values (p_booking_id, auth.uid(), 'no_show');

  insert into public.job_assignments(booking_id, staff_user_id, status)
  values (p_booking_id, auth.uid(), 'no_show')
  on conflict (booking_id) do update set
    staff_user_id = excluded.staff_user_id,
    status = excluded.status,
    updated_at = now();

  return 'OK';
end;
$$;

grant execute on function public.promote_existing_user_to_staff(text, text, text, text, text) to authenticated;
grant execute on function public.admin_update_staff_account(uuid, text, text, text, boolean) to authenticated;
grant execute on function public.validate_qr_and_prepare_job(text, text) to authenticated;
grant execute on function public.start_staff_service(text) to authenticated;
grant execute on function public.complete_staff_service(text) to authenticated;
grant execute on function public.mark_staff_no_show(text) to authenticated;

-- ------------------------------------------------
-- 5) RLS
-- ------------------------------------------------

alter table public.app_config enable row level security;
alter table public.services enable row level security;
alter table public.service_pricing enable row level security;
alter table public.standard_services enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.user_profiles enable row level security;
alter table public.user_vehicles enable row level security;
alter table public.bookings enable row level security;
alter table public.service_feedback enable row level security;
alter table public.support_messages enable row level security;
alter table public.staff_users enable row level security;
alter table public.attendance_logs enable row level security;
alter table public.service_logs enable row level security;
alter table public.job_assignments enable row level security;

-- Clean old policy names if any
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('app_config','services','service_pricing','standard_services','subscription_plans','user_profiles','user_vehicles','bookings','service_feedback','support_messages','staff_users','attendance_logs','service_logs','job_assignments')
  LOOP
    EXECUTE format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

create policy app_config_read_all on public.app_config for select to public using (true);
create policy services_read_all on public.services for select to public using (true);
create policy pricing_read_all on public.service_pricing for select to public using (true);
create policy standard_services_read_all on public.standard_services for select to public using (true);
create policy sub_plans_read_all on public.subscription_plans for select to public using (true);

create policy app_config_write_admin on public.app_config for all to authenticated
using (public.is_admin_user()) with check (public.is_admin_user());
create policy services_write_admin on public.services for all to authenticated
using (public.is_admin_user()) with check (public.is_admin_user());
create policy pricing_write_admin on public.service_pricing for all to authenticated
using (public.is_admin_user()) with check (public.is_admin_user());
create policy standard_services_write_admin on public.standard_services for all to authenticated
using (public.is_admin_user()) with check (public.is_admin_user());
create policy sub_plans_write_admin on public.subscription_plans for all to authenticated
using (public.is_admin_user()) with check (public.is_admin_user());

create policy user_profiles_select_own_or_admin on public.user_profiles for select to authenticated
using (id = auth.uid() or public.is_admin_user());
create policy user_profiles_insert_own_or_admin on public.user_profiles for insert to authenticated
with check (id = auth.uid() or public.is_admin_user());
create policy user_profiles_update_own_or_admin on public.user_profiles for update to authenticated
using (id = auth.uid() or public.is_admin_user())
with check (id = auth.uid() or public.is_admin_user());

create policy user_vehicles_select_own_or_admin on public.user_vehicles for select to authenticated
using (user_id = auth.uid() or public.is_admin_user());
create policy user_vehicles_insert_own_or_admin on public.user_vehicles for insert to authenticated
with check (user_id = auth.uid() or public.is_admin_user());
create policy user_vehicles_update_own_or_admin on public.user_vehicles for update to authenticated
using (user_id = auth.uid() or public.is_admin_user())
with check (user_id = auth.uid() or public.is_admin_user());
create policy user_vehicles_delete_own_or_admin on public.user_vehicles for delete to authenticated
using (user_id = auth.uid() or public.is_admin_user());

create policy bookings_select_user_staff_admin on public.bookings for select to authenticated
using (user_id = auth.uid() or public.is_staff_user() or public.is_admin_user());
create policy bookings_insert_own on public.bookings for insert to authenticated
with check (user_id = auth.uid());
create policy bookings_update_user_staff_admin on public.bookings for update to authenticated
using (user_id = auth.uid() or public.is_staff_user() or public.is_admin_user())
with check (user_id = auth.uid() or public.is_staff_user() or public.is_admin_user());

create policy feedback_select_auth on public.service_feedback for select to authenticated using (true);
create policy feedback_insert_auth on public.service_feedback for insert to authenticated with check (user_id = auth.uid());

create policy support_messages_select on public.support_messages for select to authenticated
using (user_id = auth.uid() or public.is_admin_user() or public.is_staff_user());
create policy support_messages_insert on public.support_messages for insert to authenticated
with check (user_id = auth.uid() or public.is_admin_user() or public.is_staff_user());

create policy staff_users_select_staff on public.staff_users for select to authenticated
using (public.is_staff_user());
create policy staff_users_manage_admin on public.staff_users for all to authenticated
using (public.is_admin_user()) with check (public.is_admin_user());

create policy attendance_select_staff on public.attendance_logs for select to authenticated
using (public.is_admin_user() or staff_user_id = auth.uid());
create policy attendance_insert_staff on public.attendance_logs for insert to authenticated
with check (public.is_staff_user() and staff_user_id = auth.uid());
create policy attendance_update_staff on public.attendance_logs for update to authenticated
using (public.is_admin_user() or staff_user_id = auth.uid())
with check (public.is_admin_user() or staff_user_id = auth.uid());

create policy service_logs_select_staff on public.service_logs for select to authenticated
using (public.is_admin_user() or staff_user_id = auth.uid());
create policy service_logs_insert_staff on public.service_logs for insert to authenticated
with check (public.is_staff_user());

create policy job_assignments_select_staff on public.job_assignments for select to authenticated
using (public.is_staff_user());
create policy job_assignments_manage_staff on public.job_assignments for all to authenticated
using (public.is_admin_user() or staff_user_id = auth.uid())
with check (public.is_admin_user() or staff_user_id = auth.uid());

-- ------------------------------------------------
-- 6) Storage bucket + policies
-- ------------------------------------------------

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists avatars_public_read on storage.objects;
drop policy if exists avatars_user_upload on storage.objects;
drop policy if exists avatars_user_update on storage.objects;
drop policy if exists avatars_user_delete on storage.objects;

create policy avatars_public_read on storage.objects
for select to public
using (bucket_id = 'avatars');

create policy avatars_user_upload on storage.objects
for insert to authenticated
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy avatars_user_update on storage.objects
for update to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy avatars_user_delete on storage.objects
for delete to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- ------------------------------------------------
-- 7) Backfill and seed
-- ------------------------------------------------

-- Ensure all existing auth users have profile rows
insert into public.user_profiles (id, full_name, membership_tier)
select u.id,
       coalesce(nullif(trim(u.raw_user_meta_data ->> 'full_name'), ''), split_part(coalesce(u.email, 'User'), '@', 1), 'User') as full_name,
       upper(coalesce(u.raw_user_meta_data ->> 'membership_tier', 'FREE')) as membership_tier
from auth.users u
on conflict (id) do nothing;

-- Bootstrap admin
DO $$
DECLARE v_admin_id uuid;
BEGIN
  SELECT id INTO v_admin_id
  FROM auth.users
  WHERE lower(email) = 'admin@gmail.com'
  LIMIT 1;

  IF v_admin_id IS NOT NULL THEN
    INSERT INTO public.user_profiles (id, full_name, membership_tier)
    VALUES (v_admin_id, 'Admin', 'ADMIN')
    ON CONFLICT (id) DO UPDATE
    SET membership_tier = 'ADMIN',
        full_name = coalesce(nullif(public.user_profiles.full_name, ''), excluded.full_name);
  END IF;
END $$;

-- ================================================================
-- Hardcoded data INSERT statements - COMMENTED OUT to preserve existing data
-- Uncomment only if you want to reset these tables to default values
-- ================================================================

-- insert into public.app_config (key, value)
-- values
--   ('currency_symbol', 'Rs'),
--   ('support_whatsapp', '+919999999999'),
--   ('app_name', 'DriveGlow')
-- on conflict (key) do update set value = excluded.value, updated_at = now();

-- insert into public.services (title, description, base_price, icon_name, category, is_available)
-- values
--   ('Exterior Detailing', 'Professional exterior wash and finishing.', 499, 'local_car_wash', 'Standard', true),
--   ('Interior Deep Clean', 'Vacuum + dashboard + detailing.', 799, 'cleaning_services', 'Standard', true),
--   ('Ceramic Coating', 'Long-lasting paint protection.', 2999, 'shield', 'Premium', true);

-- insert into public.service_pricing (name, description, price, category, plan_type, is_active, display_order)
-- values
--   ('Exterior Wash', 'Complete exterior wash.', 299, 'Washing', 'One-Time', true, 1),
--   ('Interior Cleaning', 'Interior vacuum and wipe.', 399, 'Cleaning', 'One-Time', true, 2),
--   ('Full Body Polish', 'Wax polishing service.', 899, 'Polishing', 'One-Time', true, 3),
--   ('Monthly Basic Pack', 'Monthly subscription pricing reference.', 999, 'Subscription', 'Monthly', true, 4),
--   ('Yearly Gold Pack', 'Yearly subscription pricing reference.', 9999, 'Subscription', 'Yearly', true, 5);

-- insert into public.standard_services (name, description, price, category, display_order, is_active)
-- values
--   ('Exterior Wash', 'Complete exterior wash with foam.', 299, 'Washing', 1, true),
--   ('Interior Cleaning', 'Vacuum + dashboard.', 399, 'Cleaning', 2, true),
--   ('Full Body Polish', 'Premium wax polish.', 899, 'Polishing', 3, true),
--   ('Ceramic Basic', 'Basic ceramic layer.', 4999, 'Protection', 4, true);

-- insert into public.subscription_plans (
--   name, tier, vehicle_category, duration, price, original_price,
--   frequency_limit, description, features, included_service_ids,
--   is_featured, is_active, display_order
-- )
-- values
--   (
--     'Silver Monthly', 'Silver', 'Sedan', 'Monthly', 1199, 1499,
--     '2 Washes/Month', 'Monthly basic subscription',
--     array['2 washes', 'priority slot'],
--     array(select id from public.standard_services order by display_order limit 2),
--     false, true, 1
--   ),
--   (
--     'Gold Yearly', 'Gold', 'Sedan', 'Yearly', 11999, 14388,
--     '24 Washes/Year', 'Yearly best-value subscription',
--     array['24 washes', 'priority slot', '1 polish'],
--     array(select id from public.standard_services order by display_order limit 3),
--     true, true, 2
--   );

-- ================================================================
-- End Recovery SQL
-- ================================================================
