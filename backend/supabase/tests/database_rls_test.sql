begin;

insert into auth.users (
  id,
  aud,
  role,
  email,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) values
  (
    '10000000-0000-4000-8000-000000000001',
    'authenticated',
    'authenticated',
    'rls-user-a@aetron.local',
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  ),
  (
    '20000000-0000-4000-8000-000000000002',
    'authenticated',
    'authenticated',
    'rls-user-b@aetron.local',
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    now(),
    now()
  );

insert into public.user_profiles (user_id, weight_kg)
values
  ('10000000-0000-4000-8000-000000000001', 60),
  ('20000000-0000-4000-8000-000000000002', 70);

insert into public.workout_sessions (
  id,
  user_id,
  activity_type,
  mode,
  started_at
) values
  (
    '10000000-0000-4000-8000-000000000011',
    '10000000-0000-4000-8000-000000000001',
    'running',
    'outdoor',
    now()
  ),
  (
    '20000000-0000-4000-8000-000000000022',
    '20000000-0000-4000-8000-000000000002',
    'walking',
    'outdoor',
    now()
  );

insert into public.raw_gps_points (
  workout_id,
  timestamp,
  latitude,
  longitude
) values
  ('10000000-0000-4000-8000-000000000011', now(), 10.762622, 106.660172),
  ('20000000-0000-4000-8000-000000000022', now(), 10.762623, 106.660173);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

do $$
declare
  visible_count integer;
  affected_count integer;
  unvalidated_constraint_count integer;
  ended_at_is_nullable boolean;
begin
  select is_nullable = 'YES'
  into ended_at_is_nullable
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'workout_sessions'
    and column_name = 'ended_at';
  if ended_at_is_nullable is distinct from true then
    raise exception
      'Workout recording shell requires workout_sessions.ended_at to be nullable';
  end if;

  select count(*)
  into unvalidated_constraint_count
  from pg_constraint
  where conrelid = 'public.workout_ai_insights'::regclass
    and conname in (
      'workout_ai_insights_workout_id_fkey',
      'workout_ai_insights_user_id_fkey'
    )
    and not convalidated;
  if unvalidated_constraint_count <> 0 then
    raise exception
      'Fresh database has % unvalidated AI insight constraints',
      unvalidated_constraint_count;
  end if;

  select count(*) into visible_count from public.user_profiles;
  if visible_count <> 1 then
    raise exception 'RLS failure: user A sees % profiles', visible_count;
  end if;

  select count(*) into visible_count from public.workout_sessions;
  if visible_count <> 1 then
    raise exception 'RLS failure: user A sees % workouts', visible_count;
  end if;

  if (select count(*) from public.v_user_stats) <> 1
    or (select count(*) from public.v_weekly_stats) <> 1
    or (select count(*) from public.v_monthly_sessions) <> 1
    or exists (select 1 from public.v_user_stats where user_id <> auth.uid())
    or exists (select 1 from public.v_weekly_stats where user_id <> auth.uid())
    or exists (select 1 from public.v_monthly_sessions where user_id <> auth.uid()) then
    raise exception 'Reporting views must expose only the owner rows';
  end if;

  if has_table_privilege('anon', 'public.v_user_stats', 'SELECT')
    or has_table_privilege('anon', 'public.v_weekly_stats', 'SELECT')
    or has_table_privilege('anon', 'public.v_monthly_sessions', 'SELECT') then
    raise exception 'Anonymous reporting access must be denied';
  end if;

  select count(*) into visible_count from public.raw_gps_points;
  if visible_count <> 1 then
    raise exception 'RLS failure: user A sees % GPS points', visible_count;
  end if;

  update public.workout_sessions
  set activity_type = 'cycling'
  where id = '20000000-0000-4000-8000-000000000022';
  get diagnostics affected_count = row_count;
  if affected_count <> 0 then
    raise exception 'RLS failure: user A updated user B workout';
  end if;

  -- Exercise the production updated_at trigger on an owned active session.
  -- This catches legacy schemas where the trigger exists but its column does not.
  update public.workout_sessions
  set mode = 'indoor'
  where id = '10000000-0000-4000-8000-000000000011';
  get diagnostics affected_count = row_count;
  if affected_count <> 1 then
    raise exception 'Expected user A to update own workout';
  end if;

  delete from public.raw_gps_points
  where workout_id = '20000000-0000-4000-8000-000000000022';
  get diagnostics affected_count = row_count;
  if affected_count <> 0 then
    raise exception 'RLS failure: user A deleted user B GPS point';
  end if;

  begin
    insert into public.raw_gps_points (
      workout_id,
      timestamp,
      latitude,
      longitude
    ) values (
      '20000000-0000-4000-8000-000000000022',
      now(),
      10.7,
      106.6
    );
    raise exception 'RLS failure: cross-user GPS insert was accepted';
  exception
    when insufficient_privilege then null;
  end;

  insert into public.workout_ai_insights (
    workout_id,
    user_id,
    source,
    confidence,
    insight_json,
    payload_hash,
    fallback_reason
  ) values (
    '10000000-0000-4000-8000-000000000011',
    '10000000-0000-4000-8000-000000000001',
    'fallback_rule',
    1,
    '{"summary":"RLS integration fixture"}'::jsonb,
    repeat('a', 64),
    'none'
  );

  begin
    insert into public.workout_ai_insights (
      workout_id,
      user_id,
      source,
      confidence,
      insight_json,
      payload_hash,
      fallback_reason
    ) values (
      '20000000-0000-4000-8000-000000000022',
      '20000000-0000-4000-8000-000000000002',
      'fallback_rule',
      1,
      '{}'::jsonb,
      repeat('b', 64),
      'none'
    );
    raise exception 'RLS failure: cross-user AI insight insert was accepted';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;

rollback;
