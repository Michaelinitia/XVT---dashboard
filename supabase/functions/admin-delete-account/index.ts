// Fully deletes a staff account — both their Supabase Auth login and
// their profiles row — in one call, so deleting someone from the
// dashboard's Team & Account page never requires going into the Supabase
// dashboard by hand.
//
// This has to live here, server-side, rather than in index.html: deleting
// an Auth user requires the Admin API, which requires the service_role
// key. That key bypasses every RLS policy in the project — it must never
// be embedded in client-side code, where anyone could read it via
// view-source. An Edge Function is the opposite: it runs on Supabase's
// servers, the service_role key is injected as an environment variable
// that the browser never sees, and this function is the only thing
// that gets to use it, gated by the admin check below.
//
// Deploy once (see supabase/functions/admin-delete-account/DEPLOY.md),
// then it's live at:
//   https://<project-ref>.supabase.co/functions/v1/admin-delete-account
//
// Requires supabase/profile_delete_fk_fix.sql to have been run first —
// otherwise deleting a staff member who has ever claimed a request will
// fail with a foreign key error, same as the direct REST delete does
// today.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ message: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization") || "";
  const callerToken = authHeader.replace(/^Bearer\s+/i, "");
  if (!callerToken) return json({ message: "Missing Authorization header" }, 401);

  let body: { user_id?: string };
  try {
    body = await req.json();
  } catch {
    return json({ message: "Invalid JSON body" }, 400);
  }
  const targetUserId = body.user_id;
  if (!targetUserId) return json({ message: "user_id is required" }, 400);

  // A client scoped to the CALLER's own token — used only to find out who
  // they are and whether they're an admin. Never used for the delete
  // itself, so a non-admin caller can't do anything here beyond that check.
  const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${callerToken}` } },
  });
  const { data: callerData, error: callerErr } = await callerClient.auth.getUser();
  if (callerErr || !callerData?.user) return json({ message: "Invalid or expired session" }, 401);
  const callerId = callerData.user.id;

  if (callerId === targetUserId) {
    return json({ message: "You can't delete your own account from here." }, 400);
  }

  // The admin client — this is the only place SERVICE_ROLE_KEY is used.
  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: callerProfile, error: profileErr } = await adminClient
    .from("profiles")
    .select("is_admin")
    .eq("user_id", callerId)
    .maybeSingle();
  if (profileErr) return json({ message: "Could not verify admin status: " + profileErr.message }, 500);
  if (!callerProfile?.is_admin) return json({ message: "Only admins can delete accounts." }, 403);

  // Delete the Auth login first. If the project's profiles table has
  // profiles.user_id -> auth.users(id) on delete cascade, this alone would
  // also remove the profiles row — but that's not guaranteed, so the
  // explicit delete below runs regardless and is a no-op if it's already gone.
  const { error: authDeleteErr } = await adminClient.auth.admin.deleteUser(targetUserId);
  if (authDeleteErr && authDeleteErr.status !== 404) {
    return json({ message: "Could not delete login: " + authDeleteErr.message }, 500);
  }

  const { error: profileDeleteErr } = await adminClient
    .from("profiles")
    .delete()
    .eq("user_id", targetUserId);
  if (profileDeleteErr) {
    // The Auth login is already gone at this point even if this fails —
    // surface it clearly rather than claiming full success.
    return json({
      message: "Login deleted, but the profile row could not be removed: " + profileDeleteErr.message +
        ". Run supabase/profile_delete_fk_fix.sql if you haven't, then delete the leftover profiles row directly.",
    }, 500);
  }

  return json({ ok: true });
});
