// Idempotent monthly playlist sync. Called both right after a post (that
// month) and from a manual "sync" button in the diary (any month) — so this
// is the only place playlist-building logic lives.
//
// Always does a full PUT of the ordered track list rather than appending,
// which makes repeat calls safe and makes a stale/unfollowed playlist
// self-healing (see the 404 handling below).

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

const MONTH_NAMES = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];

function monthLabel(month: string): string {
  const [y, m] = month.split("-").map(Number);
  return `${MONTH_NAMES[m - 1]} ${y}`;
}

function monthRange(month: string): { start: string; end: string } {
  const [y, m] = month.split("-").map(Number);
  const start = new Date(Date.UTC(y, m - 1, 1));
  const end = new Date(Date.UTC(y, m, 1));
  return { start: start.toISOString(), end: end.toISOString() };
}

function trackURI(spotifyUrl: string | null): string | null {
  if (!spotifyUrl) return null;
  const match = spotifyUrl.match(/\/track\/([A-Za-z0-9]+)/);
  return match ? `spotify:track:${match[1]}` : null;
}

async function searchTrackURI(track: string, artist: string, accessToken: string): Promise<string | null> {
  const query = encodeURIComponent(`track:${track} artist:${artist}`);
  const res = await fetch(`https://api.spotify.com/v1/search?q=${query}&type=track&limit=1`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) return null;
  const data = await res.json();
  return data?.tracks?.items?.[0]?.uri ?? null;
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

    const { month } = await req.json();
    if (!month || !/^\d{4}-\d{2}$/.test(month)) {
      return json({ error: "Expected month as 'YYYY-MM'" }, 400);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 1. Load (and if needed, refresh) the connection.
    const { data: conn, error: connErr } = await admin
      .from("spotify_connections")
      .select("spotify_user_id, refresh_token, access_token, expires_at")
      .eq("user_id", userId)
      .single();
    if (connErr || !conn) return json({ error: "Spotify isn't connected" }, 400);

    let accessToken = conn.access_token as string;
    const expiresAt = conn.expires_at ? new Date(conn.expires_at).getTime() : 0;
    if (!accessToken || expiresAt < Date.now() + 60_000) {
      const clientId = Deno.env.get("SPOTIFY_CLIENT_ID")!;
      const refreshRes = await fetch("https://accounts.spotify.com/api/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          grant_type: "refresh_token",
          refresh_token: conn.refresh_token,
          client_id: clientId,
        }),
      });
      const refreshData = await refreshRes.json();
      if (!refreshRes.ok || !refreshData.access_token) {
        return json({ error: "Spotify session expired — reconnect in Settings" }, 400);
      }
      accessToken = refreshData.access_token;

      // Spotify rotates refresh tokens on this flow; if we got a new one,
      // it must replace the old one or the connection dies on next refresh.
      const update: Record<string, unknown> = {
        access_token: accessToken,
        expires_at: new Date(Date.now() + refreshData.expires_in * 1000).toISOString(),
      };
      if (refreshData.refresh_token) update.refresh_token = refreshData.refresh_token;
      await admin.from("spotify_connections").update(update).eq("user_id", userId);
    }

    // 2. Gather the month's tracks, oldest first.
    const { start, end } = monthRange(month);
    const { data: posts, error: postsErr } = await admin
      .from("posts")
      .select("track_name, artist_name, spotify_url, created_at")
      .eq("user_id", userId)
      .gte("created_at", start)
      .lt("created_at", end)
      .order("created_at", { ascending: true });
    if (postsErr) return json({ error: postsErr.message }, 500);

    const uris: string[] = [];
    for (const post of posts ?? []) {
      const uri = trackURI(post.spotify_url) ??
        (await searchTrackURI(post.track_name, post.artist_name, accessToken));
      if (uri) uris.push(uri);
    }

    if (uris.length === 0) {
      return json({ error: "No matched tracks for that month yet" }, 400);
    }

    // 3. Find or create the playlist for this month.
    const { data: existing } = await admin
      .from("month_playlists")
      .select("playlist_id, playlist_url")
      .eq("user_id", userId)
      .eq("month", month)
      .maybeSingle();

    let playlistId = existing?.playlist_id as string | undefined;
    let playlistUrl = existing?.playlist_url as string | undefined;

    async function createPlaylist() {
      const createRes = await fetch(
        `https://api.spotify.com/v1/users/${conn.spotify_user_id}/playlists`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            name: `RECORD · ${monthLabel(month)}`,
            description: "Your daily records, one month at a time. Made with RECORD.",
            public: true,
          }),
        }
      );
      const created = await createRes.json();
      if (!createRes.ok) throw new Error("Playlist creation failed: " + JSON.stringify(created));
      playlistId = created.id;
      playlistUrl = created.external_urls?.spotify;
    }

    if (!playlistId) {
      await createPlaylist();
    }

    // 4. Full replace of the track list — safe to repeat, self-healing.
    let putRes = await fetch(`https://api.spotify.com/v1/playlists/${playlistId}/tracks`, {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ uris }),
    });

    if (putRes.status === 404) {
      // The playlist was unfollowed/deleted on Spotify's side. Recreate it.
      await createPlaylist();
      putRes = await fetch(`https://api.spotify.com/v1/playlists/${playlistId}/tracks`, {
        method: "PUT",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ uris }),
      });
    }

    if (!putRes.ok) {
      const body = await putRes.text();
      return json({ error: "Failed to update playlist tracks: " + body }, 500);
    }

    await admin.from("month_playlists").upsert({
      user_id: userId,
      month,
      playlist_id: playlistId,
      playlist_url: playlistUrl,
      synced_at: new Date().toISOString(),
    });

    return json({ playlist_url: playlistUrl });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
