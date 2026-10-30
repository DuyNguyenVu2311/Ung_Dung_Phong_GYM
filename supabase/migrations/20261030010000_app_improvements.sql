-- FitPlan improvements: richer personalization, history, membership and account controls.

alter table public.profiles
  add column if not exists occupation text not null default '',
  add column if not exists activity_level text not null default 'moderate'
    check (activity_level in ('sedentary', 'moderate', 'active')),
  add column if not exists available_weekdays integer[] not null default array[1,3,5],
  add column if not exists preferred_workout_time text not null default 'evening'
    check (preferred_workout_time in ('morning', 'afternoon', 'evening')),
  add column if not exists dietary_preference text not null default 'balanced'
    check (dietary_preference in ('balanced', 'vegetarian', 'low_carb')),
  add column if not exists health_notes text not null default '';

alter table public.workout_sessions
  add column if not exists branch_name text not null default 'FitPlan Center',
  add column if not exists check_in_at timestamptz;

drop index if exists public.workout_sessions_user_client_id_idx;
create unique index if not exists workout_sessions_user_client_id_idx
  on public.workout_sessions (user_id, client_session_id);

create table if not exists public.memberships (
  id text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  branch_name text not null,
  start_date date not null,
  end_date date not null,
  used_sessions integer not null default 0 check (used_sessions >= 0),
  total_sessions integer not null default 0 check (total_sessions >= 0),
  price integer not null default 0 check (price >= 0),
  active boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table if not exists public.app_notifications (
  id text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  message text not null,
  notice_type text not null default 'system',
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table if not exists public.promotions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  active boolean not null default true
);

alter table public.memberships enable row level security;
alter table public.app_notifications enable row level security;
alter table public.promotions enable row level security;

grant select, insert, update, delete on public.memberships to authenticated;
grant select, insert, update, delete on public.app_notifications to authenticated;
grant select on public.promotions to authenticated;

create policy "Users manage their memberships"
on public.memberships for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users manage their notifications"
on public.app_notifications for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Authenticated users read active promotions"
on public.promotions for select to authenticated
using (active and now() between starts_at and ends_at);

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
