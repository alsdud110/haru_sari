-- 업데이트 안내 팝업. Supabase 대시보드(Table Editor)에서 값을 바꾸면 다음에 앱을 켤 때 반영된다.
-- 여러 번 실행해도 안전하게 썼다.
--
-- 플랫폼마다 한 줄. 값은 pubspec.yaml version 의 + 뒤 빌드 번호와 비교한다 (1.1.0+3 → 3).
-- - latest_build: 이보다 낮은 빌드는 '나중에'를 누를 수 있는 안내를 본다 (나중에를 누르면 이 번호에서는 다시 안 뜬다).
-- - min_build:    이보다 낮은 빌드는 닫을 수 없는 안내를 본다 (꼭 업데이트해야 할 때만).
-- - store_url 이 비어 있으면 팝업을 띄우지 않는다.
-- 앱만 읽는다. 고치기는 대시보드(service_role)에서만.

create table if not exists public.app_updates (
  platform     text primary key check (platform in ('ios', 'android')),
  latest_build int  not null default 0,
  min_build    int  not null default 0,
  message      text not null default '',
  store_url    text not null default '',
  updated_at   timestamptz not null default now()
);

alter table public.app_updates enable row level security;

drop policy if exists "anyone reads app updates" on public.app_updates;
create policy "anyone reads app updates" on public.app_updates
  for select to anon, authenticated using (true);

-- android 는 Play 비공개 테스트 중이라 store_url 을 비워 둔다 (팝업 안 뜸).
-- 프로덕션 출시 후 Table Editor 에서 https://play.google.com/store/apps/details?id=com.harusari.app 로 채운다.
insert into public.app_updates (platform, store_url) values
  ('android', ''),
  ('ios', 'https://apps.apple.com/app/id6834387060')
on conflict do nothing;
