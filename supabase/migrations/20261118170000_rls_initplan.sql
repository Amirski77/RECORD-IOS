-- Wrap auth.uid() in a scalar subquery in the remaining policies.
--
-- `auth.uid() = user_id` is re-evaluated for every row scanned;
-- `(select auth.uid()) = user_id` is evaluated once per statement and the
-- result reused. Same meaning, and it stops being a per-row function call as
-- these tables grow. The policies rewritten in earlier migrations already do
-- this — these are the ones that weren't touched.

drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile" on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile" on public.profiles
  for update to authenticated
  using      ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists "Users can insert their own posts" on public.posts;
create policy "Users can insert their own posts" on public.posts
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own posts" on public.posts;
create policy "Users can delete their own posts" on public.posts
  for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "friendships_select" on public.friendships;
create policy friendships_select on public.friendships
  for select to authenticated
  using ((select auth.uid()) = requester_id or (select auth.uid()) = addressee_id);

drop policy if exists "friendships_insert" on public.friendships;
create policy friendships_insert on public.friendships
  for insert to authenticated
  with check ((select auth.uid()) = requester_id and status = 'pending');

drop policy if exists "friendships_update" on public.friendships;
create policy friendships_update on public.friendships
  for update to authenticated
  using      ((select auth.uid()) = addressee_id)
  with check ((select auth.uid()) = addressee_id and status = 'accepted');

drop policy if exists "friendships_delete" on public.friendships;
create policy friendships_delete on public.friendships
  for delete to authenticated
  using ((select auth.uid()) = requester_id or (select auth.uid()) = addressee_id);

drop policy if exists "invites_select" on public.invites;
create policy invites_select on public.invites
  for select to authenticated using ((select auth.uid()) = owner_id);

drop policy if exists "invites_insert" on public.invites;
create policy invites_insert on public.invites
  for insert to authenticated with check ((select auth.uid()) = owner_id);

drop policy if exists "invites_delete" on public.invites;
create policy invites_delete on public.invites
  for delete to authenticated using ((select auth.uid()) = owner_id);
