create extension if not exists pg_net with schema extensions;

create or replace function public.notify_message_push()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  notification_secret text;
begin
  select decrypted_secret
    into notification_secret
  from vault.decrypted_secrets
  where name = 'message_notification_secret'
  limit 1;

  if notification_secret is null or trim(notification_secret) = '' then
    return new;
  end if;

  perform net.http_post(
    url := 'https://vgtgcjnrsladdharzkwn.supabase.co/functions/v1/send-message-notification',
    headers := jsonb_build_object(
      'Content-Type',
      'application/json',
      'x-message-notification-secret',
      notification_secret
    ),
    body := jsonb_build_object('messageId', new.id::text),
    timeout_milliseconds := 5000
  );

  return new;
exception
  when others then
    return new;
end;
$$;

drop trigger if exists notify_message_push_on_insert on public.messages;
create trigger notify_message_push_on_insert
  after insert on public.messages
  for each row
  execute function public.notify_message_push();
