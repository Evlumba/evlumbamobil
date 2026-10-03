-- Mobil uygulamanın yüklediği bucket'lar.
-- avatars:        avatars/{uid}.{ext}             (edit_profile_screen.dart)
-- project-images: projects/{uid}/{timestamp}.{ext} (project_form_screen.dart)
-- İkisi de getPublicUrl kullanıyor; bu yüzden public bucket. Okuma public URL ile,
-- yazma/silme yalnız kullanıcının kendi yolunda.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880, array['image/*']),
  ('project-images', 'project-images', true, 10485760, array['image/*'])
on conflict (id) do nothing;

-- avatars
drop policy if exists "avatars_owner_select" on storage.objects;
drop policy if exists "avatars_owner_insert" on storage.objects;
drop policy if exists "avatars_owner_update" on storage.objects;
drop policy if exists "avatars_owner_delete" on storage.objects;

create policy "avatars_owner_select" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = 'avatars'
    and split_part(storage.filename(name), '.', 1) = (select auth.uid())::text
  );

create policy "avatars_owner_insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = 'avatars'
    and split_part(storage.filename(name), '.', 1) = (select auth.uid())::text
  );

create policy "avatars_owner_update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = 'avatars'
    and split_part(storage.filename(name), '.', 1) = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = 'avatars'
    and split_part(storage.filename(name), '.', 1) = (select auth.uid())::text
  );

create policy "avatars_owner_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = 'avatars'
    and split_part(storage.filename(name), '.', 1) = (select auth.uid())::text
  );

-- project-images
drop policy if exists "project_images_owner_select" on storage.objects;
drop policy if exists "project_images_owner_insert" on storage.objects;
drop policy if exists "project_images_owner_update" on storage.objects;
drop policy if exists "project_images_owner_delete" on storage.objects;

create policy "project_images_owner_select" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'project-images'
    and (storage.foldername(name))[1] = 'projects'
    and (storage.foldername(name))[2] = (select auth.uid())::text
  );

create policy "project_images_owner_insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'project-images'
    and (storage.foldername(name))[1] = 'projects'
    and (storage.foldername(name))[2] = (select auth.uid())::text
  );

create policy "project_images_owner_update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'project-images'
    and (storage.foldername(name))[1] = 'projects'
    and (storage.foldername(name))[2] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'project-images'
    and (storage.foldername(name))[1] = 'projects'
    and (storage.foldername(name))[2] = (select auth.uid())::text
  );

create policy "project_images_owner_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'project-images'
    and (storage.foldername(name))[1] = 'projects'
    and (storage.foldername(name))[2] = (select auth.uid())::text
  );
