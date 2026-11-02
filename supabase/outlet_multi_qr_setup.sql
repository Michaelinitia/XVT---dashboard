-- =====================================================================
-- Multiple QR codes per outlet (Team & Account → Outlets → QR codes).
-- Run once in Supabase → SQL Editor, after outlet_admin_setup.sql.
-- Safe to re-run.
--
-- Lets one outlet have several QR codes (e.g. a separate sticker for
-- each entrance or washroom) that all resolve to the same outlet. The
-- original single qr_token column is kept and stays mirrored to the
-- first entry in qr_tokens, so nothing that reads qr_token directly
-- (old printed codes, old rows) breaks.
-- =====================================================================

begin;

alter table public.outlets
  add column if not exists qr_tokens text[] not null default '{}';

-- Backfill: every outlet that already has a qr_token but no qr_tokens
-- yet gets a one-element array from it.
update public.outlets
set qr_tokens = array[qr_token]
where qr_token is not null
  and (qr_tokens is null or qr_tokens = '{}');

commit;

-- Check: every outlet and all of its QR links.
select outlet_name,
       qr_tokens,
       (
         select string_agg(
           'https://michaelinitia.github.io/XVT---dashboard/?qr=' || t, E'\n'
         )
         from unnest(qr_tokens) as t
       ) as qr_links
from public.outlets
order by outlet_name;
