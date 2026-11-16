-- 방 방문 공개 설정 (기능 F-LERLEQ)
-- 여러 번 실행해도 안전하게 썼다.
--
-- 줄이 있으면 공개, 없으면 비공개. 공개를 멈추면 줄을 지우므로 방문 경로(token)도 함께 사라지고,
-- 다시 공개하면 새 token 이 만들어진다 (예전 경로는 다시 쓸 수 없다).
-- 공개하는 것은 방의 모습뿐이다. 다른 사용자가 이 테이블이나 user_state 를 직접 읽을 수는 없다.
-- 방문(F-HEIPOG)을 만들 때 token 으로 방 배치만 돌려주는 security definer 함수를 따로 둔다.

create table if not exists public.room_shares (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  token      uuid not null unique default gen_random_uuid(),
  created_at timestamptz not null default now()
);

alter table public.room_shares enable row level security;

-- 본인 줄만 읽고, 만들고, 지운다 (고치기는 없다 → token 을 직접 정할 수 없다).
drop policy if exists "read own room share" on public.room_shares;
create policy "read own room share" on public.room_shares
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "delete own room share" on public.room_shares;
create policy "delete own room share" on public.room_shares
  for delete to authenticated using (user_id = (select auth.uid()));

-- 공개하기. 이미 공개 중이면 그대로 둔다.
create or replace function public.publish_room()
returns void language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in'; end if;
  insert into public.room_shares (user_id) values (uid) on conflict do nothing;
end $$;

revoke all on function public.publish_room() from public, anon;
grant execute on function public.publish_room() to authenticated;
