-- Run only against a disposable or local migrated test database.
begin;

insert into auth.users (
  id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '53000000-0000-4000-8000-000000000001', 'authenticated',
  'authenticated', 'scientific-fixture@aetron.local',
  '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now()
);

insert into public.workout_sessions (
  id, user_id, activity_type, mode, started_at, ended_at,
  distance_km, processing_status, metrics_version
) values
  ('53000000-0000-4000-8000-000000000011',
   '53000000-0000-4000-8000-000000000001', 'walking', 'outdoor',
   now() - interval '5 minutes', now(), 0.5, 'client_finished_pending_processing', 1),
  ('53000000-0000-4000-8000-000000000012',
   '53000000-0000-4000-8000-000000000001', 'walking', 'outdoor',
   now() - interval '5 minutes', now(), 0.4, 'client_finalized', 2);

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"53000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

-- First final artifact is accepted. Later retry/snapshot cannot mutate it.
update public.workout_sessions
set client_research_result_json = '{"version":1,"session_id":"53000000-0000-4000-8000-000000000011","distance_km":0.5}'
where id = '53000000-0000-4000-8000-000000000011';
update public.workout_sessions
set distance_km = 10, processing_status = 'client_recording',
    client_research_result_json = null,
    route_match_metrics_json = '{"live_snapshot":true}'
where id = '53000000-0000-4000-8000-000000000011';

do $$
declare w public.workout_sessions%rowtype;
begin
  select * into strict w from public.workout_sessions
  where id = '53000000-0000-4000-8000-000000000011';
  if w.distance_km <> 0.5 or w.processing_status <> 'client_finished_pending_processing'
    or (w.client_research_result_json->>'distance_km')::float8 <> 0.5
    or w.route_match_metrics_json ? 'live_snapshot' then
    raise exception 'Delayed client retry changed scientific artifact';
  end if;
end $$;

-- Service role may publish the server verdict, without mutating archive.
reset role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
update public.workout_sessions
set distance_km = 0.45, processing_status = 'client_finalized', metrics_version = 2,
    route_match_metrics_json = '{"client_scientific_reconciliation":{"selected":false,"exact_replay":false}}'
where id = '53000000-0000-4000-8000-000000000011';
insert into public.workout_processing_jobs (workout_id, job_type, status)
values ('53000000-0000-4000-8000-000000000011', 'deterministic_finalize', 'completed');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"53000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
-- A retry that claims to already be finalized must also preserve server verdict.
update public.workout_sessions
set distance_km = 20, processing_status = 'client_finalized',
    route_match_metrics_json = '{}', metrics_version = 1,
    client_research_result_json = '{"version":1,"distance_km":20}'
where id = '53000000-0000-4000-8000-000000000011';

-- First late artifact on an already finalized legacy record can be archived
-- only if it has the correct identity; the server metrics remain unchanged.
update public.workout_sessions
set distance_km = 99,
    client_research_result_json = '{"version":1,"session_id":"wrong"}'
where id = '53000000-0000-4000-8000-000000000012';
do $$
begin
  if exists (select 1 from public.workout_sessions
    where id = '53000000-0000-4000-8000-000000000012'
      and client_research_result_json is not null) then
    raise exception 'Mismatched late artifact accepted';
  end if;
end $$;
update public.workout_sessions
set distance_km = 99, processing_status = 'client_finished_pending_processing',
    client_research_result_json = '{"version":1,"session_id":"53000000-0000-4000-8000-000000000012","distance_km":0.3}'
where id = '53000000-0000-4000-8000-000000000012';

do $$
declare w public.workout_sessions%rowtype;
begin
  select * into strict w from public.workout_sessions
  where id = '53000000-0000-4000-8000-000000000011';
  if w.distance_km <> 0.45 or w.processing_status <> 'client_finalized'
    or w.metrics_version <> 2
    or (w.client_research_result_json->>'distance_km')::float8 <> 0.5
    or not (w.route_match_metrics_json ? 'client_scientific_reconciliation') then
    raise exception 'Completed server verdict overwritten by retry';
  end if;
  select * into strict w from public.workout_sessions
  where id = '53000000-0000-4000-8000-000000000012';
  if w.distance_km <> 0.4 or w.processing_status <> 'client_finalized'
    or (w.client_research_result_json->>'distance_km')::float8 <> 0.3 then
    raise exception 'Late archive changed server metrics or was not preserved';
  end if;
  begin
    insert into public.workout_processing_jobs (workout_id, job_type, status)
    values ('53000000-0000-4000-8000-000000000011', 'deterministic_finalize', 'queued');
    raise exception 'Completed duplicate job accepted';
  exception when unique_violation then
    null;
  end;
  insert into public.workout_processing_jobs (workout_id, job_type, status)
  values ('53000000-0000-4000-8000-000000000011', 'route_correction_finalize', 'queued');
end $$;

rollback;
