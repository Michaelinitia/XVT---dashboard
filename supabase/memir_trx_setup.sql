-- =====================================================================
-- Memir TRX: outlet setup
-- Run in Supabase → SQL Editor. Safe to re-run (it only adds what's missing).
-- =====================================================================

begin;

-- 1. Per-outlet Telegram on/off switch.
--    Existing outlets default to ON, so nothing changes for KLGCC / MODU TRX.
--    The notify_* trigger functions skip any outlet where this is false,
--    so an outlet without its own groups yet never falls back to posting
--    in another outlet's (or the fallback) group.
alter table public.outlets
  add column if not exists telegram_enabled boolean not null default true;

-- 2. The outlet itself, with Telegram OFF until its groups are ready.
--    The name must match the dashboard config key ('MEMIR TRX', compared
--    case-insensitively), which is what loads its floor plan and zones.
insert into public.outlets (outlet_name, qr_token, telegram_enabled)
select 'Memir TRX', replace(gen_random_uuid()::text, '-', ''), false
where not exists (
  select 1 from public.outlets where upper(trim(outlet_name)) = 'MEMIR TRX'
);

commit;

-- 3. The outlet's id and QR link (print this link as the outlet's QR code).
select outlet_id,
       outlet_name,
       telegram_enabled,
       'https://michaelinitia.github.io/XVT---dashboard/?qr=' || qr_token as qr_link
from public.outlets
where upper(trim(outlet_name)) = 'MEMIR TRX';


-- =====================================================================
-- LATER: Telegram onboarding for Memir TRX (run once the groups exist)
-- =====================================================================
-- a) Add the bot to each group (and make it able to post in the topics).
-- b) Post any message in each topic, then open in a browser:
--      https://api.telegram.org/bot<BOT_TOKEN>/getUpdates
--    For each message, note "chat":{"id": ...}  (a negative number, e.g.
--    -100123...) and "message_thread_id" (only present for forum topics).
-- c) Fill in the values below and run it. Leave a thread id null if that
--    group doesn't use topics.
--
-- update public.outlets set
--   telegram_chat_id_defects        = '-100XXXXXXXXXX',  -- new defect alerts (staff group)
--   telegram_thread_id_defects      = null,              -- topic id, or null
--   telegram_chat_id_improvements   = '-100XXXXXXXXXX',  -- new improvement alerts (staff group)
--   telegram_thread_id_improvements = null,
--   telegram_submitter_chat_id      = '-100XXXXXXXXXX',  -- "Claimed by" / "Resolved by" updates
--   telegram_submitter_thread_id    = null,
--   telegram_enabled                = true
-- where upper(trim(outlet_name)) = 'MEMIR TRX';
--
-- To pause alerts again at any time:
-- update public.outlets set telegram_enabled = false
-- where upper(trim(outlet_name)) = 'MEMIR TRX';
