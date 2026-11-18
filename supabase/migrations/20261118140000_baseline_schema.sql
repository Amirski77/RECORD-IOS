-- Baseline: the schema as it stood before any migration existed.
--
-- Everything up to this point was applied by hand in the Supabase dashboard,
-- so git had no record of it and nothing could tell whether the code and the
-- database agreed. (They didn't — see 20261118145755_spotify_connections.)
-- This file is that history, reconstructed from the live catalog, so a fresh
-- database can be rebuilt by replaying this plus the migrations after it.
--
-- Don't "fix" anything here. The improvements are the later migrations; this
-- is deliberately the original, warts and all.

-- ─── Tables ──────────────────────────────────────────────────────────────

create table if not exists public.profiles (
  id                  uuid not null primary key references auth.users(id) on delete cascade,
  username            text not null unique,
  created_at          timestamptz default now(),
  current_streak      integer default 0 not null,
  last_post_date      date,
  apple_music_profile text,
  spotify_profile     text,
  longest_streak      integer default 0 not null,
  avatar_url          text
);

create table if not exists public.posts (
  id              bigint generated always as identity primary key,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  track_id        text not null,
  track_name      text not null,
  artist_name     text not null,
  album_art_url   text not null,
  preview_url     text,
  apple_music_url text,
  spotify_url     text,
  note            text,
  created_at      timestamptz default now()
);

create table if not exists public.reactions (
  id         bigint generated always as identity primary key,
  user_id    uuid   not null references public.profiles(id) on delete cascade,
  post_id    bigint not null references public.posts(id)    on delete cascade,
  type       text   not null,
  created_at timestamptz default now(),
  unique (user_id, post_id)
);

create table if not exists public.friendships (
  id           uuid default gen_random_uuid() primary key,
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status       text not null check (status = any (array['pending', 'accepted'])),
  created_at   timestamptz default now() not null,
  check (requester_id <> addressee_id),
  unique (requester_id, addressee_id)
);

create table if not exists public.invites (
  code       text not null primary key,
  owner_id   uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz default now() not null
);

-- ─── Indexes ─────────────────────────────────────────────────────────────

-- One post per person per UTC day. The real guard behind PostConfirmView's
-- friendly "you've already posted today" message.
create unique index if not exists one_post_per_utc_day
  on public.posts (user_id, ((created_at at time zone 'UTC')::date));
create index if not exists posts_user_created_idx
  on public.posts (user_id, created_at desc);

create index if not exists friendships_requester_idx on public.friendships (requester_id);
create index if not exists friendships_addressee_idx on public.friendships (addressee_id);
-- One friendship per pair, whichever direction it was created in.
create unique index if not exists friendships_pair_uniq
  on public.friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));

create index if not exists invites_owner_idx on public.invites (owner_id);

-- ─── Row level security ──────────────────────────────────────────────────

alter table public.profiles    enable row level security;
alter table public.posts       enable row level security;
alter table public.reactions   enable row level security;
alter table public.friendships enable row level security;
alter table public.invites     enable row level security;

create policy "Profiles are viewable by authenticated users" on public.profiles
  for select to authenticated using (true);
create policy "Users can insert their own profile" on public.profiles
  for insert to authenticated with check (auth.uid() = id);
create policy "Users can update their own profile" on public.profiles
  for update to authenticated using (auth.uid() = id);

-- NOTE: no daily-lock condition here. This is the hole that
-- 20261118145734_enforce_daily_lock.sql closes.
create policy "posts_select" on public.posts
  for select to authenticated using (
    auth.uid() = user_id
    or exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
        and ((f.requester_id = auth.uid() and f.addressee_id = posts.user_id)
          or (f.addressee_id = auth.uid() and f.requester_id = posts.user_id))
    )
  );
create policy "Users can insert their own posts" on public.posts
  for insert to authenticated with check (auth.uid() = user_id);
create policy "Users can delete their own posts" on public.posts
  for delete to authenticated using (auth.uid() = user_id);

