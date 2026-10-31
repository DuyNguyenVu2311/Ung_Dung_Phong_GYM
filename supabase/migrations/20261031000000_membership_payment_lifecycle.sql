-- Order routing is immutable: toggling merchant settings must not turn a
-- personal transfer into a Business transaction (or allow unsafe cancellation).
alter table public.membership_renewal_requests
  add column payment_provider text not null default 'manual' check(payment_provider in ('manual','momo_business','legacy_review')),
  add column gateway_started_at timestamptz,
  add column payment_expires_at timestamptz,
  add column gateway_checked_at timestamptz,
  add column gateway_result_code integer;
alter table public.membership_renewal_requests drop constraint membership_renewal_requests_status_check;
alter table public.membership_renewal_requests add constraint membership_renewal_requests_status_check
  check(status in ('pending','approved','rejected','cancelled','expired'));
update public.membership_renewal_requests set
  payment_provider='momo_business', gateway_started_at=created_at,
  payment_expires_at=greatest(created_at,now())+interval '20 minutes'
where payment_method='online' and (payment_url is not null or transaction_no is not null);
-- Today's settings and a missing URL cannot prove whether a historical order
-- was a personal transfer or a Business create timeout. Preserve both paths.
update public.membership_renewal_requests set payment_provider='legacy_review',
  gateway_started_at=created_at,payment_expires_at=now()+interval '20 minutes'
where payment_method='online' and status <> 'approved' and payment_url is null and transaction_no is null;

