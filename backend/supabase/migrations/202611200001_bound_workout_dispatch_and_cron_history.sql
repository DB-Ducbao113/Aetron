-- Separate transport retries from worker processing attempts. A failed HTTP
-- request may never reach the worker and therefore never increment attempt_count.
alter table public.workout_processing_jobs
  add column if not exists dispatch_attempt_count integer not null default 0
    check (dispatch_attempt_count between 0 and 3),
  add column if not exists dispatch_after timestamptz not null default now(),
  add column if not exists last_dispatch_request_id bigint,
  add column if not exists dispatch_nonce uuid;

-- Mobile clients own their workout rows but not the transport retry budget.
create or replace function public.guard_workout_dispatch_fields()
returns trigger language plpgsql set search_path = '' as $$
begin
  if auth.role() = 'authenticated' then
    if tg_op = 'INSERT' then
      new.dispatch_attempt_count := 0;
      new.dispatch_after := now();
      new.last_dispatch_request_id := null;
      new.dispatch_nonce := null;
    else
      new.dispatch_attempt_count := old.dispatch_attempt_count;
      new.dispatch_after := old.dispatch_after;
      new.last_dispatch_request_id := old.last_dispatch_request_id;
      new.dispatch_nonce := old.dispatch_nonce;
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists guard_workout_dispatch_fields on public.workout_processing_jobs;
create trigger guard_workout_dispatch_fields
before insert or update on public.workout_processing_jobs
for each row execute function public.guard_workout_dispatch_fields();

-- Recheck and lock stale work before changing its state. A worker that has
-- completed in the meantime must never be returned to the queue.
create or replace function public.requeue_stale_workout_processing_jobs(
  stale_after interval default interval '10 minutes'
)
returns table (recovered_job_id uuid, recovered_status text)
language plpgsql security definer set search_path = '' as $$
begin
  return query
  with stale as (
    select j.id from public.workout_processing_jobs j
    where j.status = 'running' and j.started_at is not null
      and j.started_at < now() - coalesce(stale_after, interval '10 minutes')
    for update skip locked
  )
  update public.workout_processing_jobs j
  set status = case when j.attempt_count < 3 and j.dispatch_attempt_count < 3 then 'queued' else 'failed' end,
      started_at = case when j.attempt_count < 3 and j.dispatch_attempt_count < 3 then null else j.started_at end,
      finished_at = case when j.attempt_count < 3 and j.dispatch_attempt_count < 3 then null else now() end,
      error_message = case when j.attempt_count < 3 and j.dispatch_attempt_count < 3 then null else 'Processing job exceeded stale recovery retry budget.' end,
      dispatch_nonce = null
  from stale where j.id = stale.id and j.status = 'running'
  returning j.id, j.status;
end;
$$;

create or replace function public.dispatch_workout_processing_jobs(
  batch_size integer default 5
)
returns table (dispatched_job_id uuid, dispatched_job_type text, request_id bigint)
language plpgsql security definer set search_path = '' as $$
declare
  project_url text;
  dispatch_secret text;
  worker_name text;
  job record;
  http_request_id bigint;
  nonce uuid;
  signed_at text;
  signature text;
