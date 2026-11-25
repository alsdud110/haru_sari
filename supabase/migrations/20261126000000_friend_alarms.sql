-- 나의 루틴 공유 2단계: 친구 루틴 알림 (PLAN_FRIEND_SHARE.md)
-- 여러 번 실행해도 안전하게 썼다. 20261125000000_routine_shares.sql 다음에 실행한다.
--
-- 친구가 공유한 루틴 중 알림을 켠 것을 루틴 id 로 적어 둔다 (friend_follows.alarm_ids).
-- 알림 자체는 기기에서 예약한다 (서버 푸시 없음). 서버는 고른 것과 상한(한 사람당 5개)만 지킨다.
-- 켜고 끄기는 set_friend_alarm 으로만 (friend_follows 를 직접 고치면 owner 를 바꿔 코드 없이 친구가 될 수 있으므로 update 정책을 두지 않는다).

alter table public.friend_follows add column if not exists alarm_ids jsonb not null default '[]'::jsonb;

-- 알림 켜기/끄기. reason: not_friend / limit (5개) / invalid
create or replace function public.set_friend_alarm(p_owner uuid, p_routine_id text, p_on boolean)
returns table (ok boolean, reason text)
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  v_ids jsonb;
  v_total int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if p_routine_id is null or length(p_routine_id) not between 1 and 40 or p_on is null then
    return query select false, 'invalid'::text; return;
  end if;

  -- 같은 사람이 동시에 여러 개를 켜서 상한을 넘지 않게 잠근다
  perform pg_advisory_xact_lock(hashtextextended(uid::text, 1));

  select f.alarm_ids into v_ids from public.friend_follows f where f.follower = uid and f.owner = p_owner;
  if v_ids is null then return query select false, 'not_friend'::text; return; end if;

  if p_on then
    if v_ids @> jsonb_build_array(p_routine_id) then return query select true, null::text; return; end if;
    select coalesce(sum(jsonb_array_length(f.alarm_ids)), 0) into v_total
      from public.friend_follows f where f.follower = uid;
    if v_total >= 5 then return query select false, 'limit'::text; return; end if;
    v_ids := v_ids || jsonb_build_array(p_routine_id);
  else
    v_ids := coalesce((select jsonb_agg(e) from jsonb_array_elements(v_ids) e where e <> to_jsonb(p_routine_id)), '[]'::jsonb);
  end if;

  update public.friend_follows f
     set alarm_ids = v_ids, alarm = jsonb_array_length(v_ids) > 0
   where f.follower = uid and f.owner = p_owner;
  return query select true, null::text;
end $$;

-- 친구 목록에 내가 켠 알림(alarm_ids)을 함께 돌려준다. 반환 칸이 바뀌어 다시 만든다.
drop function if exists public.my_friend_routines();
create function public.my_friend_routines()
returns table (owner uuid, nickname text, look jsonb, routines jsonb, updated_at timestamptz, alarm_ids jsonb)
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in'; end if;
  return query
    select s.user_id, s.nickname, s.look, s.routines, s.updated_at, f.alarm_ids
      from public.friend_follows f
      join public.routine_shares s on s.user_id = f.owner
     where f.follower = uid
     order by f.created_at;
end $$;

revoke all on function public.set_friend_alarm(uuid, text, boolean) from public, anon;
revoke all on function public.my_friend_routines() from public, anon;
grant execute on function public.set_friend_alarm(uuid, text, boolean) to authenticated;
grant execute on function public.my_friend_routines() to authenticated;
