create or replace function public.sync_workout_session(
  p_client_session_id text,
  p_day_name text,
  p_performed_at timestamptz,
  p_branch_name text,
  p_check_in_at timestamptz,
  p_logs jsonb
)
returns uuid
language plpgsql
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  v_session_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;
  if nullif(trim(p_client_session_id), '') is null then
    raise exception 'Client session ID is required';
  end if;
  if jsonb_typeof(coalesce(p_logs, '[]'::jsonb)) <> 'array' then
    raise exception 'Workout logs must be an array';
  end if;

  insert into public.workout_sessions (
    user_id,
    client_session_id,
    day_name,
    performed_at,
    branch_name,
    check_in_at
  )
  values (
    current_user_id,
    p_client_session_id,
    p_day_name,
    p_performed_at,
    p_branch_name,
    p_check_in_at
  )
  on conflict (user_id, client_session_id)
  do update set
    day_name = excluded.day_name,
    performed_at = excluded.performed_at,
    branch_name = excluded.branch_name,
    check_in_at = excluded.check_in_at
  returning id into v_session_id;

  delete from public.exercise_logs
  where user_id = current_user_id and session_id = v_session_id;

  insert into public.exercise_logs (
    user_id,
    session_id,
    exercise_name,
    sets,
    reps,
    weight_kg,
    rpe,
    is_personal_record
  )
  select
    current_user_id,
    v_session_id,
    logs.exercise_name,
    logs.sets,
    logs.reps,
    logs.weight_kg,
    logs.rpe,
    coalesce(logs.is_personal_record, false)
  from jsonb_to_recordset(coalesce(p_logs, '[]'::jsonb)) as logs(
    exercise_name text,
    sets integer,
    reps integer,
    weight_kg numeric,
    rpe integer,
    is_personal_record boolean
  );

  return v_session_id;
end;
$$;

revoke all on function public.sync_workout_session(
  text, text, timestamptz, text, timestamptz, jsonb
) from public, anon;
grant execute on function public.sync_workout_session(
  text, text, timestamptz, text, timestamptz, jsonb
) to authenticated;
