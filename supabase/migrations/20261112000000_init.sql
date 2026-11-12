-- 하루살이 서버 데이터 (Supabase)
-- 여러 번 실행해도 안전하게 썼다 (if not exists / create or replace / drop policy if exists).
--
-- 구조
--   user_state     : 루틴·꾸미기·설정 등 앱 상태 (본인이 직접 읽고 씀)
--   day_logs       : 날짜별 기록 (본인이 직접 읽고 씀)
--   wallets        : 레벨·경험치·코인 (읽기만, 바꾸는 건 아래 함수만)
--   reward_grants  : 날짜별 지급 보상 (날짜당 한 줄 → 중복 지급 방지)
--   purchases      : 구매 내역 (아이템당 한 줄 → 중복 구매 방지)
--
-- 보상 규칙은 정책 PL-BBQESH 와 lib/data/rewards.dart 를 따른다.
--   70% 이상: 20 XP + 10코인, 100%: +10 XP + 5코인, 다음 레벨까지 level*50 XP, 레벨업마다 +20코인

-- ───────── 테이블 ─────────

create table if not exists public.user_state (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  nickname   text not null default '',
  onboarded  boolean not null default false,
  routines   jsonb not null default '[]'::jsonb,
  profile    jsonb not null default '{}'::jsonb,  -- 옷·방·보유 아이템 표시 상태·배지·알림 설정 (지갑 값 제외)
  updated_at timestamptz not null default now()
);

