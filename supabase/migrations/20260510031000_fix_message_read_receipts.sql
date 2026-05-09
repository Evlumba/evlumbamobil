alter table public.messages
  add column if not exists read_at timestamptz,
  add column if not exists is_read boolean not null default false;

update public.messages
set read_at = coalesce(read_at, created_at),
    is_read = true
where is_read = true
  and read_at is null;

create or replace function public.mark_conversation_read(conversation_uuid uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  updated_count integer;
begin
  update public.messages
  set
    read_at = coalesce(read_at, now()),
    is_read = true
  where conversation_id = conversation_uuid
    and sender_id != auth.uid()
    and read_at is null;

  get diagnostics updated_count = row_count;
  return updated_count;
end;
$$;
