-- 나의 루틴 공유 3단계: 초대 보상 (PLAN_FRIEND_SHARE.md)
-- 여러 번 실행해도 안전하게 썼다. 20261125000000_routine_shares.sql 다음에 실행한다.
--
-- 규칙 (2026-11-26 정함, lib/data/friends.dart InviteRules 와 같다)
--   - 새 친구: 가입 후 48시간 안에 코드를 넣으면 30코인, 한 계정에 한 번
--   - 초대한 사람: 30코인, 평생 10명까지 (그 뒤로는 새 친구만 받는다)
--   - 내 코드는 안 된다
--   - 탈퇴하면 받은 기록도 함께 지운다 (재가입을 따로 막지 않는다. 남용은 초대한 사람 10명 상한이 막는다)
--   - 익명 계정(개발 빌드의 "새 익명 계정으로 시작")은 받을 수 없다. 익명 로그인을 켜 두면 공개 키로 누구나
--     계정을 찍어낼 수 있으므로, 코인이 걸린 곳은 소셜 로그인 계정만 쓴다.
-- 코인은 wallets 에 더한다 (claim_ad_reward 와 같은 방식). 앱은 돌려받은 지갑으로 맞춘다.

create table if not exists public.invite_claims (
  claimer    uuid primary key references auth.users (id) on delete cascade,
  -- 초대한 사람이 탈퇴해도 받은 사람의 기록은 남긴다 (두 번 받지 않게)
  inviter    uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists invite_claims_inviter_idx on public.invite_claims (inviter);

alter table public.invite_claims enable row level security;

-- 내가 받은 기록만 읽는다. 쓰기는 claim_invite 로만.
drop policy if exists "read own invite claim" on public.invite_claims;
create policy "read own invite claim" on public.invite_claims
  for select to authenticated using (claimer = (select auth.uid()));

-- 지금 코드를 넣으면 보상을 받을 수 있는지 (가입 직후 안내를 띄울지 정한다).
create or replace function public.invite_status()
returns table (eligible boolean)
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  joined timestamptz;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select u.created_at into joined from auth.users u where u.id = uid;
  return query select
    joined is not null
    and not coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false)
    and joined > now() - interval '48 hours'
    and not exists (select 1 from public.invite_claims c where c.claimer = uid);
end $$;

-- 초대 보상 받기. reason: not_found / self / claimed / not_new
-- 반환: ok, reason, 받은 코인, 내 지갑
create or replace function public.claim_invite(p_code text)
returns table (ok boolean, reason text, gained int, level int, xp int, total_xp int, coins int)
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  v_code text := public._normalize_share_code(p_code);
  v_inviter uuid;
  joined timestamptz;
  given int;
  w public.wallets;
begin
  if uid is null then raise exception 'not signed in'; end if;

  -- 지갑 (없으면 만든다)
  select * into w from public.wallets wl where wl.user_id = uid for update;
  if not found then
    insert into public.wallets (user_id) values (uid) returning * into w;
  end if;

  if v_code is not null then
    select r.user_id into v_inviter from public.routine_shares r where r.code = v_code;
  end if;
  if v_inviter is null then
    return query select false, 'not_found'::text, 0, w.level, w.xp, w.total_xp, w.coins; return;
  end if;
  if v_inviter = uid then
    return query select false, 'self'::text, 0, w.level, w.xp, w.total_xp, w.coins; return;
  end if;
  if exists (select 1 from public.invite_claims c where c.claimer = uid) then
    return query select false, 'claimed'::text, 0, w.level, w.xp, w.total_xp, w.coins; return;
  end if;
  select u.created_at into joined from auth.users u where u.id = uid;
  if joined is null or joined <= now() - interval '48 hours'
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    return query select false, 'not_new'::text, 0, w.level, w.xp, w.total_xp, w.coins; return;
  end if;

  -- 한 계정에 한 번 (동시에 두 번 불러도 기본 키가 막는다)
  begin
    insert into public.invite_claims (claimer, inviter) values (uid, v_inviter);
  exception when unique_violation then
    return query select false, 'claimed'::text, 0, w.level, w.xp, w.total_xp, w.coins; return;
  end;

  update public.wallets wl set coins = wl.coins + 30, updated_at = now() where wl.user_id = uid returning * into w;

  -- 초대한 사람: 평생 10명까지 (이번 줄 포함해 센다)
  perform pg_advisory_xact_lock(hashtextextended(v_inviter::text, 2));
  select count(*) into given from public.invite_claims c where c.inviter = v_inviter;
  if given <= 10 then
    insert into public.wallets (user_id, coins) values (v_inviter, 30)
      on conflict (user_id) do update set coins = public.wallets.coins + 30, updated_at = now();
  end if;

  return query select true, null::text, 30, w.level, w.xp, w.total_xp, w.coins;
end $$;

revoke all on function public.invite_status() from public, anon;
revoke all on function public.claim_invite(text) from public, anon;
grant execute on function public.invite_status() to authenticated;
grant execute on function public.claim_invite(text) to authenticated;
