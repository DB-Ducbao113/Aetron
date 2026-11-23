-- Observe interrupted cloud shells without inventing end times or scientific
-- metrics. The owner may recover a durable device checkpoint or discard it.
create or replace view public.v_interrupted_workout_sessions
with (security_invoker = true) as
select s.id as workout_id, s.user_id, s.activity_type, s.mode, s.started_at,
       activity.last_activity_at,
       gps.point_count as raw_gps_points,
       steps.interval_count as raw_step_intervals,
       case when gps.point_count > 0 or steps.interval_count > 0 or
         (case when jsonb_typeof(s.filtered_route_json) = 'array'
               then jsonb_array_length(s.filtered_route_json) > 0 else false end)
         then 'evidence_available' else 'no_cloud_evidence' end as recovery_state
from public.workout_sessions s
cross join lateral (
  select count(*) as point_count, max(p.timestamp) as last_sample_at
  from public.raw_gps_points p where p.workout_id = s.id
) gps
cross join lateral (
  select count(*) as interval_count, max(p.interval_end) as last_sample_at
  from public.raw_step_intervals p where p.workout_id = s.id
) steps
cross join lateral (
  select greatest(s.started_at, s.updated_at, gps.last_sample_at, steps.last_sample_at)
    as last_activity_at
) activity
where s.ended_at is null and s.processing_status = 'client_recording'
  and activity.last_activity_at < now() - interval '24 hours';

revoke all on public.v_interrupted_workout_sessions from public, anon;
grant select on public.v_interrupted_workout_sessions to authenticated, service_role;
comment on view public.v_interrupted_workout_sessions is
  'Open workout inactive for 24 hours by latest persisted activity; diagnostic only, no automatic finalization.';
