-- 광고 보상 (AdMob 보상형 광고를 끝까지 보면 코인)
-- 여러 번 실행해도 안전하게 썼다.
--
-- 규칙은 lib/data/rewards.dart 의 AdRules 와 같다: 하루 5번, 한 번에 5코인 (경험치 없음).
-- 횟수는 서버가 센다 → 기기를 바꾸거나 앱을 다시 깔아도 하루 5번을 넘지 못한다.

create table if not exists public.ad_rewards (
  user_id    uuid not null references auth.users (id) on delete cascade,
  day        date not null,
  used       int not null default 0 check (used >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

alter table public.ad_rewards enable row level security;

-- 읽기만. 쓰기는 아래 security definer 함수로만.
drop policy if exists "read own ad rewards" on public.ad_rewards;
create policy "read own ad rewards" on public.ad_rewards
  for select to authenticated using (user_id = (select auth.uid()));

-- 반환: ok(이번에 코인을 줬는지), used(그날 준 횟수), 지갑.
create or replace function public.claim_ad_reward(p_day date)
returns table (ok boolean, used int, level int, xp int, total_xp int, coins int)
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  today date := (now() at time zone 'utc')::date;
  n int;
  w public.wallets;
begin
  if uid is null then raise exception 'not signed in'; end if;
  -- 기기의 '오늘'은 시간대에 따라 서버 날짜와 하루까지 다를 수 있다. 그보다 먼 날짜는 받지 않는다
  -- (지난 날짜를 골라 횟수를 다시 채우는 것을 막는다).
  if p_day > today + 1 or p_day < today - 1 then raise exception 'day out of range'; end if;

  select * into w from public.wallets where user_id = uid for update;
  if not found then
    insert into public.wallets (user_id) values (uid) returning * into w;
  end if;

  select ad_rewards.used into n from public.ad_rewards where user_id = uid and day = p_day;
  n := coalesce(n, 0);
  if n >= 5 then
    return query select false, n, w.level, w.xp, w.total_xp, w.coins;
    return;
  end if;

  insert into public.ad_rewards (user_id, day, used) values (uid, p_day, 1)
    on conflict (user_id, day) do update set used = ad_rewards.used + 1, updated_at = now();
  update public.wallets set coins = wallets.coins + 5, updated_at = now()
   where user_id = uid returning * into w;
  return query select true, n + 1, w.level, w.xp, w.total_xp, w.coins;
end $$;

revoke all on function public.claim_ad_reward(date) from public, anon;
grant execute on function public.claim_ad_reward(date) to authenticated;
