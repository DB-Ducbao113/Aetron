-- The client submits observations and requests work; only trusted workers
-- publish canonical verdicts. Existing rows are not rewritten.
-- Keep the existing scientific retry behavior, including the late archive.
create or replace function public.guard_scientific_workout_retry()
returns trigger language plpgsql set search_path = '' as $$
declare
  valid_artifact boolean;
  snapshot jsonb;
begin
  if current_user <> 'authenticated' and auth.role() is distinct from 'authenticated' then
    return new;
  end if;

  valid_artifact := coalesce(jsonb_typeof(new.client_research_result_json) = 'object'
    and new.client_research_result_json->>'session_id' = new.id::text
    and new.client_research_result_json->'version' = '1'::jsonb, false);

  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id or new.user_id is distinct from old.user_id then
      raise insufficient_privilege using message = 'Workout identity is immutable';
    end if;
    if old.client_research_result_json is not null or
       (old.processing_status = 'client_finalized' and old.metrics_version >= 2) then
      if old.client_research_result_json is null and valid_artifact then
        old.client_research_result_json := new.client_research_result_json;
      end if;
      return old;
    end if;
    -- A delayed recording shell must not reopen a completed client upload.
    if old.ended_at is not null and new.ended_at is null then return old; end if;
  end if;

  if new.client_research_result_json is not null and
     (not valid_artifact or new.ended_at is null) then
    raise check_violation using message = 'Invalid client scientific artifact';
  end if;

  new.processing_status := case when new.ended_at is null then 'client_recording'
    else 'client_finished_pending_processing' end;
  new.metrics_version := 1;
  new.data_quality_score := null;
  new.matched_route_json := '[]'::jsonb;
  new.matched_distance_km := null;
  new.route_match_confidence := null;
  new.route_distance_source := 'filtered';
  if new.route_match_status is distinct from 'not_requested' then
    new.route_match_status := 'pending';
  end if;

  -- The live snapshot contract has only these client observation fields.
  -- Never allow arbitrary keys (e.g. scientific reconciliation or server audit).
  snapshot := new.route_match_metrics_json;
  if jsonb_typeof(snapshot) = 'object' and snapshot->'live_snapshot' = 'true'::jsonb then
    new.route_match_metrics_json := jsonb_strip_nulls(jsonb_build_object(
      'live_snapshot', true,
      'route_segment_count', snapshot->'route_segment_count',
      'route_point_count', snapshot->'route_point_count',
      'last_gps_gap_duration_sec', snapshot->'last_gps_gap_duration_sec',
      'is_gps_signal_weak', snapshot->'is_gps_signal_weak',
      'snapshot_synced_at', snapshot->'snapshot_synced_at'));
  else
    new.route_match_metrics_json := '{}'::jsonb;
  end if;
  return new;
end;
$$;
drop trigger if exists guard_scientific_workout_retry on public.workout_sessions;
create trigger guard_scientific_workout_retry
before insert or update on public.workout_sessions
for each row execute function public.guard_scientific_workout_retry();

-- Enqueue remains a direct mobile INSERT. Server-only fields are initialized
-- in the database, including fields introduced by the dispatcher migration.
create or replace function public.guard_client_workout_job()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user = 'authenticated' or auth.role() = 'authenticated' then
    if new.job_type not in ('deterministic_finalize', 'route_correction_finalize') then
      raise check_violation using message = 'Unsupported workout job type';
    end if;
    new.status := 'queued';
    new.attempt_count := 0;
    new.started_at := null;
    new.finished_at := null;
    new.error_message := null;
    new.created_at := now();
    new.dispatch_attempt_count := 0;
    new.dispatch_after := now();
    new.last_dispatch_request_id := null;
    new.dispatch_nonce := null;
  end if;
  return new;
end;
$$;
create trigger guard_client_workout_job before insert on public.workout_processing_jobs
for each row execute function public.guard_client_workout_job();

drop policy if exists "workout_processing_jobs: update own" on public.workout_processing_jobs;
drop policy if exists "workout_processing_jobs: delete own" on public.workout_processing_jobs;
revoke update, delete on public.workout_processing_jobs from public, anon, authenticated;

-- Preserve existing logs without retroactively asserting their provenance.
alter table public.workout_processing_logs add column source text not null
  default 'legacy_unverified' check (source in ('legacy_unverified', 'client', 'server'));
alter table public.workout_processing_logs alter column source set default 'server';

create or replace function public.guard_client_workout_log()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user = 'authenticated' or auth.role() = 'authenticated' then
    new.source := 'client';
    new.created_at := now();
    if new.event_type not in ('client_finish_enqueued', 'client_finish_enqueue_skipped_existing',
      'client_route_correction_enqueued', 'client_route_correction_enqueue_skipped_existing',
      'gps_stream_error', 'gps_stream_done', 'gps_stream_stalled',
      'gps_recovery_started', 'gps_recovery_succeeded', 'gps_recovery_failed',
      'edge_finish_enqueued') then
      raise check_violation using message = 'Unsupported client workout log event';
    end if;
  end if;
  if new.job_id is not null and not exists (
    select 1 from public.workout_processing_jobs j
    where j.id = new.job_id and j.workout_id = new.workout_id
  ) then
    raise check_violation using message = 'Workout log job does not belong to workout';
  end if;
  return new;
end;
$$;
create trigger guard_client_workout_log before insert on public.workout_processing_logs
for each row execute function public.guard_client_workout_log();

drop policy if exists "workout_processing_logs: update own" on public.workout_processing_logs;
drop policy if exists "workout_processing_logs: delete own" on public.workout_processing_logs;
revoke update, delete on public.workout_processing_logs from public, anon, authenticated;

-- Client deletion of a whole workout/account still cascades. Individual
-- evidence and server-produced audit rows cannot be selectively removed.
drop policy if exists "workout_segment_audits: delete own" on public.workout_segment_audits;
revoke insert, update, delete on public.workout_segment_audits from public, anon, authenticated;
drop policy if exists "raw_gps_points: delete own" on public.raw_gps_points;
drop policy if exists "raw_step_intervals: delete own" on public.raw_step_intervals;

comment on column public.workout_processing_logs.source is
  'Server-assigned provenance. Historical rows were not retrospectively authenticated.';