create function public.resolve_legacy_membership_payment(request_id uuid, provider text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if coalesce(auth.role(),'') <> 'service_role' then raise exception 'Not authorized'; end if;
  if provider is null or provider not in ('manual','momo_business') then raise exception 'Invalid provider'; end if;
  update public.membership_renewal_requests set payment_provider=provider,
    gateway_started_at=case when provider='manual' then null else gateway_started_at end,
    payment_expires_at=case when provider='manual' then null else now()+interval '20 minutes' end
  where id=request_id and payment_provider='legacy_review' and status <> 'approved';
  if not found then raise exception 'Unresolved legacy order not found'; end if;
end $$;
revoke all on function public.resolve_legacy_membership_payment(uuid,text) from public,anon,authenticated;
grant execute on function public.resolve_legacy_membership_payment(uuid,text) to service_role;

create function public.snapshot_payment_lifecycle()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  new.payment_provider := case when new.payment_method='online' and
    exists(select 1 from public.payment_settings where online_enabled)
    then 'momo_business' else 'manual' end;
  new.gateway_started_at := null; new.gateway_checked_at := null;
  new.gateway_result_code := null;
  new.payment_expires_at := case when new.payment_provider='momo_business'
    then now()+interval '20 minutes' else null end;
  return new;
end $$;
create trigger snapshot_payment_lifecycle before insert on public.membership_renewal_requests
  for each row execute function public.snapshot_payment_lifecycle();

-- A persistent single-use claim prevents concurrent creation and blind retries
-- after an ambiguous timeout. Reconciliation never creates gateway sessions.
create function public.claim_membership_payment(request_id uuid)
returns boolean language plpgsql security definer set search_path=public as $$
begin
  if coalesce(auth.role(),'') <> 'service_role' then raise exception 'Not authorized'; end if;
  update public.membership_renewal_requests set gateway_started_at=now()
  where id=request_id and status='pending' and payment_provider='momo_business'
    and gateway_started_at is null and payment_expires_at > now();
  return found;
end $$;
revoke all on function public.claim_membership_payment(uuid) from public,anon,authenticated;
grant execute on function public.claim_membership_payment(uuid) to service_role;

create or replace function public.cancel_own_membership_request(request_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare req public.membership_renewal_requests;
begin
  select * into req from public.membership_renewal_requests where id=request_id for update;
  if req.id is null or req.user_id is distinct from auth.uid() then raise exception 'Request not found'; end if;
  if req.status <> 'pending' then return; end if;
  if req.payment_provider='legacy_review' then raise exception 'Gym must classify this legacy payment first'; end if;
  if req.payment_provider='momo_business' and req.gateway_started_at is not null then
    raise exception 'Check gateway status before closing this payment';
  end if;
  update public.membership_renewal_requests set status='cancelled',processed_at=now() where id=req.id;
end $$;

create or replace function public.approve_membership_renewal(request_id uuid)
returns void language plpgsql security definer set search_path=public set timezone='Asia/Ho_Chi_Minh' as $$
declare req public.membership_renewal_requests; old_end date; renewed_end date;
begin
  if coalesce(auth.role(),'') <> 'service_role' then raise exception 'Only gym administrators can approve payment'; end if;
  select * into req from public.membership_renewal_requests where id=request_id for update;
  if req.id is null then raise exception 'Request not found'; end if;
  if req.status='approved' then return; end if;
  if req.payment_provider='legacy_review' then raise exception 'Gym must classify this legacy payment first'; end if;
  -- Only verified gateway success may recover a closed Business order.
  if req.payment_provider='momo_business' then
    if req.transaction_no is null or req.gateway_result_code is distinct from 0 then raise exception 'Verified gateway payment required'; end if;
  elsif req.status <> 'pending' then raise exception 'Request is not pending'; end if;
  perform pg_advisory_xact_lock(hashtextextended(req.user_id::text,0));
  select max(end_date) into old_end from public.memberships where user_id=req.user_id and active;
  renewed_end := case when req.duration_months > 0
    then (greatest(coalesce(old_end,current_date),current_date)+make_interval(months=>req.duration_months))::date
    else greatest(coalesce(old_end,current_date),current_date)+req.duration_days end;
  update public.memberships set active=false where user_id=req.user_id;
  insert into public.memberships(id,user_id,name,branch_name,start_date,end_date,total_sessions,price,active)
  values(req.id::text,req.user_id,req.package_name,req.branch_name,current_date,renewed_end,0,req.amount,true);
  update public.membership_renewal_requests set status='approved',processed_at=now(),paid_at=coalesce(paid_at,now()) where id=req.id;
  insert into public.app_notifications(id,user_id,title,message,notice_type)
  values('renewal_'||req.id,req.user_id,'Gia hạn thành công','Gói '||req.package_name||' đã được xác nhận và kích hoạt.','renewal') on conflict do nothing;
end $$;

create or replace function public.confirm_online_membership(request_id uuid, expected_amount integer, gateway_transaction text)
returns void language plpgsql security definer set search_path=public as $$
declare req public.membership_renewal_requests;
begin
  if coalesce(auth.role(),'') <> 'service_role' then raise exception 'Not authorized'; end if;
  select * into req from public.membership_renewal_requests where id=request_id for update;
  if req.id is null or req.payment_provider not in ('momo_business','legacy_review') or req.payment_method <> 'online'
    or req.amount is distinct from expected_amount or gateway_transaction is null
    or gateway_transaction !~ '^[1-9][0-9]*$' then raise exception 'Payment mismatch'; end if;
  if req.status='approved' then
    if req.transaction_no=gateway_transaction then return; end if;
    raise exception 'Transaction mismatch';
  end if;
  if req.transaction_no is not null and req.transaction_no <> gateway_transaction then raise exception 'Transaction mismatch'; end if;
  update public.membership_renewal_requests set transaction_no=gateway_transaction,payment_provider='momo_business',
    gateway_result_code=0,gateway_checked_at=now() where id=req.id;
  perform public.approve_membership_renewal(req.id);
end $$;

-- Both IPN and authenticated server-to-server query enter this transaction.
-- Never treat a deadline, transient code or unknown code as proof of nonpayment.
create function public.apply_momo_result(request_id uuid, expected_amount integer,
  result_code integer, gateway_transaction text default null, queried_missing boolean default false)
returns void language plpgsql security definer set search_path=public as $$
declare req public.membership_renewal_requests;
begin
  if coalesce(auth.role(),'') <> 'service_role' then raise exception 'Not authorized'; end if;
  select * into req from public.membership_renewal_requests where id=request_id for update;
  if req.id is null or req.payment_provider not in ('momo_business','legacy_review') then raise exception 'Invalid gateway order'; end if;
  if result_code=0 then
    perform public.confirm_online_membership(request_id,expected_amount,gateway_transaction);
    return;
  end if;
  if req.status='approved' then return; end if;
  if expected_amount is distinct from req.amount then raise exception 'Payment mismatch'; end if;
  update public.membership_renewal_requests set gateway_checked_at=now(),gateway_result_code=result_code where id=req.id;
  -- Not-found or failure cannot disprove a legacy personal transfer. Only a
  -- verified success or explicit administrator classification resolves routing.
  if req.payment_provider='legacy_review' then return; end if;
  if req.status <> 'pending' then return; end if;
  if result_code in (1001,1002,1003,1004,1005,1006,1007,1017,1026,4001,4002,4100)
    or (result_code=42 and queried_missing and req.gateway_started_at is not null
      and now() >= req.payment_expires_at+interval '5 minutes') then
    update public.membership_renewal_requests set
      status=case when result_code in (42,1005) then 'expired' else 'rejected' end,
      processed_at=now() where id=req.id;
  elsif req.gateway_started_at is null and now() >= req.payment_expires_at then
    -- No process ever claimed creation, and the row lock excludes future claims.
    update public.membership_renewal_requests set status='expired',processed_at=now() where id=req.id;
  end if;
end $$;
revoke all on function public.apply_momo_result(uuid,integer,integer,text,boolean) from public,anon,authenticated;
grant execute on function public.apply_momo_result(uuid,integer,integer,text,boolean) to service_role;
