-- ============================================================
--  사진 보관함 잠금 (storage-lock-migration.sql)
--  Supabase 대시보드 → SQL Editor 에 "이 파일만" 붙여넣고 [Run] 한 번.
--
--  효과:
--   · 사진 파일을 관리자(로그인)만 볼 수 있게 잠근다.
--   · 고객의 사진 "올리기"는 지금처럼 로그인 없이 가능.
--   · 앱은 로그인한 관리자에게만 서명주소(임시 열람권)를 발급해 사진을 보여준다.
-- ============================================================

-- 1) 보관함 자체를 비공개로 전환 — 공개 주소로 바로 열리던 문을 닫는다
update storage.buckets set public = false where id = 'sample-photos';

-- 2) 옛 정책 제거 — 2026-07-23 세팅 때 만들어진 s_pho_* 가 조건 없이 열려 있었다.
--    RLS는 정책들의 OR 판정이라, 열린 정책이 하나라도 남으면 잠금이 무의미하다.
--    (s_pho_del 은 익명 삭제까지 허용하던 상태였음)
drop policy if exists s_pho_read on storage.objects;
drop policy if exists s_pho_del  on storage.objects;

-- 3) 파일 목록·읽기: 관리자(로그인)만
drop policy if exists sp_read on storage.objects;
create policy sp_read on storage.objects for select
  using (bucket_id = 'sample-photos' and auth.uid() is not null);

-- (올리기 sp_insert 는 그대로 열어둠 — 고객 업로드용.
--  삭제 sp_delete 는 원래부터 관리자 전용이라 손대지 않음.)
