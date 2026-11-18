-- Make signup atomic.
--
-- AuthView.signUp() created the auth user, then inserted the profile row as a
-- second, separate request. When the second one failed — a taken username,
-- a dropped connection — the result was an account that can log in but has no
-- profile, which the app cannot recover from. That already happened three
-- times in this database (me+test@, he+test@, amirtest@).
--
-- Now a trigger on auth.users creates the profile in the same transaction as
-- the account. Either both exist or neither does.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  wanted text := nullif(btrim(new.raw_user_meta_data ->> 'username'), '');
begin
  -- An older build of the app sends no username metadata and inserts the
  -- profile row itself. Leave it to do that rather than failing its signup.
  -- This branch can go once no old builds are in the wild.
  if wanted is null then
    return new;
  end if;

  insert into public.profiles (id, username)
  values (new.id, wanted)
  on conflict (id) do nothing;

  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Shape rules for a username. Existing rows are mixed case (Donny, AMIR), so
-- case is allowed; what's rejected is whitespace, punctuation and silly
-- lengths, which previously nothing checked.
alter table public.profiles
  drop constraint if exists profiles_username_shape;
alter table public.profiles
  add  constraint profiles_username_shape
  check (username ~ '^[A-Za-z0-9._]{2,20}$');

-- `username` was only UNIQUE case-sensitively, so "amir" and "AMIR" could
-- both be registered — two accounts that look identical in the feed, and
-- search_users() uses ilike so both would come back for one query.
create unique index if not exists profiles_username_lower_key
  on public.profiles (lower(username));

-- The signup form needs to check availability before an account exists, so
-- this is deliberately callable by anon. It discloses only what any signup
-- form inevitably discloses.
create or replace function public.username_available(u text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select btrim(u) ~ '^[A-Za-z0-9._]{2,20}$'
     and not exists (
       select 1 from profiles where lower(username) = lower(btrim(u))
     );
$$;

grant execute on function public.username_available(text) to anon, authenticated;
