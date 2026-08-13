-- ============================================================
--  사진 용량 한도 맞추기 (photo-size-limit-migration.sql)
--  Supabase 대시보드 → SQL Editor 에 "이 파일만" 붙여넣고 [Run] 한 번.
--  (프로젝트: zoszumqphwfniankrgio.supabase.co)
--
--  왜 필요한가:
--   · 앱은 "한 번에 합계 100MB"까지만 담기게 막고, 넘으면 손님에게 안내한다.
--   · 그런데 버킷 한도가 앱 한도보다 낮으면 경계에서 맞붙는다.
--     → 앱은 통과시키는데 서버가 거부하고,
--       그러면 손님은 이유 없이 "일부 저장 실패"만 보게 된다.
--   · 버킷 한도를 102MB로 한 칸 올려두면 항상 앱의 안내가 먼저 걸린다.
--     (손님이 실제로 올릴 수 있는 양은 그대로 100MB — 이 파일은 여유만 준다)
--
--  ※ 버킷 한도는 "파일 1장당" 한도다. 앱의 100MB는 "한 번에 담는 합계"이고
--    업로드는 한 장씩 따로 올라가므로, 사진 여러 장으로 100MB를 채우는 건
--    버킷 한도와 무관하다. 102MB는 "한 장이 아주 클 때"를 위한 여유다.
--
--  ※ 만약 이 SQL 실행 후에도 큰 사진이 거부되면, 프로젝트 전체 상한
--    (Storage → Settings → Global file upload limit)이 더 낮은 것이다.
--    Free 플랜은 이 값이 50MB로 묶여 있어 버킷만 올려도 소용이 없다.
-- ============================================================

update storage.buckets
   set file_size_limit = 106954752          -- 102MB (앱 한도 100MB + 여유 2MB)
 where id = 'sample-photos';

-- 확인용 — file_size_limit 이 106954752 로 나오면 적용된 것
select id, public, file_size_limit
  from storage.buckets
 where id = 'sample-photos';
