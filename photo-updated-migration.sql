-- ============================================================
--  새 사진 알림용 공개 함수 (photo-updated-migration.sql)
--  Supabase 대시보드 → SQL Editor 에 "이 파일만" 붙여넣고 [Run] 한 번.
--  (프로젝트: zoszumqphwfniankrgio.supabase.co)
--
--  왜 필요한가:
--   · 브라보 대시보드의 S 단추 위에 새 사진이 올라왔을 때만 「Update」 말풍선을 띄우고,
--     경리 담당이 주 1회 새 사진 장수를 확인한다 (사장님 2026-10-21).
--   · photos / photo_tally 는 관리자만 읽을 수 있어(RLS) 대시보드가 볼 길이 없었다.
--
--  하는 일: 합계 두 개만 돌려준다 — 이름·아이디·사진 주소 같은 개인정보는 없다.
--   total   : 지금까지 손님이 올린 상품 사진 누적 장수 (photo_tally 합계, 줄지 않음)
--   last_at : 마지막으로 사진(시안 포함)이 올라온 시각
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
    'total',   coalesce((select sum(n) from photo_tally), 0),
    'last_at', greatest((select max(updated_at) from photo_tally),
                        (select max(created_at) from photos))
  );
$$;

grant execute on function photo_feed_status() to anon, authenticated;
