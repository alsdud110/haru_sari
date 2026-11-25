-- 나의 루틴 공유 1단계 (PLAN_FRIEND_SHARE_STEP1.md)
-- 여러 번 실행해도 안전하게 썼다 (if not exists / create or replace / drop policy if exists).
--
-- 구조
--   routine_shares : 계정당 한 줄. 초대 코드 + 공유하는 루틴 스냅숏 + 닉네임·미니미 모습
--                    줄이 있으면 공유 중, 없으면 공유 안 함. 멈추면 줄을 지우므로 코드도 사라진다.
--   friend_follows : (받은 사람 follower, 공유한 사람 owner). 친구는 한 사람당 10명까지.
--                    공유를 멈추면 그 사람을 따르던 줄도 함께 지운다.
--   share_lookups  : 없는 코드 조회 횟수 (계정·날짜별). 하루 20번을 넘으면 조회를 막는다 (코드 무작위 대입 방지).
--
-- 다른 사람의 표 줄은 어떤 표에서도 직접 읽을 수 없다. 남의 공유는 아래 함수가 정해진 칸만 돌려준다.
-- 앱이 보낸 값은 믿지 않는다: save_routine_share 가 칸을 골라내고 길이·범위를 다시 검사한다.
-- 메모·알림 여부·쉬는 상태는 받지도 저장하지도 않는다.

-- ───────── 테이블 ─────────

