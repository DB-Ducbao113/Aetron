-- Disposable test database only. net.http_post is mocked by the test harness.
begin;

insert into vault.decrypted_secrets(name, decrypted_secret, updated_at) values
  ('project_url', 'https://fixture.invalid', now()),
  ('service_role_key', repeat('legacy-test-', 4), now()),
  ('workout_dispatch_secret', repeat('x', 40), now());
insert into public.workout_sessions(id, ended_at, processing_status, metrics_version) values
  ('63000000-0000-4000-8000-000000000001', now(), 'client_finished_pending_processing', 1),
  ('63000000-0000-4000-8000-000000000002', null, 'client_recording', 1),
  ('63000000-0000-4000-8000-000000000003', now(), 'client_finalized', 2);
insert into public.workout_processing_jobs(id,workout_id,job_type,status,created_at) values
  ('63000000-0000-4000-8000-000000000011','63000000-0000-4000-8000-000000000001','deterministic_finalize','queued',now()-interval '3 minutes'),
  ('63000000-0000-4000-8000-000000000012','63000000-0000-4000-8000-000000000002','deterministic_finalize','queued',now()-interval '2 minutes'),
  ('63000000-0000-4000-8000-000000000013','63000000-0000-4000-8000-000000000001','route_correction_finalize','queued',now()),
  ('63000000-0000-4000-8000-000000000014','63000000-0000-4000-8000-000000000003','deterministic_finalize','completed',now()),
  ('63000000-0000-4000-8000-000000000015','63000000-0000-4000-8000-000000000003','route_correction_finalize','queued',now());

do $$
declare n int;
begin
  select count(*) into n from public.dispatch_workout_processing_jobs(5);
  if n <> 2 then raise exception 'expected only ended/ready jobs, got %', n; end if;
  if exists(select 1 from net.mock_http_requests r
    where r.headers ? 'Authorization' or r.headers ? 'apikey'
       or r.headers::text like '%' || repeat('x', 40) || '%'
       or r.headers->>'X-Aetron-Worker-Signature' is distinct from
         encode(extensions.hmac(
           convert_to(split_part(r.url, '/functions/v1/', 2) || chr(10) ||
             (r.body->>'job_id') || chr(10) || (r.body->>'workout_id') || chr(10) ||
             (r.body->>'dispatch_nonce') || chr(10) ||
             (r.headers->>'X-Aetron-Worker-Timestamp'), 'UTF8'),
           convert_to(repeat('x',40),'UTF8'), 'sha256'), 'hex')) then
    raise exception 'unsigned request or reusable credential exposed';
  end if;
  if (select dispatch_attempt_count from public.workout_processing_jobs where id='63000000-0000-4000-8000-000000000011') <> 1 then
    raise exception 'sending must consume retry budget before worker starts';
  end if;
  if (select attempt_count from public.workout_processing_jobs where id='63000000-0000-4000-8000-000000000011') <> 0 then
    raise exception 'dispatch must not consume worker processing attempts';
  end if;
  select count(*) into n from public.dispatch_workout_processing_jobs(5);
  if n <> 0 then raise exception 'immediate repeated dispatch bypassed backoff'; end if;
  -- Simulate lost/401 responses: the worker never claims the job.
  for i in 2..3 loop
    update public.workout_processing_jobs set dispatch_after=now()-interval '1 second'
      where id='63000000-0000-4000-8000-000000000011';
    select count(*) into n from public.dispatch_workout_processing_jobs(5);
    if n <> 1 then raise exception 'expected one retry, got %', n; end if;
  end loop;
  update public.workout_processing_jobs set dispatch_after=now()-interval '1 second'
    where id='63000000-0000-4000-8000-000000000011';
  select count(*) into n from public.dispatch_workout_processing_jobs(5);
  if n <> 0 then raise exception 'retry budget exceeded'; end if;
  if not exists(select 1 from public.workout_processing_jobs where id='63000000-0000-4000-8000-000000000011' and status='failed' and dispatch_attempt_count=3 and attempt_count=0) then
    raise exception 'exhausted dispatch must become failed';
  end if;
  if exists(select 1 from public.workout_processing_jobs where id in ('63000000-0000-4000-8000-000000000012','63000000-0000-4000-8000-000000000013') and dispatch_attempt_count<>0) then
    raise exception 'unfinished or dependent job consumed retry budget';
  end if;
  if not exists(select 1 from public.workout_processing_jobs where id='63000000-0000-4000-8000-000000000013' and status='failed' and dispatch_attempt_count=0) then
    raise exception 'terminal deterministic failure must terminate dependent job without HTTP dispatch';
  end if;
  if (select count(distinct body->>'dispatch_nonce') from net.mock_http_requests
      where body->>'job_id' = '63000000-0000-4000-8000-000000000011') <> 3 then
    raise exception 'retry must generate a fresh dispatch nonce';
  end if;
  update public.workout_processing_jobs set status='running', started_at=now()-interval '11 minutes', attempt_count=1
    where id='63000000-0000-4000-8000-000000000015';
  select count(*) into n from public.requeue_stale_workout_processing_jobs();
  if n<>1 or not exists(select 1 from public.workout_processing_jobs where id='63000000-0000-4000-8000-000000000015' and status='queued' and dispatch_nonce is null) then
    raise exception 'stale running job did not recover';
  end if;
  if not exists(select 1 from public.workout_processing_jobs where id='63000000-0000-4000-8000-000000000014' and status='completed') then
    raise exception 'completed dependency modified by stale recovery';
  end if;
end $$;
rollback;
