-- ============================================================
--  새 사진 알림용 공개 함수 (photo-updated-migration.sql)
--  Supabase 대시보드 → SQL Editor 에 "이 파일만" 붙여넣고 [Run] 한 번.
--  (프로젝트: zoszumqphwfniankrgio.supabase.co) — 2026-10-21 실행함
--
--  왜 필요한가:
--   · 브라보 대시보드의 S 단추 위에 새 사진이 올라왔을 때만 「Update」 말풍선을 띄우고,
--     경리 담당이 주 1회 새 사진 장수를 확인한다 (사장님 2026-10-21).
--   · photos 는 관리자만 읽을 수 있어(RLS) 대시보드가 볼 길이 없었다.
--
--  하는 일: 숫자 두 개만 돌려준다 — 이름·아이디·사진 주소 같은 개인정보는 없다.
--   last_at : 마지막으로 사진(시안 포함)이 올라온 시각
--   week    : 최근 7일 동안 올라온 사진 장수 (관리자가 내려받아 지운 사진은 빠진다)
--  ⚠ photo_tally(photo-tally-migration.sql)는 실제 서버에 없다 — 그래서 photos 만 본다.
--
--  ⚠ schema.sql 전체를 다시 돌리지 마세요. 이 파일만 돌리면 됩니다. 기존 데이터는 건드리지 않습니다.
-- ============================================================

create or replace function photo_feed_status()
returns json
language sql
stable
security definer
set search_path = public
as $$
  select json_build_object(
    'last_at', (select max(created_at) from photos),
    'week',    (select count(*) from photos where created_at > now() - interval '7 days')
  );
$$;

grant execute on function photo_feed_status() to anon, authenticated;
