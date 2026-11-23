-- Disposable local database only; no actual route matching or HTTP calls.
begin;
insert into auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values ('55000000-0000-4000-8000-000000000001','authenticated','authenticated','route-lifecycle@aetron.local','{}','{}',now(),now());

-- All fixtures share a user; only the server may publish the verdict.
insert into public.workout_sessions(id,user_id,activity_type,mode,started_at,ended_at,processing_status,metrics_version,distance_km,route_match_status,filtered_route_json,route_match_metrics_json)
select ('55000000-0000-4000-8000-0000000000'||lpad(n::text,2,'0'))::uuid,
 '55000000-0000-4000-8000-000000000001','running','outdoor',now()-interval '10 minutes',
 case when n=4 then null else now() end,
 case when n=4 then 'client_recording' when n in (5,6) then 'client_finished_pending_processing' else 'client_finalized' end,
 case when n in (4,5,6) then 1 else 2 end,0.5,
 case when n=7 then 'matched_success_high_confidence' else 'pending' end,
 case when n=1 then '[]'::jsonb else (select jsonb_build_array(jsonb_agg(jsonb_build_object('lat',0,'lng',0))) from generate_series(1,10)) end,
 '{"workout_validity_status":"partial","exact_replay":false}'::jsonb
from generate_series(1,7) n;

-- Independent research archive: a future server publication must preserve it.
insert into public.workout_sessions(id,user_id,activity_type,mode,started_at,ended_at,processing_status,metrics_version,distance_km,route_match_status,client_research_result_json,route_match_metrics_json)
values ('55000000-0000-4000-8000-000000000008','55000000-0000-4000-8000-000000000001','walking','outdoor',now()-interval '10 minutes',now(),'client_finalized',2,0.25,'pending',
 '{"version":1,"session_id":"55000000-0000-4000-8000-000000000008","audit":{"exact_replay":false}}',
 '{"client_scientific_reconciliation":{"selected":false,"exact_replay":false}}');

insert into public.workout_processing_jobs(workout_id,job_type,status)
values ('55000000-0000-4000-8000-000000000005','route_correction_finalize','queued'),
 ('55000000-0000-4000-8000-000000000006','route_correction_finalize','running');
update public.workout_sessions set processing_status='client_finalized',metrics_version=2
where id in ('55000000-0000-4000-8000-000000000005','55000000-0000-4000-8000-000000000006');

do $$ begin
 if not exists(select 1 from public.workout_sessions where id='55000000-0000-4000-8000-000000000001' and route_match_status='not_requested'
 and route_match_metrics_json#>>'{route_lifecycle,reason}'='insufficient_route_evidence') then raise exception 'Short route remains pending'; end if;
 if not exists(select 1 from public.workout_sessions where id='55000000-0000-4000-8000-000000000002' and route_match_status='not_requested'
 and route_match_metrics_json#>>'{route_lifecycle,reason}'='no_verified_route_matching_adapter'
 and distance_km=0.5 and route_match_confidence is null and matched_distance_km is null and matched_route_json='[]'
 and route_match_metrics_json->>'workout_validity_status'='partial' and route_match_metrics_json->'exact_replay'='false'
 and jsonb_array_length(filtered_route_json->0)=10) then raise exception 'Unsupported orphan was misclassified or evidence changed'; end if;
 if not exists(select 1 from public.workout_sessions where id='55000000-0000-4000-8000-000000000008' and route_match_status='not_requested'
 and route_match_metrics_json#>>'{route_lifecycle,reason}'='scientific_archive_only'
 and route_match_metrics_json->'client_scientific_reconciliation'='{"selected":false,"exact_replay":false}'::jsonb
 and client_research_result_json='{"version":1,"session_id":"55000000-0000-4000-8000-000000000008","audit":{"exact_replay":false}}'::jsonb
 and distance_km=0.25) then raise exception 'Scientific evidence modified'; end if;
 if (select count(*) from public.workout_sessions where id in ('55000000-0000-4000-8000-000000000004','55000000-0000-4000-8000-000000000005','55000000-0000-4000-8000-000000000006') and route_match_status='pending')<>3 then
 raise exception 'Recording or genuine active jobs were changed'; end if;
 if not exists(select 1 from public.workout_sessions where id='55000000-0000-4000-8000-000000000007' and route_match_status='matched_success_high_confidence') then raise exception 'Terminal verdict changed'; end if;
 if (select count(*) from public.workout_processing_jobs where workout_id in (select id from public.workout_sessions where user_id='55000000-0000-4000-8000-000000000001'))<>2 then raise exception 'Fabricated job'; end if;
end $$;

-- An actual worker result remains writable and takes precedence.
update public.workout_sessions set route_match_status='match_failed_fallback_filtered',route_match_metrics_json='{"reason":"no_verified_route_matching_adapter"}'
where id='55000000-0000-4000-8000-000000000005';
do $$ begin
 if not exists(select 1 from public.workout_sessions where id='55000000-0000-4000-8000-000000000005' and route_match_status='match_failed_fallback_filtered') then raise exception 'Worker result blocked'; end if;
end $$;
rollback;
