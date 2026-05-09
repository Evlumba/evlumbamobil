create or replace function public.register_push_token(
  p_token text,
  p_platform text default 'unknown',
  p_app_version text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.push_tokens (
    user_id,
    token,
    platform,
    app_version,
    is_active,
    last_seen_at
  )
  values (
    auth.uid(),
    p_token,
    coalesce(nullif(trim(p_platform), ''), 'unknown'),
    nullif(trim(p_app_version), ''),
    true,
    now()
  )
  on conflict (token)
  do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    app_version = excluded.app_version,
    is_active = true,
    last_seen_at = now(),
    updated_at = now();
end;
$$;

revoke all on function public.register_push_token(text, text, text)
  from public, anon, authenticated;

grant execute on function public.register_push_token(text, text, text)
  to authenticated;

create or replace function public.deactivate_push_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return;
  end if;

  update public.push_tokens
  set
    is_active = false,
    last_seen_at = now(),
    updated_at = now()
  where token = p_token
    and user_id = auth.uid();
end;
$$;

revoke all on function public.deactivate_push_token(text)
  from public, anon, authenticated;

grant execute on function public.deactivate_push_token(text)
  to authenticated;
