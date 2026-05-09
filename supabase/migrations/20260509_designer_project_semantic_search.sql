create extension if not exists vector with schema extensions;

set search_path = public, extensions;

create table if not exists public.search_documents (
  id uuid primary key default gen_random_uuid(),
  source_table text not null check (source_table in ('designer_projects')),
  source_id uuid not null,
  designer_id uuid references public.profiles(id) on delete cascade,
  content text not null,
  content_hash text not null,
  metadata jsonb not null default '{}'::jsonb,
  embedding extensions.vector(1536),
  embedding_model text,
  is_published boolean not null default true,
  embedded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source_table, source_id)
);

create index if not exists search_documents_source_idx
  on public.search_documents(source_table, source_id);

create index if not exists search_documents_designer_idx
  on public.search_documents(designer_id)
  where source_table = 'designer_projects' and is_published;

create index if not exists search_documents_embedding_hnsw_idx
  on public.search_documents
  using hnsw (embedding vector_cosine_ops)
  where embedding is not null and is_published;

alter table public.search_documents enable row level security;

create or replace function public.designer_project_search_content(
  p_title text,
  p_project_type text,
  p_location text,
  p_description text,
  p_tags text
)
returns text
language sql
immutable
as $$
  select trim(both from concat_ws(E'\n',
    nullif('Baslik: ' || coalesce(p_title, ''), 'Baslik: '),
    nullif('Mekan: ' || coalesce(p_project_type, ''), 'Mekan: '),
    nullif('Konum: ' || coalesce(p_location, ''), 'Konum: '),
    nullif('Aciklama: ' || coalesce(p_description, ''), 'Aciklama: '),
    nullif('Etiketler: ' || replace(replace(replace(coalesce(p_tags, ''), '{', ''), '}', ''), '"', ''), 'Etiketler: ')
  ));
$$;

create or replace function public.upsert_designer_project_search_document()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_content text;
  v_hash text;
begin
  if tg_op = 'DELETE' then
    delete from public.search_documents
    where source_table = 'designer_projects'
      and source_id = old.id;
    return old;
  end if;

  v_content := public.designer_project_search_content(
    new.title,
    new.project_type,
    new.location,
    new.description,
    new.tags::text
  );
  v_hash := md5(v_content);

  if coalesce(new.is_published, false) then
    insert into public.search_documents (
      source_table,
      source_id,
      designer_id,
      content,
      content_hash,
      metadata,
      is_published
    )
    values (
      'designer_projects',
      new.id,
      new.designer_id,
      v_content,
      v_hash,
      jsonb_build_object(
        'project_type', new.project_type,
        'location', new.location,
        'title', new.title
      ),
      true
    )
    on conflict (source_table, source_id) do update
      set designer_id = excluded.designer_id,
          content = excluded.content,
          content_hash = excluded.content_hash,
          metadata = excluded.metadata,
          is_published = true,
          embedding = case
            when public.search_documents.content_hash is distinct from excluded.content_hash
              then null
            else public.search_documents.embedding
          end,
          embedding_model = case
            when public.search_documents.content_hash is distinct from excluded.content_hash
              then null
            else public.search_documents.embedding_model
          end,
          embedded_at = case
            when public.search_documents.content_hash is distinct from excluded.content_hash
              then null
            else public.search_documents.embedded_at
          end,
          updated_at = now();
  else
    update public.search_documents
      set is_published = false,
          updated_at = now()
    where source_table = 'designer_projects'
      and source_id = new.id;
  end if;

  return new;
end;
$$;

drop trigger if exists designer_project_search_document_sync on public.designer_projects;
create trigger designer_project_search_document_sync
  after insert or update of title, project_type, location, description, tags, is_published, designer_id
  on public.designer_projects
  for each row
  execute function public.upsert_designer_project_search_document();

insert into public.search_documents (
  source_table,
  source_id,
  designer_id,
  content,
  content_hash,
  metadata,
  is_published
)
select
  'designer_projects',
  p.id,
  p.designer_id,
  c.content,
  md5(c.content),
  jsonb_build_object(
    'project_type', p.project_type,
    'location', p.location,
    'title', p.title
  ),
  coalesce(p.is_published, false)
from public.designer_projects p
cross join lateral (
  select public.designer_project_search_content(
    p.title,
    p.project_type,
    p.location,
    p.description,
    p.tags::text
  ) as content
) c
where coalesce(p.is_published, false)
on conflict (source_table, source_id) do update
  set designer_id = excluded.designer_id,
      content = excluded.content,
      content_hash = excluded.content_hash,
      metadata = excluded.metadata,
      is_published = excluded.is_published,
      embedding = case
        when public.search_documents.content_hash is distinct from excluded.content_hash
          then null
        else public.search_documents.embedding
      end,
      embedding_model = case
        when public.search_documents.content_hash is distinct from excluded.content_hash
          then null
        else public.search_documents.embedding_model
      end,
      embedded_at = case
        when public.search_documents.content_hash is distinct from excluded.content_hash
          then null
        else public.search_documents.embedded_at
      end,
      updated_at = now();

create or replace function public.match_designer_project_documents(
  query_embedding extensions.vector(1536),
  match_count int default 20,
  match_threshold float default 0.12,
  p_project_type text default null
)
returns table (
  project_id uuid,
  designer_id uuid,
  similarity float,
  content text
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select
    d.source_id as project_id,
    d.designer_id,
    1 - (d.embedding <=> query_embedding) as similarity,
    d.content
  from public.search_documents d
  where d.source_table = 'designer_projects'
    and d.is_published
    and d.embedding is not null
    and (p_project_type is null or d.metadata->>'project_type' = p_project_type)
    and 1 - (d.embedding <=> query_embedding) >= match_threshold
  order by d.embedding <=> query_embedding
  limit least(greatest(match_count, 1), 200);
$$;

revoke all on function public.match_designer_project_documents(
  extensions.vector,
  integer,
  double precision,
  text
) from public, anon, authenticated;

grant execute on function public.match_designer_project_documents(
  extensions.vector,
  integer,
  double precision,
  text
) to service_role;
