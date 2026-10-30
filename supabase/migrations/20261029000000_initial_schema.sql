-- FitPlan initial schema.
-- Run with the Supabase CLI or paste into the Supabase SQL editor.

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  name text not null default '',
  age integer not null check (age between 10 and 120),
  height_cm numeric(5, 2) not null check (height_cm > 0),
  weight_kg numeric(6, 2) not null check (weight_kg > 0),
  gender text not null default '',
  goal text not null check (goal in ('muscle', 'fatloss', 'maintenance')),
  experience_level text not null check (experience_level in ('beginner', 'intermediate')),
  sessions_per_week integer not null check (sessions_per_week between 1 and 7),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.exercises (
  id text primary key,
  name text not null,
  muscle_group text not null,
  description text not null default '',
  image_url text not null default '',
  created_at timestamptz not null default now()
);

create table public.workout_schedules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  scheduled_date date not null,
  day_name text not null,
  is_rest boolean not null default false,
  status text not null default 'planned'
    check (status in ('planned', 'in_progress', 'completed', 'rest_day')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id),
  unique (user_id, scheduled_date)
);

create table public.schedule_exercises (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  schedule_id uuid not null,
  exercise_id text not null references public.exercises (id),
  position integer not null default 0,
  sets integer not null check (sets > 0),
  reps integer not null check (reps > 0),
  weight_kg numeric(7, 2) not null default 0 check (weight_kg >= 0),
  unique (schedule_id, exercise_id),
  foreign key (schedule_id, user_id)
    references public.workout_schedules (id, user_id) on delete cascade
);

create table public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  schedule_id uuid,
  day_name text not null,
  performed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (id, user_id),
  foreign key (schedule_id, user_id)
    references public.workout_schedules (id, user_id) on delete set null (schedule_id)
);

create table public.exercise_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  session_id uuid not null,
  exercise_id text references public.exercises (id) on delete set null,
  exercise_name text not null,
  sets integer not null check (sets > 0),
  reps integer not null check (reps > 0),
  weight_kg numeric(7, 2) not null default 0 check (weight_kg >= 0),
  created_at timestamptz not null default now(),
  foreign key (session_id, user_id)
    references public.workout_sessions (id, user_id) on delete cascade
);

create index workout_schedules_user_id_idx on public.workout_schedules (user_id);
create index schedule_exercises_user_id_idx on public.schedule_exercises (user_id);
create index schedule_exercises_schedule_id_idx on public.schedule_exercises (schedule_id);
create index workout_sessions_user_id_idx on public.workout_sessions (user_id);
create index exercise_logs_user_id_idx on public.exercise_logs (user_id);
create index exercise_logs_session_id_idx on public.exercise_logs (session_id);

alter table public.profiles enable row level security;
alter table public.exercises enable row level security;
alter table public.workout_schedules enable row level security;
alter table public.schedule_exercises enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.exercise_logs enable row level security;

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.exercises from anon, authenticated;
revoke all on table public.workout_schedules from anon, authenticated;
revoke all on table public.schedule_exercises from anon, authenticated;
revoke all on table public.workout_sessions from anon, authenticated;
revoke all on table public.exercise_logs from anon, authenticated;

grant select, insert, update, delete on table public.profiles to authenticated;
grant select on table public.exercises to authenticated;
grant select, insert, update, delete on table public.workout_schedules to authenticated;
grant select, insert, update, delete on table public.schedule_exercises to authenticated;
grant select, insert, update, delete on table public.workout_sessions to authenticated;
grant select, insert, update, delete on table public.exercise_logs to authenticated;

create policy "Authenticated users can read exercises"
on public.exercises for select to authenticated
using (true);

create policy "Users can read their profile"
on public.profiles for select to authenticated
using ((select auth.uid()) = user_id);
create policy "Users can create their profile"
on public.profiles for insert to authenticated
with check ((select auth.uid()) = user_id);
create policy "Users can update their profile"
on public.profiles for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
create policy "Users can delete their profile"
on public.profiles for delete to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can read their schedules"
on public.workout_schedules for select to authenticated
using ((select auth.uid()) = user_id);
create policy "Users can create their schedules"
on public.workout_schedules for insert to authenticated
with check ((select auth.uid()) = user_id);
create policy "Users can update their schedules"
on public.workout_schedules for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
create policy "Users can delete their schedules"
on public.workout_schedules for delete to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can read their scheduled exercises"
on public.schedule_exercises for select to authenticated
using ((select auth.uid()) = user_id);
create policy "Users can create their scheduled exercises"
on public.schedule_exercises for insert to authenticated
with check ((select auth.uid()) = user_id);
create policy "Users can update their scheduled exercises"
on public.schedule_exercises for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
create policy "Users can delete their scheduled exercises"
on public.schedule_exercises for delete to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can read their sessions"
on public.workout_sessions for select to authenticated
using ((select auth.uid()) = user_id);
create policy "Users can create their sessions"
on public.workout_sessions for insert to authenticated
with check ((select auth.uid()) = user_id);
create policy "Users can update their sessions"
on public.workout_sessions for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
create policy "Users can delete their sessions"
on public.workout_sessions for delete to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can read their exercise logs"
on public.exercise_logs for select to authenticated
using ((select auth.uid()) = user_id);
create policy "Users can create their exercise logs"
on public.exercise_logs for insert to authenticated
with check ((select auth.uid()) = user_id);
create policy "Users can update their exercise logs"
on public.exercise_logs for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
create policy "Users can delete their exercise logs"
on public.exercise_logs for delete to authenticated
using ((select auth.uid()) = user_id);
