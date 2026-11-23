-- A finalized route must not look pending solely because its trace has ten
-- points. The client enqueues correction independently and the current
-- route-correction worker has no verified matching adapter.
-- Preserve actual active jobs and historical matching/research evidence.
create or replace function public.normalize_finalized_route_pending()
returns trigger language plpgsql set search_path = '' as $$
declare
  point_count bigint;
  lifecycle_reason text;
begin
  if current_user = 'authenticated' or auth.role() = 'authenticated' then
    return new;
  end if;
  if new.ended_at is null or new.processing_status <> 'client_finalized'
     or new.route_match_status <> 'pending'
     or new.route_distance_source <> 'filtered'
     or new.matched_route_json is distinct from '[]'::jsonb
     or new.matched_distance_km is not null
     or coalesce(new.route_match_confidence, 0) <> 0 then
    return new;
  end if;
  if exists (select 1 from public.workout_processing_jobs j
    where j.workout_id = new.id and j.job_type = 'route_correction_finalize'
      and j.status in ('queued', 'running')) then
    return new;
  end if;

  if new.client_research_result_json is not null
     or new.route_match_metrics_json ? 'client_scientific_reconciliation' then
    lifecycle_reason := 'scientific_archive_only';
  else
    select count(*) into point_count
    from jsonb_array_elements(case when jsonb_typeof(new.filtered_route_json) = 'array'
      then new.filtered_route_json else '[]'::jsonb end) as segment(value)
    cross join lateral jsonb_array_elements(case when jsonb_typeof(segment.value) = 'array'
      then segment.value else '[]'::jsonb end) as point(value)
    where jsonb_typeof(point.value->'lat') = 'number'
      and jsonb_typeof(point.value->'lng') = 'number';
    if point_count < 10 or coalesce(new.distance_km, 0) < 0.15 then
      lifecycle_reason := 'insufficient_route_evidence';
    else
      lifecycle_reason := 'no_verified_route_matching_adapter';
    end if;
  end if;

  new.route_match_status := 'not_requested';
  -- Do not replace legacy non-object metadata or any existing scientific
  -- fields. This annotation is a lifecycle decision, not a matching result.
  if jsonb_typeof(new.route_match_metrics_json) = 'object' then
    new.route_match_metrics_json := new.route_match_metrics_json ||
      jsonb_build_object('route_lifecycle', jsonb_build_object(
        'reason', lifecycle_reason,
        'active_correction_job', false));
  end if;
  return new;
end;
$$;

drop trigger if exists normalize_finalized_route_pending on public.workout_sessions;
create trigger normalize_finalized_route_pending
before insert or update on public.workout_sessions
for each row execute function public.normalize_finalized_route_pending();

-- Repair the same unambiguous historical state through the shared guard.
-- No new job, matching confidence, geometry, distance or research result.
update public.workout_sessions s
set route_match_status = s.route_match_status
where s.ended_at is not null and s.processing_status = 'client_finalized'
  and s.route_match_status = 'pending' and s.route_distance_source = 'filtered'
  and s.matched_route_json = '[]'::jsonb and s.matched_distance_km is null
  and coalesce(s.route_match_confidence, 0) = 0
  and not exists (select 1 from public.workout_processing_jobs j
    where j.workout_id = s.id and j.job_type = 'route_correction_finalize'
      and j.status in ('queued', 'running'));
