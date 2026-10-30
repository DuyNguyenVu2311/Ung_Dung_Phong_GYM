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
