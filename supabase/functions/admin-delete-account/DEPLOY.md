# Deploying admin-delete-account

One-time setup so Team & Account → Delete fully removes an account
(login + profile) without ever opening Supabase's dashboard again.

1. Run `supabase/profile_delete_fk_fix.sql` in Supabase → SQL Editor, if
   you haven't already (needed either way — the direct delete the
   dashboard used before hits the same error this fixes).

2. Install the Supabase CLI if you don't have it:
   ```
   npm install -g supabase
   ```

3. From the repo root, log in and link this function to your project
   (find `<project-ref>` in Supabase → Project Settings → General):
   ```
   supabase login
   supabase link --project-ref <project-ref>
   ```

4. Deploy the function:
   ```
   supabase functions deploy admin-delete-account
   ```
   No secrets to set — `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
   `SUPABASE_SERVICE_ROLE_KEY` are injected automatically into every Edge
   Function by Supabase.

That's it — the dashboard's Delete button (index.html) already calls
`${SUPABASE_URL}/functions/v1/admin-delete-account`, so it starts working
as soon as this is deployed. No index.html changes needed for future
re-deploys of this function (e.g. after editing index.ts), just repeat
step 4.
