-- =====================================================================
-- Lets a profile be deleted even after that staff member has claimed or
-- resolved requests. Run once in Supabase -> SQL Editor. Safe to re-run.
--
-- Today, deleting a profiles row that any request.assigned_to points at
-- fails with:
--   "update or delete on table "profiles" violates foreign key
--    constraint "requests_assigned_to_fkey" on table "requests""
--
-- This changes that foreign key to ON DELETE SET NULL: deleting the
-- profile clears assigned_to on their past requests instead of blocking
-- the delete. The request itself (description, photos, status, resolved
-- date, comments) is untouched — only the "claimed/resolved by" link to
-- that now-deleted account is cleared. Needed before admin-delete-account
-- (supabase/functions/admin-delete-account) can fully remove an account.
-- =====================================================================

begin;

alter table public.requests
  drop constraint if exists requests_assigned_to_fkey;

alter table public.requests
  add constraint requests_assigned_to_fkey
  foreign key (assigned_to) references public.profiles(user_id)
  on delete set null;

commit;
