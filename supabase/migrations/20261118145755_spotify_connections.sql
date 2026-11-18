-- Spotify connection + monthly playlists.
--
-- This is supabase/sql/spotify.sql, which was written as a "paste into the
-- dashboard" script and never pasted. The app shipped code that selects
-- profiles.spotify_connected, so ProfileView.load() and
-- SettingsView.loadLinks() failed with 42703 on every call and the Diary tab
-- and Settings silently rendered empty.

alter table public.profiles
  add column if not exists spotify_connected boolean not null default false;

create table if not exists public.spotify_connections (
  user_id         uuid primary key references auth.users(id) on delete cascade,
  spotify_user_id text not null,
  display_name    text,
  profile_url     text,
  refresh_token   text not null,
  access_token    text,
  expires_at      timestamptz,
  connected_at    timestamptz not null default now()
);

alter table public.spotify_connections enable row level security;

-- Deliberately no policies: RLS denies by default, so only the service-role
-- edge functions can ever reach a refresh token. The grants go too, so the
-- table isn't even reachable through PostgREST.
revoke all on table public.spotify_connections from anon, authenticated;

create table if not exists public.month_playlists (
  user_id      uuid not null references auth.users(id) on delete cascade,
  month        text not null,                     -- 'YYYY-MM'
  playlist_id  text not null,
  playlist_url text not null,
  synced_at    timestamptz not null default now(),
  primary key (user_id, month)
);

alter table public.month_playlists enable row level security;

drop policy if exists month_playlists_select_own on public.month_playlists;
create policy month_playlists_select_own on public.month_playlists
for select to authenticated
using ((select auth.uid()) = user_id);

-- Writes are service-role only (spotify-playlist edge function).
revoke insert, update, delete on table public.month_playlists from anon, authenticated;
