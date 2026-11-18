-- Enforce the daily lock in RLS, not just in today_feed().
--
-- today_feed() masks a locked row's track fields, but it was never the lock:
-- posts_select let any accepted friend read the posts table directly, so
-- Friends → tap a friend → their Diary showed today's record in full. The
-- lock now lives on the table; today_feed()'s masking becomes a second layer.

-- "Have I posted today?" — SECURITY DEFINER so it can read posts from inside
-- a policy on posts without recursing. Only ever discloses a boolean about
-- the caller themselves.
create or replace function public.has_posted_today()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from posts
    where user_id = (select auth.uid())
      and created_at >= (date_trunc('day', now() at time zone 'utc') at time zone 'utc')
  );
$$;

revoke all on function public.has_posted_today() from public, anon;
grant execute on function public.has_posted_today() to authenticated;

drop policy if exists "posts_select" on public.posts;

create policy posts_select on public.posts
for select to authenticated
using (
  -- always my own
  (select auth.uid()) = user_id
  or (
    -- an accepted friend, matching friendships_pair_uniq so the index applies
    exists (
      select 1
      from friendships f
      where f.status = 'accepted'
        and least(f.requester_id, f.addressee_id)
            = least((select auth.uid()), posts.user_id)
        and greatest(f.requester_id, f.addressee_id)
            = greatest((select auth.uid()), posts.user_id)
    )
    and (
      -- their past records are always theirs to browse; today's is sealed
      -- until I've posted mine too
      created_at < (date_trunc('day', now() at time zone 'utc') at time zone 'utc')
      or public.has_posted_today()
    )
  )
);
