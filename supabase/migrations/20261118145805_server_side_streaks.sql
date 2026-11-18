-- Streaks become server-authoritative.
--
-- They were computed on the device and written straight to profiles, and the
-- UPDATE policy (auth.uid() = id) covered every column — so a single PATCH to
-- /rest/v1/profiles could set current_streak to anything. The read-modify-write
-- was also racy, and longest_streak was never written by any code path, so
-- "best streak" sat at 0 forever.
--
-- Now a trigger on posts owns all three columns, and the client is granted
-- UPDATE only on the columns it actually writes.

create or replace function public.apply_streak()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  post_day date := (new.created_at at time zone 'utc')::date;
  prev_day date;
  streak   int;
begin
  select last_post_date, current_streak
    into prev_day, streak
  from profiles
  where id = new.user_id
  for update;

  -- Shouldn't happen (one_post_per_utc_day), but don't double-count if it does.
  if prev_day = post_day then
    return new;
  end if;

  if prev_day = post_day - 1 then
    streak := coalesce(streak, 0) + 1;   -- consecutive UTC day
  else
    streak := 1;                         -- first post, or a gap
  end if;

  update profiles
  set current_streak = streak,
      longest_streak = greatest(coalesce(longest_streak, 0), streak),
      last_post_date = post_day
  where id = new.user_id;

  return new;
end;
$$;

drop trigger if exists posts_apply_streak on public.posts;
create trigger posts_apply_streak
after insert on public.posts
for each row execute function public.apply_streak();

-- Column-level privileges, since RLS can't restrict columns. The streak
-- columns are now writable only by the trigger (SECURITY DEFINER) and the
-- service role. Add a column here if the client ever needs to write one —
-- e.g. username, when a rename screen exists.
revoke update on table public.profiles from anon, authenticated;
grant  update (avatar_url, apple_music_profile) on table public.profiles to authenticated;

-- Backfill longest_streak for anyone who predates the trigger.
update public.profiles
set longest_streak = greatest(coalesce(longest_streak, 0), coalesce(current_streak, 0))
where coalesce(longest_streak, 0) < coalesce(current_streak, 0);
