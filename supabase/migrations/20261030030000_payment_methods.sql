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
