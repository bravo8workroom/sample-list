-- ============================================================
--  저장소 사용량 확인 + 완료 처리 (storage-usage-and-done-migration.sql)
--  Supabase 대시보드 → SQL Editor 에 "이 파일만" 붙여넣고 [Run] 한 번.
--
--  왜 필요한가:
--   · 관리자 페이지 '고객 사진 모음'에 남은 저장 용량을 보여주려면
--     버킷 안 파일 크기 합계를 서버가 계산해 줘야 한다 → storage_usage()
--   · '완료' 버튼: 사진을 지워 용량을 비운 뒤, 그 손님의 신청 기록에서
--     인스타 아이디와 옵션명만 남기고 주소 등 배송·추가입력 정보를 지운다.
--     submissions 테이블은 직접 수정이 막혀 있어(RLS) RPC 가 필요하다
--     → anonymize_buyer()
--   · 두 함수 모두 관리자(로그인)만 호출 가능. 손님(anon)은 호출 불가.
-- ============================================================

-- 1) storage_usage() : sample-photos 버킷의 총 사용량(byte)
create or replace function storage_usage()
returns bigint
language sql
security definer
set search_path = public, storage
as $$
  select coalesce(sum((metadata->>'size')::bigint), 0)
    from storage.objects
   where bucket_id = 'sample-photos';
$$;

revoke all on function storage_usage() from anon, public;
grant execute on function storage_usage() to authenticated;

-- 2) anonymize_buyer(아이디) : 그 손님의 신청 기록에서
--    주소 등 배송정보(ship)와 추가입력(opt)을 지운다.
--    아이디(buyer)와 옵션명(size_key)은 남는다 → 명단·재고 수량은 그대로.
--    opt 에 완료 표시({"__done": true})를 남겨, 사진을 지워도
--    '사진 아직 안 올린 사람' 목록에 다시 잡히지 않게 한다.
create or replace function anonymize_buyer(p_buyer text)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text := lower(replace(p_buyer, '@', ''));
  v_n   int;
begin
  if v_key = '' then return 0; end if;
  update submissions
     set ship = '{}'::jsonb,
         opt  = '{"__done": true}'::jsonb
   where lower(replace(buyer, '@', '')) = v_key;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke all on function anonymize_buyer(text) from anon, public;
grant execute on function anonymize_buyer(text) to authenticated;

-- 확인용 — 현재 사용량(byte)이 숫자 하나로 나오면 적용된 것
select storage_usage() as used_bytes;