create table if not exists public.day_logs (
  user_id    uuid not null references auth.users (id) on delete cascade,
  day        date not null,
  data       jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

create table if not exists public.wallets (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  level      int not null default 1 check (level >= 1),
  xp         int not null default 0 check (xp >= 0),
  total_xp   int not null default 0 check (total_xp >= 0),
  coins      int not null default 0 check (coins >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.reward_grants (
  user_id    uuid not null references auth.users (id) on delete cascade,
  day        date not null,
  xp         int not null,
  coins      int not null,
  perfect    boolean not null default false,
  granted_at timestamptz not null default now(),
  primary key (user_id, day)
);

create table if not exists public.purchases (
  user_id   uuid not null references auth.users (id) on delete cascade,
  item_id   text not null,
  price     int not null check (price >= 0),
  bought_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

-- ───────── 접근 규칙 (RLS) ─────────

alter table public.user_state    enable row level security;
alter table public.day_logs      enable row level security;
alter table public.wallets       enable row level security;
alter table public.reward_grants enable row level security;
alter table public.purchases     enable row level security;

drop policy if exists "own state" on public.user_state;
create policy "own state" on public.user_state
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists "own logs" on public.day_logs;
create policy "own logs" on public.day_logs
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- 지갑·보상·구매는 읽기만. 쓰기는 아래 security definer 함수로만.
drop policy if exists "read own wallet" on public.wallets;
create policy "read own wallet" on public.wallets
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "read own grants" on public.reward_grants;
create policy "read own grants" on public.reward_grants
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "read own purchases" on public.purchases;
create policy "read own purchases" on public.purchases
  for select to authenticated using (user_id = (select auth.uid()));

-- ───────── 가입 시 기본 행 만들기 ─────────

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.wallets (user_id) values (new.id) on conflict do nothing;
  insert into public.user_state (user_id, nickname)
    values (new.id, coalesce(new.raw_user_meta_data ->> 'name', new.raw_user_meta_data ->> 'full_name', ''))
    on conflict do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ───────── 내부: 경험치 더하기 (레벨업 처리) ─────────

create or replace function public._add_xp(p_user uuid, p_xp int, p_coins int)
returns public.wallets language plpgsql security definer set search_path = '' as $$
declare
  w public.wallets;
  ups int := 0;
begin
  select * into w from public.wallets where user_id = p_user for update;
  if not found then
    insert into public.wallets (user_id) values (p_user) returning * into w;
  end if;
  w.xp := w.xp + p_xp;
  w.total_xp := w.total_xp + p_xp;
  while w.xp >= w.level * 50 loop
    w.xp := w.xp - w.level * 50;
    w.level := w.level + 1;
    ups := ups + 1;
  end loop;
  w.coins := w.coins + p_coins + ups * 20;
  update public.wallets
     set level = w.level, xp = w.xp, total_xp = w.total_xp, coins = w.coins, updated_at = now()
   where user_id = p_user
  returning * into w;
  return w;
end $$;

revoke all on function public._add_xp(uuid, int, int) from public, anon, authenticated;

-- ───────── 하루 보상 받기 ─────────
-- 같은 날짜는 한 번만. 70%로 받은 뒤 그날 100%가 되면 보너스만 한 번 더.
-- 반환: 이번에 새로 받은 xp·coins (없으면 0)과 지갑.

create or replace function public.claim_daily_reward(p_day date, p_done int, p_total int)
returns table (gained_xp int, gained_coins int, perfect boolean, level int, xp int, total_xp int, coins int)
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  g public.reward_grants;
  is_perfect boolean;
  add_xp int := 0;
  add_coins int := 0;
  lvl_before int;
  w public.wallets;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if p_total <= 0 or p_done < 0 or p_done > p_total then raise exception 'bad counts'; end if;
  if p_day > (now() at time zone 'utc')::date + 1 then raise exception 'future day'; end if;

  is_perfect := p_done = p_total;
  select * into g from public.reward_grants where user_id = uid and day = p_day for update;

  if not found then
    if p_done * 10 < p_total * 7 then
      select * into w from public.wallets where user_id = uid;
      return query select 0, 0, false, w.level, w.xp, w.total_xp, w.coins;
      return;
    end if;
    add_xp := 20 + case when is_perfect then 10 else 0 end;
    add_coins := 10 + case when is_perfect then 5 else 0 end;
    insert into public.reward_grants (user_id, day, xp, coins, perfect)
      values (uid, p_day, add_xp, add_coins, is_perfect);
  elsif is_perfect and not g.perfect then
    add_xp := 10;
    add_coins := 5;
    update public.reward_grants
       set xp = g.xp + add_xp, coins = g.coins + add_coins, perfect = true
     where user_id = uid and day = p_day;
  end if;

  select wallets.level into lvl_before from public.wallets where user_id = uid;
  if add_xp > 0 then
    w := public._add_xp(uid, add_xp, add_coins);
    -- 레벨업 코인도 이번 지급분에 포함해 돌려준다
    add_coins := add_coins + (w.level - coalesce(lvl_before, w.level)) * 20;
    update public.reward_grants set coins = reward_grants.coins + (w.level - coalesce(lvl_before, w.level)) * 20
     where user_id = uid and day = p_day;
  else
    select * into w from public.wallets where user_id = uid;
  end if;

  return query select add_xp, add_coins, is_perfect, w.level, w.xp, w.total_xp, w.coins;
end $$;

-- ───────── 아이템 사기 ─────────
-- 가격과 필요 레벨은 앱 카탈로그 값을 받는다 (현금 결제가 없는 앱 내 재화라 서버 카탈로그는 두지 않음).

create or replace function public.buy_item(p_item_id text, p_price int, p_min_level int)
returns table (ok boolean, reason text, level int, xp int, total_xp int, coins int)
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  w public.wallets;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if p_price < 0 then raise exception 'bad price'; end if;

  select * into w from public.wallets where user_id = uid for update;
  if exists (select 1 from public.purchases where user_id = uid and item_id = p_item_id) then
    return query select false, 'already_owned', w.level, w.xp, w.total_xp, w.coins; return;
  end if;
  if w.level < p_min_level then
    return query select false, 'level_too_low', w.level, w.xp, w.total_xp, w.coins; return;
  end if;
  if w.coins < p_price then
    return query select false, 'not_enough_coins', w.level, w.xp, w.total_xp, w.coins; return;
  end if;

  insert into public.purchases (user_id, item_id, price) values (uid, p_item_id, p_price);
  update public.wallets set coins = wallets.coins - p_price, updated_at = now()
   where user_id = uid returning * into w;
  return query select true, null::text, w.level, w.xp, w.total_xp, w.coins;
end $$;

-- ───────── 계정 삭제 ─────────
-- auth.users 를 지우면 위 테이블은 on delete cascade 로 함께 지워진다.

create or replace function public.delete_account()
returns void language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in'; end if;
  delete from auth.users where id = uid;
end $$;

revoke all on function public.claim_daily_reward(date, int, int) from public, anon;
revoke all on function public.buy_item(text, int, int) from public, anon;
revoke all on function public.delete_account() from public, anon;
grant execute on function public.claim_daily_reward(date, int, int) to authenticated;
grant execute on function public.buy_item(text, int, int) to authenticated;
grant execute on function public.delete_account() to authenticated;
