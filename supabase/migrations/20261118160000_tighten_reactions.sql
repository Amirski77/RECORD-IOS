-- Reactions could be read and written far too freely.
--
-- SELECT was `using (true)`, so any signed-in user could read every reaction
-- in the database — a full activity graph of who reacts to whom. INSERT only
-- checked that user_id was yours, never that the post was one you're allowed
-- to see, so you could react to a stranger's post by guessing an id. And
-- `type` had no constraint, so any string at all could be stored (the UI
-- renders unknown types as "❓").

alter table public.reactions
  drop constraint if exists reactions_type_check;
alter table public.reactions
  add  constraint reactions_type_check
  check (type = any (array['fire', 'heart', 'sleepy', 'poop']));

-- The FK had no covering index, and the policies below now join through it
-- on every read.
create index if not exists reactions_post_id_idx on public.reactions (post_id);

-- `exists (select ... from posts ...)` is itself subject to my RLS on posts,
-- so this inherits the daily lock for free: while the edition is locked, a
-- locked post's reaction counts aren't readable either.
drop policy if exists "Reactions are viewable by authenticated users" on public.reactions;
create policy reactions_select on public.reactions
for select to authenticated
using (
  exists (select 1 from public.posts p where p.id = reactions.post_id)
);

drop policy if exists "Users can insert their own reactions" on public.reactions;
create policy reactions_insert on public.reactions
for insert to authenticated
with check (
  (select auth.uid()) = user_id
  and exists (select 1 from public.posts p where p.id = reactions.post_id)
);

drop policy if exists "Users can update their own reactions" on public.reactions;
create policy reactions_update on public.reactions
for update to authenticated
using      ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own reactions" on public.reactions;
create policy reactions_delete on public.reactions
for delete to authenticated
using ((select auth.uid()) = user_id);
