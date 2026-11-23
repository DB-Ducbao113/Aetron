-- Isolated migrated test database. Always rolled back.
begin;
insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values ('55000000-0000-4000-8000-000000000001','authenticated','authenticated','interrupted-a@aetron.local','{}','{}',now(),now()),
       ('55000000-0000-4000-8000-000000000002','authenticated','authenticated','interrupted-b@aetron.local','{}','{}',now(),now());
insert into public.workout_sessions(id,user_id,activity_type,mode,started_at,ended_at,updated_at,processing_status)
values
 ('55000000-0000-4000-8000-000000000011','55000000-0000-4000-8000-000000000001','walking','outdoor',now()-interval '3 days',null,now()-interval '2 days','client_recording'),
 ('55000000-0000-4000-8000-000000000012','55000000-0000-4000-8000-000000000001','walking','outdoor',now()-interval '3 days',null,now()-interval '2 days','client_recording'),
 ('55000000-0000-4000-8000-000000000013','55000000-0000-4000-8000-000000000001','walking','outdoor',now()-interval '3 days',null,now()-interval '2 days','client_recording'),
 ('55000000-0000-4000-8000-000000000014','55000000-0000-4000-8000-000000000002','walking','outdoor',now()-interval '3 days',null,now()-interval '2 days','client_recording'),
 ('55000000-0000-4000-8000-000000000015','55000000-0000-4000-8000-000000000001','walking','outdoor',now()-interval '3 days',now()-interval '2 days',now()-interval '2 days','client_finished_pending_processing');
insert into public.raw_gps_points(workout_id,timestamp,latitude,longitude)
values ('55000000-0000-4000-8000-000000000011',now()-interval '2 days',0,0),
       ('55000000-0000-4000-8000-000000000013',now()-interval '1 hour',0,0);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"55000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000001',true);
do $$ begin
  if (select count(*) from public.v_interrupted_workout_sessions) <> 2 then
    raise exception 'Interrupted view must show only owner stale open sessions';
  end if;
  if not exists(select 1 from public.v_interrupted_workout_sessions
    where workout_id='55000000-0000-4000-8000-000000000011'
      and recovery_state='evidence_available' and raw_gps_points=1) then
    raise exception 'Existing raw evidence is not detected';
  end if;
  if not exists(select 1 from public.v_interrupted_workout_sessions
    where workout_id='55000000-0000-4000-8000-000000000012' and recovery_state='no_cloud_evidence') then
    raise exception 'Empty shell is not distinguishable';
  end if;
  if has_table_privilege('anon','public.v_interrupted_workout_sessions','SELECT') then
    raise exception 'Anonymous recovery access';
  end if;
end $$;
rollback;
