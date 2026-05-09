set search_path = public, extensions;

create or replace function public.match_designer_project_documents(
  query_embedding extensions.vector(1536),
  match_count int default 20,
  match_threshold float default 0.12,
  p_project_type text default null,
  p_budget_level text default null,
  p_city text default null
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
  join public.designer_projects p on p.id = d.source_id
  where d.source_table = 'designer_projects'
    and d.is_published
    and d.embedding is not null
    and p.is_published
    and (p_project_type is null or p.project_type = p_project_type)
    and (p_budget_level is null or p.budget_level = p_budget_level)
    and (p_city is null or p.location ilike '%' || p_city || '%')
    and 1 - (d.embedding <=> query_embedding) >= match_threshold
  order by d.embedding <=> query_embedding
  limit least(greatest(match_count, 1), 200);
$$;

revoke all on function public.match_designer_project_documents(
  extensions.vector,
  integer,
  double precision,
  text,
  text,
  text
) from public, anon, authenticated;

grant execute on function public.match_designer_project_documents(
  extensions.vector,
  integer,
  double precision,
  text,
  text,
  text
) to service_role;
