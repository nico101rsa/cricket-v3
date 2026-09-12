-- Cricket v3 cloud save. Paste the whole file into Supabase → SQL editor → Run.
-- Safe to run again: everything is "if not exists" / "or replace".
--
-- One row per sync code. The device hashes the code (SHA-256) and sends the
-- hash as p_key; the table itself is not reachable through the API (row level
-- security on, no policies), only these two functions are.

create table if not exists public.cricket_saves (
  key        text primary key,                 -- sha-256 of the sync code, hex
  data       jsonb not null,                   -- the whole game save
  rev        bigint not null default 1,        -- bumps on every write
  updated_at timestamptz not null default now()
);

alter table public.cricket_saves enable row level security;
revoke all on table public.cricket_saves from anon, authenticated;

-- Read: null when the code has no save yet.
create or replace function public.cricket_get(p_key text)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select jsonb_build_object('data', s.data, 'rev', s.rev, 'updated_at', s.updated_at)
  from public.cricket_saves s
  where s.key = p_key;
$$;

-- Write: upsert. With p_expected set, a stale device gets {conflict: true}
-- and the current row instead of overwriting it.
create or replace function public.cricket_put(p_key text, p_payload jsonb, p_expected bigint default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  cur_rev bigint;
  cur_data jsonb;
begin
  if p_key is null or length(p_key) <> 64 then
    raise exception 'bad key';
  end if;
  if pg_column_size(p_payload) > 4000000 then
    raise exception 'save too big';
  end if;
  select s.rev, s.data into cur_rev, cur_data from public.cricket_saves s where s.key = p_key for update;
  if found and p_expected is not null and cur_rev <> p_expected then
    return jsonb_build_object('conflict', true, 'rev', cur_rev, 'data', cur_data);
  end if;
  insert into public.cricket_saves as s (key, data, rev, updated_at)
  values (p_key, p_payload, coalesce(cur_rev, 0) + 1, now())
  on conflict (key) do update set data = excluded.data, rev = s.rev + 1, updated_at = now();
  return jsonb_build_object('conflict', false, 'rev', coalesce(cur_rev, 0) + 1);
end;
$$;

revoke all on function public.cricket_get(text) from public;
revoke all on function public.cricket_put(text, jsonb, bigint) from public;
grant execute on function public.cricket_get(text) to anon, authenticated;
grant execute on function public.cricket_put(text, jsonb, bigint) to anon, authenticated;
