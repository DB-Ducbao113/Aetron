-- Client scientific output is stored independently from server validation.
alter table public.workout_sessions
  add column if not exists client_research_result_json jsonb;
alter table public.workout_sessions
  drop constraint if exists workout_sessions_route_match_status_check;
alter table public.workout_sessions
  add constraint workout_sessions_route_match_status_check check (
    route_match_status in (
      'pending', 'not_requested', 'matched_success_high_confidence',
      'matched_success_medium_confidence', 'partial_match',
      'match_failed_fallback_filtered', 'reconstructed_pchip',
      'reconstructed_linear'
    )
  );
comment on column public.workout_sessions.client_research_result_json is
  'Versioned unverified client scientific result; independent of server canonical audit.';

-- A delayed authenticated upsert/snapshot must not reset a completed scientific
-- artifact or server verdict. Service-role workers keep normal update access.
create or replace function public.guard_scientific_workout_retry()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.role() = 'authenticated' and
     (old.client_research_result_json is not null or
      (old.processing_status = 'client_finalized' and old.metrics_version >= 2)) then
    -- A late first scientific artifact may still be archived on a legacy
    -- server-finalized row, but cannot change its already published verdict.
    if old.client_research_result_json is null
       and new.client_research_result_json->>'session_id' = old.id::text
       and new.client_research_result_json->>'version' = '1' then
      old.client_research_result_json := new.client_research_result_json;
    end if;
    return old;
  end if;
  return new;
end;
$$;
drop trigger if exists guard_scientific_workout_retry on public.workout_sessions;
create trigger guard_scientific_workout_retry
before update on public.workout_sessions
for each row execute function public.guard_scientific_workout_retry();

-- Mobile retries must not enqueue another already-completed job. The
-- existing unique active-job index covers concurrent queued/running jobs.
create or replace function public.guard_completed_workout_job_retry()
returns trigger language plpgsql set search_path = '' as $$
begin
  if auth.role() = 'authenticated' and exists (
    select 1 from public.workout_processing_jobs
    where workout_id = new.workout_id and job_type = new.job_type
      and status = 'completed'
  ) then
    raise unique_violation using message = 'Completed workout job already exists';
  end if;
  return new;
end;
$$;
drop trigger if exists guard_completed_workout_job_retry on public.workout_processing_jobs;
create trigger guard_completed_workout_job_retry
before insert on public.workout_processing_jobs
for each row execute function public.guard_completed_workout_job_retry();
