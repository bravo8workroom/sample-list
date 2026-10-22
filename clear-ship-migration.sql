-- ============================================================
--  clear_ship(상품, 아이디) : 선택자 명단의 「복사 후 개인정보 지우기」 단추용 (2026-10-22)
--  그 상품에서 그 손님의 성함·연락처·주소(ship)와 옵션마다 적은 칸(opt, 예: 뒷면 문구)을 지운다
--  (뒷면 문구에도 전화번호 같은 개인정보가 있을 수 있다 — 사장님 2026-10-22).
--  고른 옵션(size_key)은 그대로 남는다 → 나중에 손님이 사진을 올릴 때 옵션이 그대로 보인다.
--  완료 표시(__done)가 있던 신청은 그 표시만 남긴다.
--  submissions 는 직접 수정이 막혀 있어(RLS) 함수가 필요하다. 관리자(로그인)만 호출 가능.
--  Supabase → SQL Editor → New query → 이 파일 전체 붙여넣기 → Run (한 번만)
-- ============================================================
create or replace function clear_ship(p_product text, p_buyer text)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text := lower(replace(coalesce(p_buyer, ''), '@', ''));
  v_n   int;
begin
  if v_key = '' then return 0; end if;
  update submissions
     set ship = '{}'::jsonb,
         opt  = case when opt ? '__done' then '{"__done": true}'::jsonb else '{}'::jsonb end
   where product_id = p_product
     and lower(replace(buyer, '@', '')) = v_key;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke all on function clear_ship(text, text) from anon, public;
grant execute on function clear_ship(text, text) to authenticated;

-- 확인용 — 아래가 0 으로 나오면 적용된 것
select clear_ship('__확인용__', '__확인용__') as ok;
