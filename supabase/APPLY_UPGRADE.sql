-- Run once after the original three migrations. Do not also run migrations 020000-040000 separately.
-- Includes exact demo-data cleanup described in PAYMENTS_SETUP.md.
begin;
alter table public.profiles add column if not exists profile_completed boolean not null default false;

create table if not exists public.gym_packages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  duration_days integer not null check(duration_days > 0),
  price integer not null check(price >= 0),
  branch_name text not null,
  active boolean not null default true
);
create table if not exists public.membership_renewal_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  package_id uuid not null references public.gym_packages(id),
  status text not null default 'pending' check(status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);
create unique index if not exists one_pending_renewal on public.membership_renewal_requests(user_id) where status = 'pending';
alter table public.gym_packages enable row level security;
alter table public.membership_renewal_requests enable row level security;
grant select on public.gym_packages to authenticated;
grant select, insert on public.membership_renewal_requests to authenticated;
create policy "Members read packages" on public.gym_packages for select to authenticated using(active);
create policy "Members read requests" on public.membership_renewal_requests for select to authenticated using(auth.uid() = user_id);
create policy "Members request renewal" on public.membership_renewal_requests for insert to authenticated with check(auth.uid() = user_id and status = 'pending' and processed_at is null and exists(select 1 from public.gym_packages p where p.id = package_id and p.active));

-- Deactivate only the exact auto-generated demo contract identifier from the old app.
update public.memberships set active = false where id ~ '^FIT-[0-9]{6}-001$';
delete from public.app_notifications where id ~ '^expiry_FIT-[0-9]{6}-001$'
  or message like 'Bản mô phỏng đã gia hạn%';
-- Remove the exact bootstrap workout emitted by the old main.dart for incomplete profiles.
delete from public.workout_sessions s where s.client_session_id = 's1'
  and exists(select 1 from public.profiles p where p.user_id = s.user_id and not p.profile_completed)
  and (select count(*) from public.exercise_logs l where l.session_id = s.id) = 1
  and exists(select 1 from public.exercise_logs l where l.session_id = s.id and l.exercise_name = 'Bench Press' and l.sets = 4 and l.reps = 8 and l.weight_kg = 60);

-- Membership dates and payment confirmation are managed by the gym, not by the member client.
drop policy if exists "Users manage their memberships" on public.memberships;
revoke insert, update, delete on public.memberships from authenticated;
create policy "Members read contracts" on public.memberships for select to authenticated using(auth.uid() = user_id);

