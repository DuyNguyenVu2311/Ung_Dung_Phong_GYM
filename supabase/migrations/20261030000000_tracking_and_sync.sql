-- FitPlan tracking, favorites and idempotent client synchronization.

alter table public.workout_sessions
  add column if not exists client_session_id text;

create unique index if not exists workout_sessions_user_client_id_idx
  on public.workout_sessions (user_id, client_session_id)
  where client_session_id is not null;

alter table public.exercise_logs
  add column if not exists rpe integer check (rpe between 1 and 10),
  add column if not exists is_personal_record boolean not null default false;

create table if not exists public.daily_check_ins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  check_in_date date not null,
  energy integer not null check (energy between 1 and 5),
  soreness integer not null check (soreness between 1 and 5),
  sleep_quality integer not null check (sleep_quality between 1 and 5),
  available_minutes integer not null check (available_minutes between 5 and 240),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, check_in_date)
);

create table if not exists public.body_measurements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  client_id text not null,
  measured_at timestamptz not null,
  weight_kg numeric(6, 2) not null check (weight_kg between 20 and 400),
  created_at timestamptz not null default now(),
  unique (user_id, client_id)
);

create table if not exists public.favorite_exercises (
  user_id uuid not null references auth.users (id) on delete cascade,
  exercise_id text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, exercise_id)
);

alter table public.daily_check_ins enable row level security;
alter table public.body_measurements enable row level security;
alter table public.favorite_exercises enable row level security;

grant select, insert, update, delete on public.daily_check_ins to authenticated;
grant select, insert, update, delete on public.body_measurements to authenticated;
grant select, insert, update, delete on public.favorite_exercises to authenticated;

create policy "Users manage their check-ins"
on public.daily_check_ins for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users manage their measurements"
on public.body_measurements for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users manage their favorites"
on public.favorite_exercises for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