begin
  -- Prevent concurrent manual/cron calls from sending the same job.
  if not pg_try_advisory_xact_lock(20261120, 1) then return; end if;
  perform public.requeue_stale_workout_processing_jobs();

  select decrypted_secret into project_url from vault.decrypted_secrets
  where name = 'project_url' order by updated_at desc limit 1;
  select decrypted_secret into dispatch_secret from vault.decrypted_secrets
  where name = 'workout_dispatch_secret' order by updated_at desc limit 1;
  if project_url is null or coalesce(length(dispatch_secret), 0) < 32 then
    raise warning 'Workout dispatcher paused: missing project_url or workout_dispatch_secret in Vault.';
    return;
  end if;
  project_url := regexp_replace(project_url, '/+$', '');

  -- The last send has a 15-minute grace period before declaring exhaustion.
  update public.workout_processing_jobs
  set status = 'failed', finished_at = now(), dispatch_nonce = null,
      error_message = 'Workout dispatch retry budget exhausted; inspect last_dispatch_request_id.'
  where status = 'queued' and dispatch_attempt_count >= 3 and dispatch_after <= now();

  -- A terminal deterministic failure makes route correction impossible.
  -- Keep the failed job as evidence rather than leaving it queued forever.
  update public.workout_processing_jobs route_job
  set status = 'failed', finished_at = now(), dispatch_nonce = null,
      error_message = 'Deterministic finalize dependency failed.'
  where route_job.status = 'queued' and route_job.job_type = 'route_correction_finalize'
    and (select f.status from public.workout_processing_jobs f
         where f.workout_id = route_job.workout_id and f.job_type = 'deterministic_finalize'
         order by f.created_at desc, f.id desc limit 1) = 'failed';

  for job in
    select jobs.id, jobs.workout_id, jobs.job_type, jobs.dispatch_attempt_count
    from public.workout_processing_jobs jobs
    join public.workout_sessions workout on workout.id = jobs.workout_id
    where jobs.status = 'queued'
      and jobs.attempt_count < 3 and jobs.dispatch_attempt_count < 3
      and jobs.dispatch_after <= now() and workout.ended_at is not null
      and (
        jobs.job_type = 'deterministic_finalize'
        or (jobs.job_type = 'route_correction_finalize'
          and workout.processing_status = 'client_finalized'
          and workout.metrics_version >= 2
          and (select finalize.status from public.workout_processing_jobs finalize
               where finalize.workout_id = jobs.workout_id
                 and finalize.job_type = 'deterministic_finalize'
               order by finalize.created_at desc, finalize.id desc limit 1) = 'completed')
      )
    order by case jobs.job_type when 'deterministic_finalize' then 0 else 1 end,
             jobs.created_at, jobs.id
    limit least(greatest(coalesce(batch_size, 5), 1), 5)
    for update of jobs skip locked
  loop
    worker_name := case job.job_type
      when 'deterministic_finalize' then 'deterministic-finalize-worker'
      else 'route-correction-worker' end;

    -- pg_net's managed queue is readable by database roles on hosted
    -- projects. Send only a short-lived signature, never a reusable secret.
    signed_at := floor(extract(epoch from clock_timestamp()))::bigint::text;
    nonce := gen_random_uuid();
    signature := encode(extensions.hmac(
      convert_to(worker_name || chr(10) || job.id::text || chr(10) ||
                 job.workout_id::text || chr(10) || nonce::text || chr(10) || signed_at, 'UTF8'),
      convert_to(dispatch_secret, 'UTF8'), 'sha256'), 'hex');
    -- Persist an independent transport attempt with the queued HTTP request.
    -- pg_net enqueues transactionally, so a SQL failure rolls back both.
    select net.http_post(
      url := project_url || '/functions/v1/' || worker_name,
      body := jsonb_build_object('job_id', job.id, 'workout_id', job.workout_id,
                                'dispatch_nonce', nonce),
      headers := jsonb_build_object('Content-Type', 'application/json',
                                    'X-Aetron-Worker-Timestamp', signed_at,
                                    'X-Aetron-Worker-Signature', signature),
      timeout_milliseconds := 5000
    ) into http_request_id;

    update public.workout_processing_jobs
    set dispatch_attempt_count = job.dispatch_attempt_count + 1,
        dispatch_after = now() + case job.dispatch_attempt_count
          when 0 then interval '2 minutes'
          when 1 then interval '5 minutes'
          else interval '15 minutes' end,
        last_dispatch_request_id = http_request_id,
        dispatch_nonce = nonce
    where id = job.id;

    dispatched_job_id := job.id;
    dispatched_job_type := job.job_type;
    request_id := http_request_id;
    return next;
  end loop;
end;
$$;
revoke all on function public.dispatch_workout_processing_jobs(integer)
  from public, anon, authenticated;
grant execute on function public.dispatch_workout_processing_jobs(integer) to service_role;

-- Keep one week of completed cron history. pg_net already has its own TTL.
-- Do not activate the dispatcher here: production must first deploy the
-- workers and configure matching Vault/Edge secrets.
select cron.schedule(
  'cleanup-cron-run-history', '31 3 * * *',
  $cron$delete from cron.job_run_details
        where end_time < now() - interval '7 days';$cron$
);
