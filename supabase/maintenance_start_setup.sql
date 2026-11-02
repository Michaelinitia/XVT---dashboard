-- =====================================================================
-- Starting a task now records HOW it's being handled instead of just WHO
-- claimed it — replaces the old single "Claim" button with two: "In
-- house maintenance" / "By contractor". Run once in Supabase -> SQL
-- Editor. Safe to re-run.
-- =====================================================================

begin;

alter table public.requests
  add column if not exists maintenance_type text,
  add column if not exists maintenance_pic text;

alter table public.requests
  drop constraint if exists requests_maintenance_type_check;
alter table public.requests
  add constraint requests_maintenance_type_check
  check (maintenance_type is null or maintenance_type in ('in_house', 'contractor'));

alter table public.requests
  drop constraint if exists requests_maintenance_pic_check;
alter table public.requests
  add constraint requests_maintenance_pic_check
  check (maintenance_pic is null or maintenance_pic in ('Firdzuan', 'Zenn', 'Isyrak'));

commit;