create or replace function public.approve_membership_renewal(request_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare req public.membership_renewal_requests; pkg public.gym_packages; old_end date;
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'Only gym administrators can approve payment'; end if;
  select * into req from public.membership_renewal_requests where id = request_id for update;
  if req.id is null or req.status <> 'pending' then raise exception 'Request is not pending'; end if;
  select * into strict pkg from public.gym_packages where id = req.package_id;
  select max(end_date) into old_end from public.memberships where user_id = req.user_id and active;
  update public.memberships set active = false where user_id = req.user_id;
  insert into public.memberships(id,user_id,name,branch_name,start_date,end_date,total_sessions,price,active)
  values(req.id::text,req.user_id,pkg.name,pkg.branch_name,current_date,greatest(coalesce(old_end,current_date),current_date)+pkg.duration_days,0,pkg.price,true);
  update public.membership_renewal_requests set status = 'approved', processed_at = now() where id = req.id;
  insert into public.app_notifications(id,user_id,title,message,notice_type)
  values('renewal_'||req.id,req.user_id,'Gia hạn thành công','Gói '||pkg.name||' đã được xác nhận và kích hoạt.','renewal');
end $$;
revoke all on function public.approve_membership_renewal(uuid) from public, anon, authenticated;
grant execute on function public.approve_membership_renewal(uuid) to service_role;

create table if not exists public.payment_settings (
  id boolean primary key default true check(id),
  bank_name text not null default '',
  bank_account_number text not null default '',
  bank_account_holder text not null default '',
  online_enabled boolean not null default false,
  gateway_name text not null default 'MoMo',
  momo_phone text not null default ''
);
alter table public.payment_settings enable row level security;
grant select on public.payment_settings to authenticated;
create policy "Members read payment details" on public.payment_settings for select to authenticated using(true);

alter table public.gym_packages add column duration_months integer not null default 0 check(duration_months >= 0);
alter table public.membership_renewal_requests
  add column payment_method text not null default 'cash' check(payment_method in ('cash','bank_transfer','online')),
  add column amount integer not null default 0,
  add column duration_days integer not null default 1,
  add column duration_months integer not null default 0,
  add column package_name text not null default '',
  add column branch_name text not null default '',
  add column transaction_no text,
  add column payment_url text,
  add column paid_at timestamptz;

create or replace function public.snapshot_membership_price()
returns trigger language plpgsql security definer set search_path = public as $$
declare pkg public.gym_packages;
begin
  select * into strict pkg from public.gym_packages where id = new.package_id and active;
  new.amount := pkg.price; new.duration_days := pkg.duration_days;
  new.duration_months := pkg.duration_months;
  new.package_name := pkg.name; new.branch_name := pkg.branch_name;
  new.transaction_no := null; new.paid_at := null; new.payment_url := null;
  return new;
end $$;
create trigger snapshot_membership_price before insert on public.membership_renewal_requests
  for each row execute function public.snapshot_membership_price();
update public.membership_renewal_requests r set amount = p.price, duration_days = p.duration_days,
  duration_months = p.duration_months,
  package_name = p.name, branch_name = p.branch_name from public.gym_packages p where p.id = r.package_id;

create or replace function public.approve_membership_renewal(request_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare req public.membership_renewal_requests; old_end date; renewed_end date;
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'Only gym administrators can approve payment'; end if;
  select * into req from public.membership_renewal_requests where id = request_id for update;
  if req.id is null then raise exception 'Request not found'; end if;
  if req.status = 'approved' then return; end if;
  if req.status <> 'pending' then raise exception 'Request is not pending'; end if;
  perform pg_advisory_xact_lock(hashtextextended(req.user_id::text, 0));
  select max(end_date) into old_end from public.memberships where user_id = req.user_id and active;
  renewed_end := case when req.duration_months > 0
    then (greatest(coalesce(old_end,current_date),current_date) + make_interval(months => req.duration_months))::date
    else greatest(coalesce(old_end,current_date),current_date) + req.duration_days end;
  update public.memberships set active = false where user_id = req.user_id;
  insert into public.memberships(id,user_id,name,branch_name,start_date,end_date,total_sessions,price,active)
  values(req.id::text,req.user_id,req.package_name,req.branch_name,current_date,renewed_end,0,req.amount,true);
  update public.membership_renewal_requests set status = 'approved', processed_at = now(), paid_at = coalesce(paid_at,now()) where id = req.id;
  insert into public.app_notifications(id,user_id,title,message,notice_type)
  values('renewal_'||req.id,req.user_id,'Gia hạn thành công','Gói '||req.package_name||' đã được xác nhận và kích hoạt.','renewal') on conflict do nothing;
end $$;

create or replace function public.confirm_online_membership(request_id uuid, expected_amount integer, gateway_transaction text)
returns void language plpgsql security definer set search_path = public as $$
declare req public.membership_renewal_requests;
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'Not authorized'; end if;
  select * into req from public.membership_renewal_requests where id = request_id for update;
  if req.id is null or req.payment_method <> 'online' or req.amount <> expected_amount then raise exception 'Payment mismatch'; end if;
  if req.status = 'approved' then
    if req.transaction_no = gateway_transaction then return; end if;
    raise exception 'Transaction mismatch';
  end if;
  update public.membership_renewal_requests set transaction_no = gateway_transaction where id = req.id;
  perform public.approve_membership_renewal(req.id);
end $$;
revoke all on function public.confirm_online_membership(uuid,integer,text) from public,anon,authenticated;
grant execute on function public.confirm_online_membership(uuid,integer,text) to service_role;
create unique index unique_gateway_membership_transaction on public.membership_renewal_requests(transaction_no) where transaction_no is not null;

create or replace function public.cancel_own_membership_request(request_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.membership_renewal_requests set status = 'rejected', processed_at = now()
    where id = request_id and user_id = auth.uid() and status = 'pending'
      and (payment_method <> 'online' or (payment_url is null and not exists(select 1 from public.payment_settings where online_enabled)));
end $$;
revoke all on function public.cancel_own_membership_request(uuid) from public,anon;
grant execute on function public.cancel_own_membership_request(uuid) to authenticated;

-- Public receiving details supplied by the owner. Merchant secrets belong in Supabase Secrets.
insert into public.payment_settings(id,bank_name,bank_account_number,bank_account_holder,momo_phone,gateway_name,online_enabled)
values(true,'Vietcombank','1042362758','Nguyễn Vũ Duy','0775571311','MoMo',false)
on conflict(id) do update set bank_name=excluded.bank_name,bank_account_number=excluded.bank_account_number,
  bank_account_holder=excluded.bank_account_holder,momo_phone=excluded.momo_phone,gateway_name='MoMo';

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


commit;
select name, duration_months, price, branch_name from public.gym_packages where active order by branch_name, duration_months;
