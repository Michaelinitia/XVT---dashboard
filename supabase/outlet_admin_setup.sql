-- =====================================================================
-- Outlet management from the dashboard (Team & Account → Outlets)
-- Run once in Supabase → SQL Editor. Safe to re-run.
--
-- Includes everything from memir_trx_setup.sql, so if that one was never
-- run (or failed part-way), this file alone is enough.
-- =====================================================================

begin;

-- 1. Columns the dashboard reads/writes on outlets.
--    map_config: floor plan + zones drawn in the dashboard's outlet editor:
--      { "image_url": "...", "width": 1280, "height": 1064,
--        "zones": [ { "name": "FOH Zone 1", "kind": "foh",
--                     "pin": [x, y], "points": [[x, y], ...] }, ... ] }
--      (coordinates are pixels on the uploaded image). When null, the
--      outlet uses its built-in map (KLGCC / MODU TRX / Memir TRX) if any.
--    telegram_enabled: per-outlet on/off switch for Telegram alerts
--      (existing outlets default to ON, so nothing changes for them).
alter table public.outlets
  add column if not exists map_config jsonb,
  add column if not exists telegram_enabled boolean not null default true;

-- 2. "Is the current user an admin?" — used by the policies below.
--    SECURITY DEFINER so it can read profiles regardless of profiles' RLS.
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce((select is_admin from profiles where user_id = auth.uid()), false);
$$;

-- 3. Row Level Security on outlets:
--    - anyone can read outlets (the public QR form needs the outlet's
--      name and zones before anyone logs in — same as today)
--    - only admins can add or edit outlets.
alter table public.outlets enable row level security;

drop policy if exists "outlets readable by everyone" on public.outlets;
create policy "outlets readable by everyone"
  on public.outlets for select
  using (true);

drop policy if exists "admins can add outlets" on public.outlets;
create policy "admins can add outlets"
  on public.outlets for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists "admins can edit outlets" on public.outlets;
create policy "admins can edit outlets"
  on public.outlets for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- 4. Memir TRX, if it isn't there yet (Telegram off until its groups exist).
insert into public.outlets (outlet_name, qr_token, telegram_enabled)
select 'Memir TRX', replace(gen_random_uuid()::text, '-', ''), false
where not exists (
  select 1 from public.outlets where upper(trim(outlet_name)) = 'MEMIR TRX'
);

commit;

-- 5. Check: every outlet and its QR link.
select outlet_name,
       telegram_enabled,
       map_config is not null as has_custom_map,
       'https://michaelinitia.github.io/XVT---dashboard/?qr=' || qr_token as qr_link
from public.outlets
order by outlet_name;
