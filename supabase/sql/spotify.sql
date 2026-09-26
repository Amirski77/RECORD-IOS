-- Spotify OAuth connection + automatic monthly playlists.
-- No supabase/migrations/ directory exists yet, so this is a reference
-- script: paste into the Supabase dashboard SQL editor to apply.

create table spotify_connections (
  user_id         uuid primary key references auth.users(id) on delete cascade,
  spotify_user_id text not null,
  display_name    text,
  profile_url     text,
  refresh_token   text not null,
  access_token    text,
  expires_at      timestamptz,
  connected_at    timestamptz not null default now()
);
alter table spotify_connections enable row level security;
-- Intentionally no policies: RLS denies by default, so only the
-- service-role edge functions can ever read a refresh token.

create table month_playlists (
  user_id      uuid not null references auth.users(id) on delete cascade,
  month        text not null,            -- 'YYYY-MM'
  playlist_id  text not null,
  playlist_url text not null,
  synced_at    timestamptz not null default now(),
  primary key (user_id, month)
);
alter table month_playlists enable row level security;
create policy month_playlists_select_own on month_playlists
  for select using (user_id = auth.uid());
-- Writes are service-role only.

alter table profiles add column spotify_connected boolean not null default false;
