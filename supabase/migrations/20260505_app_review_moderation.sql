create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  content_type text not null,
  content_id text not null,
  content_owner_id uuid references auth.users(id) on delete set null,
  reason text not null,
  content_preview text,
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now(),
  review_due_at timestamptz not null default (now() + interval '24 hours'),
  reviewed_at timestamptz,
  reviewer_id uuid references auth.users(id) on delete set null
);

create index if not exists content_reports_status_idx on public.content_reports(status, created_at desc);
create index if not exists content_reports_reporter_idx on public.content_reports(reporter_id, created_at desc);
create index if not exists content_reports_owner_idx on public.content_reports(content_owner_id, created_at desc);

alter table public.content_reports enable row level security;

drop policy if exists "Users can create content reports" on public.content_reports;
create policy "Users can create content reports"
  on public.content_reports
  for insert
  to authenticated
  with check (auth.uid() = reporter_id);

drop policy if exists "Users can read own content reports" on public.content_reports;
create policy "Users can read own content reports"
  on public.content_reports
  for select
  to authenticated
  using (auth.uid() = reporter_id);

drop policy if exists "Admins can manage content reports" on public.content_reports;
create policy "Admins can manage content reports"
  on public.content_reports
  for all
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role in ('admin', 'super_admin')
    )
  )
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role in ('admin', 'super_admin')
    )
  );

create table if not exists public.blocked_users (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  reason text,
  source_type text,
  source_id text,
  created_at timestamptz not null default now(),
  unique (blocker_id, blocked_user_id),
  check (blocker_id <> blocked_user_id)
);

create index if not exists blocked_users_blocker_idx on public.blocked_users(blocker_id, created_at desc);
create index if not exists blocked_users_blocked_idx on public.blocked_users(blocked_user_id, created_at desc);

alter table public.blocked_users enable row level security;

drop policy if exists "Users can read own blocks" on public.blocked_users;
create policy "Users can read own blocks"
  on public.blocked_users
  for select
  to authenticated
  using (auth.uid() = blocker_id);

drop policy if exists "Users can create own blocks" on public.blocked_users;
create policy "Users can create own blocks"
  on public.blocked_users
  for insert
  to authenticated
  with check (auth.uid() = blocker_id);

drop policy if exists "Users can update own blocks" on public.blocked_users;
create policy "Users can update own blocks"
  on public.blocked_users
  for update
  to authenticated
  using (auth.uid() = blocker_id)
  with check (auth.uid() = blocker_id);

drop policy if exists "Users can delete own blocks" on public.blocked_users;
create policy "Users can delete own blocks"
  on public.blocked_users
  for delete
  to authenticated
  using (auth.uid() = blocker_id);

drop policy if exists "Admins can read all blocks" on public.blocked_users;
create policy "Admins can read all blocks"
  on public.blocked_users
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role in ('admin', 'super_admin')
    )
  );

create table if not exists public.user_terms_acceptances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  terms_version text not null,
  surface text not null,
  accepted_at timestamptz not null default now(),
  unique (user_id, terms_version, surface)
);

create index if not exists user_terms_acceptances_user_idx
  on public.user_terms_acceptances(user_id, accepted_at desc);

alter table public.user_terms_acceptances enable row level security;

drop policy if exists "Users can create own terms acceptance" on public.user_terms_acceptances;
create policy "Users can create own terms acceptance"
  on public.user_terms_acceptances
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can read own terms acceptance" on public.user_terms_acceptances;
create policy "Users can read own terms acceptance"
  on public.user_terms_acceptances
  for select
  to authenticated
  using (auth.uid() = user_id);
