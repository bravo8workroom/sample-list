-- ============================================================
--  올린 사진 장수 기록 (photo-tally-migration.sql)
--  Supabase 대시보드 → SQL Editor 에 "이 파일만" 붙여넣고 [Run] 한 번.
--  (프로젝트: zoszumqphwfniankrgio.supabase.co)
--
--  왜 필요한가:
--   · 손님이 사진을 올린 뒤 "내 사진이 들어갔나?"를 확인할 길이 없었다.
--   · photos 테이블은 관리자만 읽을 수 있고(RLS), 관리자가 사진을
--     내려받아 '완료' 처리하면 그 행 자체가 지워진다.
--     → 사진이 지워져도 "몇 장 올렸는지"만은 남는 별도 장부가 필요하다.
--
--  하는 일 (4가지)
--   1) photo_tally  : 아이디 × 상품 별 누적 장수 장부
--   2) 트리거        : photos 에 사진이 들어올 때마다 장부를 +1
--                      (사진을 지워도 장부는 줄지 않는다 — 이게 핵심)
--   3) 첫 값 채우기  : 지금 올라와 있는 사진으로 장부를 미리 채운다
--   4) photo_count() : 손님이 "자기 장수"만 확인하는 RPC (손님 호출 허용)
--
--  ⚠ schema.sql 전체를 다시 돌리지 마세요. 이 파일만 돌리면 됩니다.
--     기존 photos / products / buyers 데이터는 건드리지 않습니다.
-- ============================================================

-- 1) 장부 --------------------------------------------------------------
create table if not exists photo_tally (
  buyer      text not null,                 -- 정규화된 인스타 아이디 (소문자, @ 제거)
  product_id text not null references products(id) on delete cascade,
  n          int  not null default 0,       -- 지금까지 올린 누적 장수 (줄지 않는다)
  updated_at timestamptz default now(),
  primary key (buyer, product_id)
);

alter table photo_tally enable row level security;
-- 남의 장수가 보이면 안 되므로 직접 읽기는 관리자만.
-- 손님은 아래 photo_count() RPC 로 자기 것만 확인한다.
drop policy if exists tally_read on photo_tally;
create policy tally_read on photo_tally for select using (auth.uid() is not null);

-- 2) 트리거 : 사진이 들어올 때마다 +1 ----------------------------------
--    시안(kind='draft') 은 세지 않는다 — 손님이 "받은 상품 사진"으로
--    올린 것(kind='item')만 장부에 오른다.
create or replace function photo_tally_bump()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text := lower(replace(coalesce(new.buyer, ''), '@', ''));
begin
  if v_key = '' then return new; end if;
  if coalesce(new.kind, 'item') <> 'item' then return new; end if;

  insert into photo_tally (buyer, product_id, n, updated_at)
    values (v_key, new.product_id, 1, now())
    on conflict (buyer, product_id)
    do update set n = photo_tally.n + 1, updated_at = now();

  return new;
end;
$$;

drop trigger if exists photos_tally_ins on photos;
create trigger photos_tally_ins
  after insert on photos
  for each row execute function photo_tally_bump();

-- 3) 첫 값 채우기 : 지금 남아 있는 사진으로 장부를 미리 채운다 ---------
--    (이미 지워진 옛 사진은 셀 방법이 없어 0부터 시작한다)
--    여러 번 실행해도 숫자가 부풀지 않게 greatest 로 받는다.
insert into photo_tally (buyer, product_id, n)
select lower(replace(buyer, '@', '')), product_id, count(*)
  from photos
 where coalesce(kind, 'item') = 'item'
   and coalesce(buyer, '') <> ''
 group by 1, 2
on conflict (buyer, product_id)
do update set n = greatest(photo_tally.n, excluded.n), updated_at = now();

-- 4) photo_count() : 손님이 자기 장수만 확인 ---------------------------
--    남의 아이디를 넣어도 그 사람 "장수"만 나올 뿐 명단은 새지 않는다.
create or replace function photo_count(p_product_id text, p_buyer text)
returns int
language sql
security definer
set search_path = public
as $$
  select coalesce((
    select n from photo_tally
     where product_id = p_product_id
       and buyer = lower(replace(coalesce(p_buyer, ''), '@', ''))
  ), 0);
$$;

grant execute on function photo_count(text, text) to anon, authenticated;

-- 확인용 — 장부에 줄이 뜨면 적용된 것 (사진이 아직 없으면 0줄이 정상)
select buyer, product_id, n from photo_tally order by n desc limit 10;