create policy "Reactions are viewable by authenticated users" on public.reactions
  for select to authenticated using (true);
create policy "Users can insert their own reactions" on public.reactions
  for insert to authenticated with check (auth.uid() = user_id);
create policy "Users can update their own reactions" on public.reactions
  for update to authenticated using (auth.uid() = user_id);
create policy "Users can delete their own reactions" on public.reactions
  for delete to authenticated using (auth.uid() = user_id);

create policy "friendships_select" on public.friendships
  for select to authenticated using (auth.uid() = requester_id or auth.uid() = addressee_id);
create policy "friendships_insert" on public.friendships
  for insert to authenticated with check (auth.uid() = requester_id and status = 'pending');
create policy "friendships_update" on public.friendships
  for update to authenticated
  using (auth.uid() = addressee_id)
  with check (auth.uid() = addressee_id and status = 'accepted');
create policy "friendships_delete" on public.friendships
  for delete to authenticated using (auth.uid() = requester_id or auth.uid() = addressee_id);

create policy "invites_select" on public.invites
  for select to authenticated using (auth.uid() = owner_id);
create policy "invites_insert" on public.invites
  for insert to authenticated with check (auth.uid() = owner_id);
create policy "invites_delete" on public.invites
  for delete to authenticated using (auth.uid() = owner_id);

-- ─── Storage ─────────────────────────────────────────────────────────────

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- NOTE: no owner check, no size or mime limit, no delete policy. Fixed in
-- 20261118145745_harden_avatar_storage.sql.
create policy "Anyone can view avatars" on storage.objects
  for select to public using (bucket_id = 'avatars');
create policy "Users can upload their own avatar" on storage.objects
  for insert to authenticated with check (bucket_id = 'avatars');
create policy "Users can update their own avatar" on storage.objects
  for update to authenticated using (bucket_id = 'avatars');

-- ─── Functions ───────────────────────────────────────────────────────────
--
-- All SECURITY DEFINER: they do the joins server-side so the client never
-- needs read access to rows it shouldn't see. today_feed() is the important
-- one — it decides what a locked row reveals.

create or replace function public.today_feed()
returns table (id bigint, user_id uuid, username text, avatar_url text,
               track_name text, artist_name text, album_art_url text,
               preview_url text, apple_music_url text, spotify_url text,
               note text, created_at timestamptz, locked boolean)
language sql stable security definer set search_path to 'public'
as $function$
  with day_start as (
    select (date_trunc('day', now() at time zone 'utc') at time zone 'utc') as t
  ),
  has_posted as (
    select exists (
      select 1 from posts po cross join day_start d
      where po.user_id = auth.uid()
        and po.created_at >= d.t
    ) as yes
  ),
  feed as (
    select
      po.id, po.user_id, pr.username, pr.avatar_url,
      po.track_name, po.artist_name, po.album_art_url, po.preview_url,
      po.apple_music_url, po.spotify_url, po.note, po.created_at,
      (hp.yes or po.user_id = auth.uid()) as unlocked
    from posts po
    join profiles pr on pr.id = po.user_id
    cross join day_start d
    cross join has_posted hp
    where po.created_at >= d.t
      and (
        po.user_id = auth.uid()
        or exists (
          select 1 from friendships f
          where f.status = 'accepted'
            and least(f.requester_id, f.addressee_id)
                = least(auth.uid(), po.user_id)
            and greatest(f.requester_id, f.addressee_id)
                = greatest(auth.uid(), po.user_id)
        )
      )
  )
  select
    f.id, f.user_id, f.username, f.avatar_url,
    case when f.unlocked then f.track_name      end,
    case when f.unlocked then f.artist_name     end,
    case when f.unlocked then f.album_art_url   end,
    case when f.unlocked then f.preview_url     end,
    case when f.unlocked then f.apple_music_url end,
    case when f.unlocked then f.spotify_url     end,
    case when f.unlocked then f.note            end,
    f.created_at,
    not f.unlocked
  from feed f
  order by f.created_at desc;
