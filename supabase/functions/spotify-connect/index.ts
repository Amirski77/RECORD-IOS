// Finishes the Spotify PKCE handshake on behalf of the signed-in user.
// The client never sees a refresh token — this function exchanges the
// authorization code, reads /v1/me, and stores the connection itself.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "No auth header" }, 401);

    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData.user) {
      return json({ error: "Invalid user: " + (userErr?.message ?? "unknown") }, 401);
    }
    const userId = userData.user.id;

    const { code, code_verifier, redirect_uri } = await req.json();
    if (!code || !code_verifier || !redirect_uri) {
      return json({ error: "Missing code, code_verifier, or redirect_uri" }, 400);
    }

    const clientId = Deno.env.get("SPOTIFY_CLIENT_ID");
    if (!clientId) return json({ error: "Spotify not configured" }, 500);

    // 1. Exchange the authorization code for tokens. PKCE means no client
    //    secret is needed or sent here.
    const tokenRes = await fetch("https://accounts.spotify.com/api/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        code,
        redirect_uri,
        client_id: clientId,
        code_verifier,
      }),
    });
    const tokenData = await tokenRes.json();
    if (!tokenRes.ok || !tokenData.access_token) {
      return json({ error: "Token exchange failed: " + JSON.stringify(tokenData) }, 400);
    }

    const { access_token, refresh_token, expires_in } = tokenData;
    if (!refresh_token) {
      // Spotify always returns one on the first authorization_code exchange.
      return json({ error: "No refresh token returned" }, 400);
    }

    // 2. Who did we just connect?
    const meRes = await fetch("https://api.spotify.com/v1/me", {
      headers: { Authorization: `Bearer ${access_token}` },
    });
    const me = await meRes.json();
    if (!meRes.ok) {
      return json({ error: "Failed to read Spotify profile: " + JSON.stringify(me) }, 400);
    }

    const profileUrl: string | null = me?.external_urls?.spotify ?? null;
    const displayName: string | null = me?.display_name ?? null;
    const expiresAt = new Date(Date.now() + expires_in * 1000).toISOString();

    // 3. Store the connection + reflect it on the profile row.
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { error: upsertErr } = await admin.from("spotify_connections").upsert({
      user_id: userId,
      spotify_user_id: me.id,
      display_name: displayName,
      profile_url: profileUrl,
      refresh_token,
      access_token,
      expires_at: expiresAt,
    });
    if (upsertErr) return json({ error: upsertErr.message }, 500);

    const { error: profileErr } = await admin
      .from("profiles")
      .update({ spotify_profile: profileUrl, spotify_connected: true })
      .eq("id", userId);
    if (profileErr) return json({ error: profileErr.message }, 500);

    return json({ ok: true, display_name: displayName, profile_url: profileUrl });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
