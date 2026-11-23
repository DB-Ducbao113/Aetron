-- Disposable migrated test database only. All test rows roll back.
begin;

insert into auth.users (id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values ('54000000-0000-4000-8000-000000000001','authenticated','authenticated','authority-a@aetron.local','{}','{}',now(),now()),
       ('54000000-0000-4000-8000-000000000002','authenticated','authenticated','authority-b@aetron.local','{}','{}',now(),now());

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"54000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','54000000-0000-4000-8000-000000000001',true), set_config('request.jwt.claim.role','authenticated',true);

-- A real shell and snapshot, followed by an attempted forged final verdict.
insert into public.workout_sessions(id,user_id,activity_type,mode,started_at,processing_status,metrics_version)
values ('54000000-0000-4000-8000-000000000011',auth.uid(),'running','outdoor',now(),'client_recording',1);
update public.workout_sessions set filtered_route_json='[]',route_match_status='not_requested',
 route_distance_source='filtered',route_match_metrics_json='{"live_snapshot":true,"route_point_count":3,"client_scientific_reconciliation":{"selected":true}}'
where id='54000000-0000-4000-8000-000000000011';
do $$ begin
 if not exists(select 1 from public.workout_sessions where id='54000000-0000-4000-8000-000000000011'
  and route_match_status='not_requested' and route_match_metrics_json->>'route_point_count'='3'
  and not (route_match_metrics_json ? 'client_scientific_reconciliation')) then
  raise exception 'Snapshot contract or server-field isolation failed'; end if;
end $$;

update public.workout_sessions set ended_at=now(),distance_km=1,processing_status='client_finalized',metrics_version=2,
 data_quality_score=100,matched_route_json='[[]]',matched_distance_km=99,route_match_confidence=1,
 route_distance_source='matched',route_match_status='matched_success_high_confidence',
 route_match_metrics_json='{"server_verdict":"forged"}',
 client_research_result_json='{"version":1,"session_id":"54000000-0000-4000-8000-000000000011"}'
where id='54000000-0000-4000-8000-000000000011';
-- Direct finalized insert must also remain a client submission.
insert into public.workout_sessions(id,user_id,activity_type,mode,started_at,ended_at,processing_status,metrics_version,data_quality_score)
values ('54000000-0000-4000-8000-000000000012',auth.uid(),'walking','indoor',now(),now(),'client_finalized',9,100);

insert into public.workout_processing_jobs(id,workout_id,job_type,status,attempt_count,started_at,finished_at,error_message,dispatch_attempt_count,last_dispatch_request_id,dispatch_nonce)
values ('54000000-0000-4000-8000-000000000021','54000000-0000-4000-8000-000000000011','deterministic_finalize','completed',9,now(),now(),'forged',3,99,gen_random_uuid());

insert into public.workout_processing_logs(workout_id,job_id,log_level,event_type,message,payload,source)
values ('54000000-0000-4000-8000-000000000011','54000000-0000-4000-8000-000000000021','info','client_finish_enqueued','fixture','{}','server');

-- Raw uploads are still accepted, including late offline retry.
insert into public.raw_gps_points(workout_id,timestamp,latitude,longitude)
values ('54000000-0000-4000-8000-000000000011',now(),0,0)
on conflict(workout_id,timestamp,latitude,longitude) do nothing;
insert into public.raw_step_intervals(workout_id,interval_start,interval_end,steps_count)
values ('54000000-0000-4000-8000-000000000011',now(),now(),1)
on conflict(workout_id,interval_start,interval_end) do nothing;

do $$ declare n int; begin
 if (select count(*) from public.workout_sessions where processing_status='client_finished_pending_processing' and metrics_version=1 and data_quality_score is null) <> 2 then
  raise exception 'Client forged canonical metrics'; end if;
 if not exists(select 1 from public.workout_sessions where id='54000000-0000-4000-8000-000000000011'
  and matched_route_json='[]' and matched_distance_km is null and route_match_confidence is null
  and route_distance_source='filtered' and route_match_status='pending' and route_match_metrics_json='{}'
  and client_research_result_json is not null) then raise exception 'Client verdict or artifact contract failed'; end if;
 if not exists(select 1 from public.workout_processing_jobs where id='54000000-0000-4000-8000-000000000021'
  and status='queued' and attempt_count=0 and started_at is null and finished_at is null and error_message is null
  and dispatch_attempt_count=0 and last_dispatch_request_id is null and dispatch_nonce is null) then
  raise exception 'Client forged processing job'; end if;
 if not exists(select 1 from public.workout_processing_logs where event_type='client_finish_enqueued' and source='client') then
  raise exception 'Forged log provenance'; end if;
 begin
  update public.workout_processing_jobs set status='completed' where id='54000000-0000-4000-8000-000000000021';
  raise exception 'Client job UPDATE allowed'; exception when insufficient_privilege then null; end;
 begin
  delete from public.workout_processing_jobs where id='54000000-0000-4000-8000-000000000021';
  raise exception 'Client job DELETE allowed'; exception when insufficient_privilege then null; end;
 begin
  update public.workout_processing_logs set message='tamper';
  raise exception 'Client log UPDATE allowed'; exception when insufficient_privilege then null; end;
 begin
  delete from public.workout_processing_logs;
  raise exception 'Client log DELETE allowed'; exception when insufficient_privilege then null; end;
 begin
  insert into public.workout_processing_logs(workout_id,event_type,message) values
   ('54000000-0000-4000-8000-000000000011','deterministic_finalize_completed','forged');
  raise exception 'Client server event allowed'; exception when check_violation then null; end;
 begin
  insert into public.workout_processing_logs(workout_id,job_id,event_type,message) values
   ('54000000-0000-4000-8000-000000000012','54000000-0000-4000-8000-000000000021','client_finish_enqueued','wrong workout');
  raise exception 'Cross-workout job reference allowed'; exception when check_violation then null; end;
 delete from public.raw_gps_points; get diagnostics n=row_count;
 if n<>0 then raise exception 'Selective raw GPS delete allowed'; end if;
 delete from public.raw_step_intervals; get diagnostics n=row_count;
 if n<>0 then raise exception 'Selective raw step delete allowed'; end if;
end $$;

reset role;
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select set_config('request.jwt.claim.sub','',true), set_config('request.jwt.claim.role','service_role',true);
update public.workout_sessions set processing_status='client_finalized',metrics_version=2,data_quality_score=90,distance_km=0.9
where id='54000000-0000-4000-8000-000000000011';
update public.workout_processing_jobs set status='completed',attempt_count=1,finished_at=now()
where id='54000000-0000-4000-8000-000000000021';
insert into public.workout_processing_logs(workout_id,job_id,event_type,message)
values ('54000000-0000-4000-8000-000000000011','54000000-0000-4000-8000-000000000021','deterministic_finalize_completed','fixture');

reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"54000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','54000000-0000-4000-8000-000000000001',true), set_config('request.jwt.claim.role','authenticated',true);
update public.workout_sessions set distance_km=100,data_quality_score=0,metrics_version=1,processing_status='client_recording'
where id='54000000-0000-4000-8000-000000000011';
do $$ begin
 if not exists(select 1 from public.workout_sessions where id='54000000-0000-4000-8000-000000000011'
 and processing_status='client_finalized' and metrics_version=2 and data_quality_score=90 and distance_km=0.9) then
  raise exception 'Server verdict overwritten or worker blocked'; end if;
 if not exists(select 1 from public.workout_processing_logs where source='server' and event_type='deterministic_finalize_completed') then
  raise exception 'Server log blocked'; end if;
end $$;

-- Other user still cannot see or enqueue against the workout.
select set_config('request.jwt.claims','{"sub":"54000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','54000000-0000-4000-8000-000000000002',true), set_config('request.jwt.claim.role','authenticated',true);
do $$ begin
 if exists(select 1 from public.workout_sessions where id='54000000-0000-4000-8000-000000000011') then
  raise exception 'Cross-owner read'; end if;
 begin
  insert into public.workout_processing_jobs(workout_id,job_type) values ('54000000-0000-4000-8000-000000000011','route_correction_finalize');
  raise exception 'Cross-owner enqueue'; exception when insufficient_privilege then null; end;
end $$;

-- Whole workout deletion must remain available with cascading evidence.
select set_config('request.jwt.claims','{"sub":"54000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','54000000-0000-4000-8000-000000000001',true), set_config('request.jwt.claim.role','authenticated',true);
delete from public.workout_sessions where id='54000000-0000-4000-8000-000000000011';
reset role;
do $$ begin
 if exists(select 1 from public.workout_sessions where id='54000000-0000-4000-8000-000000000011')
 or exists(select 1 from public.workout_processing_jobs where workout_id='54000000-0000-4000-8000-000000000011')
 or exists(select 1 from public.workout_processing_logs where workout_id='54000000-0000-4000-8000-000000000011')
 or exists(select 1 from public.raw_gps_points where workout_id='54000000-0000-4000-8000-000000000011')
 or exists(select 1 from public.raw_step_intervals where workout_id='54000000-0000-4000-8000-000000000011') then
  raise exception 'Whole workout cascade broken'; end if;
end $$;
rollback;