$function$;

create or replace function public.friends_list()
returns table (id uuid, username text, avatar_url text,
               current_streak integer, posted_today boolean)
language sql stable security definer set search_path to 'public'
as $function$
  select
    p.id,
    p.username,
    p.avatar_url,
    p.current_streak,
    exists (
      select 1 from posts po
      where po.user_id = p.id
        and po.created_at >= (date_trunc('day', now() at time zone 'utc') at time zone 'utc')
    )
  from friendships f
  join profiles p
    on p.id = case when f.requester_id = auth.uid()
                   then f.addressee_id
                   else f.requester_id end
  where f.status = 'accepted'
    and auth.uid() in (f.requester_id, f.addressee_id)
  order by p.username;
$function$;

create or replace function public.friend_requests()
returns table (id uuid, username text, avatar_url text, record_count bigint)
language sql stable security definer set search_path to 'public'
as $function$
  select
    p.id,
    p.username,
    p.avatar_url,
    (select count(*) from posts po where po.user_id = p.id)
  from friendships f
  join profiles p on p.id = f.requester_id
  where f.addressee_id = auth.uid()
    and f.status = 'pending'
  order by f.created_at desc;
$function$;

create or replace function public.search_users(q text)
returns table (id uuid, username text, avatar_url text, status text)
language sql stable security definer set search_path to 'public'
as $function$
  select
    p.id,
    p.username,
    p.avatar_url,
    coalesce((
      select case
        when f.status = 'accepted'        then 'friends'
        when f.requester_id = auth.uid()  then 'pending_out'
        else                                   'pending_in'
      end
      from friendships f
      where least(f.requester_id, f.addressee_id) = least(p.id, auth.uid())
        and greatest(f.requester_id, f.addressee_id) = greatest(p.id, auth.uid())
      limit 1
    ), 'none')
  from profiles p
  where p.username ilike q || '%'
    and p.id <> auth.uid()
  order by p.username
  limit 20;
$function$;

create or replace function public.my_invite_code()
returns text
language plpgsql security definer set search_path to 'public'
as $function$
declare
  existing text;
  fresh text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select code into existing from invites where owner_id = auth.uid();
  if existing is not null then
    return existing;
  end if;

  -- 8 chars from a base32-ish alphabet: no 0/O/1/I, so it survives being
  -- read aloud or retyped.
  loop
    fresh := (
      select string_agg(
        substr('abcdefghjkmnpqrstuvwxyz23456789',
               floor(random() * 31)::int + 1, 1), '')
      from generate_series(1, 8)
    );
    exit when not exists (select 1 from invites where code = fresh);
  end loop;

  insert into invites (code, owner_id) values (fresh, auth.uid());
  return fresh;
end;
$function$;

create or replace function public.redeem_invite(invite_code text)
returns json
language plpgsql security definer set search_path to 'public'
as $function$
declare
  owner uuid;
  owner_name text;
begin
  select i.owner_id, p.username into owner, owner_name
  from invites i join profiles p on p.id = i.owner_id
  where i.code = invite_code;

  if owner is null then
    return json_build_object('ok', false, 'reason', 'not_found');
  end if;

  if owner = auth.uid() then
    return json_build_object('ok', false, 'reason', 'self');
  end if;

  -- Already connected either way? Make sure it's accepted and report success.
  if exists (
    select 1 from friendships f
    where least(f.requester_id, f.addressee_id) = least(owner, auth.uid())
      and greatest(f.requester_id, f.addressee_id) = greatest(owner, auth.uid())
  ) then
    update friendships
    set status = 'accepted'
    where least(requester_id, addressee_id) = least(owner, auth.uid())
      and greatest(requester_id, addressee_id) = greatest(owner, auth.uid());
    return json_build_object('ok', true, 'username', owner_name);
  end if;

  insert into friendships (requester_id, addressee_id, status)
  values (owner, auth.uid(), 'accepted');

  return json_build_object('ok', true, 'username', owner_name);
end;
$function$;