create table if not exists public.routine_shares (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  code       text not null unique check (code ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$'),
  nickname   text not null default '',
  look       jsonb not null default '{}'::jsonb,
  routines   jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.friend_follows (
  follower   uuid not null references auth.users (id) on delete cascade,
  owner      uuid not null references auth.users (id) on delete cascade,
  alarm      boolean not null default false, -- 2단계(친구 루틴 알림)에서 쓴다
  created_at timestamptz not null default now(),
  primary key (follower, owner),
  check (follower <> owner)
);

create index if not exists friend_follows_owner_idx on public.friend_follows (owner);

create table if not exists public.share_lookups (
  user_id uuid not null references auth.users (id) on delete cascade,
  day     date not null,
  misses  int  not null default 0,
  primary key (user_id, day)
);

alter table public.routine_shares enable row level security;
alter table public.friend_follows enable row level security;
alter table public.share_lookups  enable row level security;

-- 내 공유 줄은 읽기만 (코드·스냅숏 확인용). 만들기·고치기·지우기는 함수로만 → 코드를 직접 정할 수 없다.
drop policy if exists "read own routine share" on public.routine_shares;
create policy "read own routine share" on public.routine_shares
  for select to authenticated using (user_id = (select auth.uid()));

-- 내가 추가한 친구 줄만 읽고 지운다 (친구 끊기). 추가는 follow_share 로만.
drop policy if exists "read own follows" on public.friend_follows;
create policy "read own follows" on public.friend_follows
  for select to authenticated using (follower = (select auth.uid()));

drop policy if exists "delete own follows" on public.friend_follows;
create policy "delete own follows" on public.friend_follows
  for delete to authenticated using (follower = (select auth.uid()));

-- share_lookups 는 정책 없음 = 앱에서 직접 못 건드린다 (함수만 쓴다).

-- ───────── 내부 도우미 (앱에서 부를 수 없다) ─────────

-- 헷갈리는 0 O 1 I L 을 뺀 31자 중 8자.
create or replace function public._new_share_code()
returns text language plpgsql set search_path = '' as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  bytes bytea := uuid_send(gen_random_uuid()) || uuid_send(gen_random_uuid());
  out text := '';
  i int := 0;
  b int;
begin
  -- 248 이상은 버려서 31로 나눈 나머지가 고르게 나오게 한다.
  while length(out) < 8 loop
    if i >= length(bytes) then
      bytes := uuid_send(gen_random_uuid());
      i := 0;
    end if;
    b := get_byte(bytes, i);
    i := i + 1;
    if b < 248 then
      out := out || substr(alphabet, (b % 31) + 1, 1);
    end if;
  end loop;
  return out;
end $$;

-- 입력 코드를 8자로 정규화. HARU- · 하이픈 · 공백 · 소문자를 받아 준다. 형식이 틀리면 null.
create or replace function public._normalize_share_code(p_code text)
returns text language plpgsql immutable set search_path = '' as $$
declare c text;
begin
  if p_code is null or length(p_code) > 40 then return null; end if;
  c := upper(regexp_replace(p_code, '[\s-]', '', 'g'));
  if left(c, 4) = 'HARU' and length(c) = 12 then c := substr(c, 5); end if;
  if c !~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$' then return null; end if;
  return c;
end $$;

-- 정수 0..max 인지
create or replace function public._is_small_int(v jsonb, max_value int)
returns boolean language sql immutable set search_path = '' as $$
  -- AND 는 계산 순서가 정해져 있지 않아서, 숫자일 때만 숫자로 바꾸도록 CASE 로 나눈다
  select case
    when jsonb_typeof(v) = 'number' then
      (v #>> '{}')::numeric = floor((v #>> '{}')::numeric)
      and (v #>> '{}')::numeric between 0 and max_value
    else false
  end
$$;

-- 공유 루틴 스냅숏 검사. 정해진 칸만 남긴다. 틀리면 예외.
create or replace function public._clean_shared_routines(p jsonb)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare
  r jsonb;
  w jsonb;
  out jsonb := '[]'::jsonb;
  days jsonb;
  ids text[] := '{}';
begin
  if p is null or jsonb_typeof(p) <> 'array' then raise exception 'invalid routines'; end if;
  if jsonb_array_length(p) > 30 or octet_length(p::text) > 16384 then raise exception 'too many routines'; end if;

  for r in select value from jsonb_array_elements(p) loop
    if jsonb_typeof(r) <> 'object' then raise exception 'invalid routine'; end if;

    -- id
    if coalesce(jsonb_typeof(r->'id'), '') <> 'string' or length(r->>'id') not between 1 and 40 then raise exception 'invalid id'; end if;
    if (r->>'id') = any(ids) then raise exception 'duplicate id'; end if;
    ids := ids || (r->>'id');

    -- 이름 (앱은 20자까지, 예전 루틴을 위해 30자까지 받는다)
    if coalesce(jsonb_typeof(r->'name'), '') <> 'string' or length(btrim(r->>'name')) not between 1 and 30 then raise exception 'invalid name'; end if;

    -- 이모지 (합성 이모지도 들어가게 바이트로 32까지)
    if coalesce(jsonb_typeof(r->'emoji'), '') <> 'string' or octet_length(r->>'emoji') not between 1 and 32 then raise exception 'invalid emoji'; end if;

    -- 시각: 없거나 null 이면 '언제든', 아니면 0..1439
    if r ? 'minute' and jsonb_typeof(r->'minute') <> 'null' and not public._is_small_int(r->'minute', 1439) then
      raise exception 'invalid minute';
    end if;

    -- 요일: 1..7, 겹치지 않게, 1~7개
    if coalesce(jsonb_typeof(r->'weekdays'), '') <> 'array' or jsonb_array_length(r->'weekdays') not between 1 and 7 then raise exception 'invalid weekdays'; end if;
    days := '[]'::jsonb;
    for w in select value from jsonb_array_elements(r->'weekdays') loop
      if not public._is_small_int(w, 7) then raise exception 'invalid weekday'; end if;
      if (w #>> '{}')::numeric::int < 1 or days @> jsonb_build_array((w #>> '{}')::numeric::int) then
        raise exception 'invalid weekday';
      end if;
      days := days || jsonb_build_array((w #>> '{}')::numeric::int);
    end loop;

    -- 카테고리 (선택)
    if r ? 'category' and (jsonb_typeof(r->'category') <> 'string' or length(r->>'category') > 20) then raise exception 'invalid category'; end if;

    out := out || jsonb_build_array(jsonb_build_object(
      'id', r->>'id',
      'name', btrim(r->>'name'),
      'emoji', r->>'emoji',
      'minute', case when jsonb_typeof(r->'minute') = 'number' then (r->>'minute')::numeric::int end,
      'weekdays', days,
      'category', coalesce(r->>'category', '기타')
    ));
  end loop;

  return out;
end $$;

-- 미니미 모습 검사. 정해진 키만 남긴다. 틀린 값은 버린다 (모습이 조금 덜 나와도 공유는 된다).
create or replace function public._clean_share_look(p jsonb)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare
  k text;
  m jsonb := '{}'::jsonb;
  colors jsonb := '{}'::jsonb;
  out jsonb := '{}'::jsonb;
  e record;
begin
  if p is null or jsonb_typeof(p) <> 'object' or octet_length(p::text) > 2048 then return '{}'::jsonb; end if;

  if jsonb_typeof(p->'minimi') = 'object' then
    foreach k in array array['skin','hair','outfit','hairStyle','eyes','mouth','pattern','bottom','bottomColor'] loop
      if public._is_small_int(p->'minimi'->k, 99) then m := m || jsonb_build_object(k, (p->'minimi'->>k)::numeric::int); end if;
    end loop;
  end if;
  out := out || jsonb_build_object('minimi', m);

  foreach k in array array['outfitId','accessoryId','earringId','bottomId'] loop
    if jsonb_typeof(p->k) = 'string' and length(p->>k) between 1 and 40 and (p->>k) ~ '^[a-z0-9_]+$' then
      out := out || jsonb_build_object(k, p->>k);
    end if;
  end loop;

  if jsonb_typeof(p->'itemColors') = 'object' then
    for e in select key, value from jsonb_each(p->'itemColors') limit 8 loop
      if length(e.key) between 1 and 40 and e.key ~ '^[a-z0-9_]+$' and public._is_small_int(e.value, 99) then
        colors := colors || jsonb_build_object(e.key, (e.value #>> '{}')::numeric::int);
      end if;
    end loop;
  end if;
  out := out || jsonb_build_object('itemColors', colors);

  return out;
end $$;

revoke all on function public._new_share_code() from public, anon, authenticated;
revoke all on function public._normalize_share_code(text) from public, anon, authenticated;
revoke all on function public._is_small_int(jsonb, int) from public, anon, authenticated;
revoke all on function public._clean_shared_routines(jsonb) from public, anon, authenticated;
revoke all on function public._clean_share_look(jsonb) from public, anon, authenticated;

-- ───────── 앱이 부르는 함수 ─────────

-- 공유 만들기 / 스냅숏 갱신. 처음이면 새 코드를 만든다. 지금 코드를 돌려준다.
create or replace function public.save_routine_share(p_nickname text, p_look jsonb, p_routines jsonb)
returns text language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  v_routines jsonb;
  v_look jsonb;
  v_nick text := left(btrim(coalesce(p_nickname, '')), 20);
  v_code text;
  tries int := 0;
begin
  if uid is null then raise exception 'not signed in'; end if;
  v_routines := public._clean_shared_routines(p_routines);
  v_look := public._clean_share_look(p_look);

  update public.routine_shares
     set nickname = v_nick, look = v_look, routines = v_routines, updated_at = now()
   where user_id = uid
  returning code into v_code;
  if v_code is not null then return v_code; end if;

  loop
    tries := tries + 1;
    begin
      insert into public.routine_shares (user_id, code, nickname, look, routines)
      values (uid, public._new_share_code(), v_nick, v_look, v_routines)
      returning code into v_code;
      return v_code;
    exception when unique_violation then
      -- 같은 계정이 동시에 두 번 부른 경우: 이미 만들어진 줄을 쓴다
      select r.code into v_code from public.routine_shares r where r.user_id = uid;
      if v_code is not null then return v_code; end if;
      if tries >= 5 then raise; end if; -- 코드가 겹침 (거의 없음) → 다시
    end;
  end loop;
end $$;

-- 공유 멈추기. 코드가 사라지고, 나를 친구로 추가한 줄도 함께 지운다.
create or replace function public.stop_routine_share()
returns void language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in'; end if;
  delete from public.friend_follows where owner = uid;
  delete from public.routine_shares where user_id = uid;
end $$;

-- 코드로 구경. status: ok / not_found / limited
create or replace function public.get_shared_routines(p_code text)
returns table (status text, nickname text, look jsonb, routines jsonb, is_me boolean, following boolean)
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  v_code text := public._normalize_share_code(p_code);
  v_misses int;
  s public.routine_shares;
begin
  if uid is null then raise exception 'not signed in'; end if;

  select l.misses into v_misses
    from public.share_lookups l where l.user_id = uid and l.day = current_date;
  if coalesce(v_misses, 0) >= 20 then
    return query select 'limited'::text, null::text, null::jsonb, null::jsonb, false, false;
    return;
  end if;

  if v_code is not null then
    select * into s from public.routine_shares r where r.code = v_code;
  end if;

  if s.user_id is null then
    delete from public.share_lookups l where l.user_id = uid and l.day < current_date;
    insert into public.share_lookups as l (user_id, day, misses) values (uid, current_date, 1)
      on conflict (user_id, day) do update set misses = l.misses + 1;
    return query select 'not_found'::text, null::text, null::jsonb, null::jsonb, false, false;
    return;
  end if;

  return query select
    'ok'::text, s.nickname, s.look, s.routines,
    s.user_id = uid,
    exists (select 1 from public.friend_follows f where f.follower = uid and f.owner = s.user_id);
end $$;

-- 친구 추가. reason: not_found / self / limit (친구 10명)
create or replace function public.follow_share(p_code text)
returns table (ok boolean, reason text)
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  v_code text := public._normalize_share_code(p_code);
  v_owner uuid;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if v_code is not null then
    select r.user_id into v_owner from public.routine_shares r where r.code = v_code;
  end if;
  if v_owner is null then return query select false, 'not_found'::text; return; end if;
  if v_owner = uid then return query select false, 'self'::text; return; end if;

  if exists (select 1 from public.friend_follows f where f.follower = uid and f.owner = v_owner) then
    return query select true, null::text; return;
  end if;

  -- 같은 사람이 동시에 여러 번 눌러 상한을 넘지 않게 잠근다
  perform pg_advisory_xact_lock(hashtextextended(uid::text, 0));
  if (select count(*) from public.friend_follows f where f.follower = uid) >= 10 then
    return query select false, 'limit'::text; return;
  end if;

  insert into public.friend_follows (follower, owner) values (uid, v_owner) on conflict do nothing;
  return query select true, null::text;
end $$;

-- 내 친구들의 공유 루틴. 지금 공유 중인 사람만.
create or replace function public.my_friend_routines()
returns table (owner uuid, nickname text, look jsonb, routines jsonb, updated_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in'; end if;
  return query
    select s.user_id, s.nickname, s.look, s.routines, s.updated_at
      from public.friend_follows f
      join public.routine_shares s on s.user_id = f.owner
     where f.follower = uid
     order by f.created_at;
end $$;

revoke all on function public.save_routine_share(text, jsonb, jsonb) from public, anon;
revoke all on function public.stop_routine_share() from public, anon;
revoke all on function public.get_shared_routines(text) from public, anon;
revoke all on function public.follow_share(text) from public, anon;
revoke all on function public.my_friend_routines() from public, anon;
grant execute on function public.save_routine_share(text, jsonb, jsonb) to authenticated;
grant execute on function public.stop_routine_share() to authenticated;
grant execute on function public.get_shared_routines(text) to authenticated;
grant execute on function public.follow_share(text) to authenticated;
grant execute on function public.my_friend_routines() to authenticated;
