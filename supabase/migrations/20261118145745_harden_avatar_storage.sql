-- Avatar storage: owner checks, and real limits on the bucket.
--
-- The previous policies checked only `bucket_id = 'avatars'`, so any signed-in
-- user could write any object in the bucket. Paths are `<uid>.jpg`, so that
-- meant overwriting anyone's avatar, and — with no size or mime limit on the
-- bucket — using it as a free file host. There was also no DELETE policy, so
-- removeAvatar()'s storage delete always failed silently.

drop policy if exists "Anyone can view avatars"            on storage.objects;
drop policy if exists "Users can upload their own avatar"  on storage.objects;
drop policy if exists "Users can update their own avatar"  on storage.objects;

-- Public read stays: the bucket is public and avatar URLs are embedded in
-- profiles.avatar_url.
create policy "Avatars are publicly readable"
on storage.objects for select to public
using (bucket_id = 'avatars');

create policy "Users can upload their own avatar"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'avatars'
  and name = (select auth.uid())::text || '.jpg'
);

create policy "Users can update their own avatar"
on storage.objects for update to authenticated
using (
  bucket_id = 'avatars'
  and name = (select auth.uid())::text || '.jpg'
)
with check (
  bucket_id = 'avatars'
  and name = (select auth.uid())::text || '.jpg'
);

create policy "Users can delete their own avatar"
on storage.objects for delete to authenticated
using (
  bucket_id = 'avatars'
  and name = (select auth.uid())::text || '.jpg'
);

-- The client now transcodes to JPEG before upload (ProfileView.uploadAvatar),
-- so a single allowed type is enough and the limit is comfortable for a
-- 512px square.
update storage.buckets
set file_size_limit   = 2097152,            -- 2 MiB
    allowed_mime_types = array['image/jpeg']
where id = 'avatars';
