alter table public.profiles
  add column if not exists workout_minutes integer not null default 60
  check (workout_minutes between 15 and 120);
