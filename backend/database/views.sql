-- ================================================================
-- views.sql
-- Derived reporting views.
-- Run this after workouts.sql so public.workout_sessions already exists.
-- ================================================================

create or replace view public.v_user_stats with (security_invoker = true) as
select
  user_id,
  count(*) as total_sessions,
  coalesce(sum(duration_sec), 0) as total_duration_sec,
  coalesce(sum(distance_km), 0) as total_distance_km,
  coalesce(sum(calories_kcal), 0) as total_calories_kcal,
  coalesce(sum(steps), 0) as total_steps,
  coalesce(
    avg(avg_speed_kmh) filter (where avg_speed_kmh is not null),
    0
  ) as overall_avg_speed_kmh
from public.workout_sessions
group by user_id;

create or replace view public.v_weekly_stats with (security_invoker = true) as
select
  user_id,
  count(*) as sessions_this_week,
  coalesce(sum(duration_sec), 0) as duration_sec_week,
  coalesce(sum(distance_km), 0) as distance_km_week,
  coalesce(sum(calories_kcal), 0) as calories_week,
  coalesce(sum(steps), 0) as steps_week
from public.workout_sessions
where started_at >= (now() - interval '7 days')
group by user_id;

create or replace view public.v_monthly_sessions with (security_invoker = true) as
select
  user_id,
  date_trunc('month', started_at) as month,
  count(*) as sessions,
  coalesce(sum(distance_km), 0) as distance_km,
  coalesce(sum(calories_kcal), 0) as calories,
  coalesce(sum(duration_sec), 0) as duration_sec
from public.workout_sessions
group by user_id, date_trunc('month', started_at)
order by user_id, month desc;

revoke all on public.v_user_stats, public.v_weekly_stats, public.v_monthly_sessions from public, anon;
grant select on public.v_user_stats, public.v_weekly_stats, public.v_monthly_sessions to authenticated, service_role;

create or replace view public.v_workout_processing_status
with (security_invoker = true)
as
select
  sessions.id as workout_id,
  sessions.user_id,
  sessions.activity_type,
  sessions.mode,
  sessions.started_at,
  sessions.ended_at,
  sessions.processing_status,
  sessions.metrics_version,
  sessions.data_quality_score,
  sessions.route_match_status,
  sessions.route_match_confidence,
  sessions.route_distance_source,
  coalesce(raw_gps.point_count, 0) as raw_gps_point_count,
  coalesce(raw_steps.interval_count, 0) as raw_step_interval_count,
  coalesce(job_counts.queued_count, 0) as queued_job_count,
  coalesce(job_counts.running_count, 0) as running_job_count,
  coalesce(job_counts.failed_count, 0) as failed_job_count,
  deterministic_job.id as deterministic_job_id,
  deterministic_job.status as deterministic_job_status,
  deterministic_job.attempt_count as deterministic_attempt_count,
  deterministic_job.started_at as deterministic_started_at,
  deterministic_job.finished_at as deterministic_finished_at,
  deterministic_job.error_message as deterministic_error_message,
  route_job.id as route_job_id,
  route_job.status as route_job_status,
  route_job.attempt_count as route_attempt_count,
  route_job.started_at as route_started_at,
  route_job.finished_at as route_finished_at,
  route_job.error_message as route_error_message,
  latest_log.log_level as latest_log_level,
  latest_log.event_type as latest_log_event_type,
  latest_log.message as latest_log_message,
  latest_log.created_at as latest_log_created_at
from public.workout_sessions sessions
left join lateral (
  select count(*)::int as point_count
  from public.raw_gps_points points
  where points.workout_id = sessions.id
) raw_gps on true
left join lateral (
  select count(*)::int as interval_count
  from public.raw_step_intervals intervals
  where intervals.workout_id = sessions.id
) raw_steps on true
left join lateral (
  select
    count(*) filter (where jobs.status = 'queued')::int as queued_count,
    count(*) filter (where jobs.status = 'running')::int as running_count,
    count(*) filter (where jobs.status = 'failed')::int as failed_count
  from public.workout_processing_jobs jobs
  where jobs.workout_id = sessions.id
) job_counts on true
left join lateral (
  select jobs.*
  from public.workout_processing_jobs jobs
  where jobs.workout_id = sessions.id
    and jobs.job_type = 'deterministic_finalize'
  order by jobs.created_at desc
  limit 1
) deterministic_job on true
left join lateral (
  select jobs.*
  from public.workout_processing_jobs jobs
  where jobs.workout_id = sessions.id
    and jobs.job_type = 'route_correction_finalize'
  order by jobs.created_at desc
  limit 1
) route_job on true
left join lateral (
  select logs.log_level, logs.event_type, logs.message, logs.created_at
  from public.workout_processing_logs logs
  where logs.workout_id = sessions.id
  order by logs.created_at desc
  limit 1
) latest_log on true;

comment on view public.v_workout_processing_status is
  'One-row-per-workout operational view for processing jobs, raw tracking counts, finalization status, route matching status, and latest processing log.';
