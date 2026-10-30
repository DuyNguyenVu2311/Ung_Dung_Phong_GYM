-- Prices and branch names supplied by the gym owner. No street addresses were provided.
insert into public.gym_packages(id,name,duration_days,duration_months,price,branch_name,active)
select md5('fitplan-package:' || branch || ':' || months::text)::uuid,
  'Gói ' || months::text || ' tháng', months * 30, months,
  case when months = 1 then 299000 else 807300 end, branch, true
from unnest(array['Thủ Đức','Bình Thạnh','Quận 1']) as branch
cross join unnest(array[1,3]) as months
on conflict(id) do update set name=excluded.name,duration_days=excluded.duration_days,
  duration_months=excluded.duration_months,price=excluded.price,branch_name=excluded.branch_name,active=true;

-- Standing owner-approved offer; no invented expiry date.
alter table public.promotions alter column ends_at drop not null;
drop policy if exists "Authenticated users read active promotions" on public.promotions;
create policy "Authenticated users read active promotions" on public.promotions for select to authenticated
  using(active and starts_at <= now() and (ends_at is null or now() <= ends_at));
insert into public.promotions(id,title,description,starts_at,ends_at,active)
values(md5('fitplan-three-month-discount')::uuid,'Giảm 10% khi đăng ký gói 3 tháng',
  'Gói 1 tháng: 299.000đ. Gói 3 tháng: 807.300đ, tiết kiệm 89.700đ so với ba gói 1 tháng. Áp dụng tại Thủ Đức, Bình Thạnh và Quận 1.',now(),null,true)
on conflict(id) do update set title=excluded.title,description=excluded.description,ends_at=null,active=true;
