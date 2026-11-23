// @deno-types="https://esm.sh/@supabase/supabase-js@2.105.1"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.1";
import { authorizedWorkoutDispatcher } from "../_shared/workout_dispatch_auth.ts";

import { compendiumDistanceMet } from "../_shared/compendium_met.ts";

type WorkoutRow = {
  id: string;
  user_id: string;
  activity_type: string;
  mode: string;
  started_at: string;
  ended_at: string | null;
  duration_sec: number | null;
  moving_time_sec: number | null;
  distance_km: number | null;
  avg_speed_kmh: number | null;
  calories_kcal: number | null;
  steps: number | null;
  // jsonb column written by the client's live route snapshot; used as a
  // fallback route when the worker has no raw GPS points to reprocess.
  filtered_route_json?: unknown;
  client_research_result_json?: unknown;
};

type ProcessingJobRow = {
  id: string;
  workout_id: string;
  attempt_count: number | null;
  dispatch_nonce: string;
};

type RawGpsPoint = {
  timestamp: string;
  latitude: number;
  longitude: number;
  altitude: number | null;
  speed: number | null;
  accuracy: number | null;
  heading: number | null;
  device_source: string | null;
};

type RawStepInterval = {
  interval_start: string;
  interval_end: string;
  steps_count: number;
};

type UserProfileRow = {
  weight_kg: number | null;
  gender: string | null;
};

type RoutePoint = {
  lat: number;
  lng: number;
  timestamp: string;
};

type DisplayRoutePoint = { lat: number; lng: number; timestamp?: string };

type CandidateSegment = {
  from: RoutePoint;
  to: RoutePoint;
  durationSec: number;
  distanceM: number;
};

type SegmentAuditRow = {
  segmentIndex: number;
  startedAt: string;
  endedAt: string;
  durationSec: number;
  distanceM: number;
  paceSecPerKm: number | null;
  avgSpeedKmh: number;
  maxSpeedKmh: number;
  avgAccuracyM: number | null;
  status: "valid" | "suspicious" | "invalid";
  reason: string;
  features: Record<string, unknown>;
};

type MovementLeg = CandidateSegment & {
  avgAccuracy: number;
  speedMs: number;
};

type CanonicalMetrics = {
  durationSec: number;
  movingTimeSec: number;
  distanceKm: number;
  avgSpeedKmh: number;
  caloriesKcal: number;
  steps: number;
  lapSplits: Array<{
    index: number;
    distanceKm: number;
    durationSeconds: number;
    paceMinPerKm: number;
  }>;
  filteredRouteJson: DisplayRoutePoint[][];
  reconstructedRouteJson?: DisplayRoutePoint[][];
  dataQualityScore: number;
  routeMatchStatus: string;
  routeDistanceSource: string;
  routeMatchMetricsJson: Record<string, unknown>;
  segmentAudits: SegmentAuditRow[];
  logSummary: Record<string, unknown>;
};

type SupabaseAdminClient = any;

const JOB_TYPE = "deterministic_finalize";
const METRICS_VERSION = 2;
const MAX_ATTEMPTS = 3;
const GAP_THRESHOLD_SEC = 5;
const HARD_GAP_THRESHOLD_SEC = 90;
const HIGH_ACCURACY_METERS = 20;
const POOR_ACCURACY_METERS = 50;
const MAX_ACCURACY_METERS = 100;
const MIN_SEGMENT_DISTANCE_M = 0.75;

const corsHeaders = {
  "Content-Type": "application/json",
};

if (import.meta.main) {
  Deno.serve(handleRequest);
}

async function handleRequest(req: Request): Promise<Response> {
  try {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
      Deno.env.get("AETRON_SERVICE_ROLE_KEY");
    const payload = await authorizedWorkoutDispatcher(
      req, "deterministic-finalize-worker", Deno.env.get("AETRON_WORKER_DISPATCH_SECRET"),
    );
    if (!payload) {
      return json({ error: "Unauthorized" }, 401);
    }
    if (!serviceRoleKey) return json({ error: "Worker unavailable" }, 503);

    const { workout_id: workoutId, job_id: jobId, dispatch_nonce: dispatchNonce } = payload;

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      serviceRoleKey,
    );

    const job = await fetchQueuedJob(supabase, { workoutId, jobId, dispatchNonce });
    if (!job) {
      return json({ status: "noop", reason: "job_not_found" });
    }

    const workout = await fetchWorkout(supabase, job.workout_id);
    if (!workout) {
      await failJob(supabase, job.id, "workout_not_found");
      return json({ status: "failed", reason: "workout_not_found" }, 404);
    }
    if (!workout.ended_at) {
      return json({ status: "deferred", reason: "workout_not_finished" });
    }
    if (!await markJobStarted(supabase, job)) {
      return json({ status: "noop", reason: "job_already_claimed" });
    }

    const [rawGpsPoints, rawStepIntervals, userProfile] = await Promise.all([
      fetchRawGpsPoints(supabase, workout.id),
      fetchRawStepIntervals(supabase, workout.id),
      fetchUserProfile(supabase, workout.user_id),
    ]);
    const incompleteReason = incompleteRawEvidence(
      workout,
      rawGpsPoints,
      rawStepIntervals,
    );
    if (incompleteReason) {
      const exhausted = Number(job.attempt_count ?? 0) + 1 >= MAX_ATTEMPTS;
      const { error } = await supabase.from("workout_processing_jobs")
        .update({
          status: exhausted ? "failed" : "queued",
          started_at: null,
          finished_at: exhausted ? new Date().toISOString() : null,
          error_message: incompleteReason,
        })
        .eq("id", job.id).eq("status", "running");
      if (error) throw error;
      return json({
        status: exhausted ? "failed" : "deferred",
        reason: incompleteReason,
      });
    }

    const metrics = computeCanonicalMetrics({
      workout,
      rawGpsPoints,
      rawStepIntervals,
      userProfile,
      clientFilteredRoute: workout.filtered_route_json,
    });

    await persistSegmentAudits(supabase, workout.id, metrics.segmentAudits);
    await insertLog(
      supabase,
      workout.id,
      job.id,
      "info",
      "deterministic_finalize_completed",
      "Server validation and metric reconciliation completed.",
      metrics.logSummary,
    );
    // Publish finalized status only after dependent audit evidence exists.
    await persistMetrics(supabase, workout.id, metrics);
    await completeJob(supabase, job.id);

    return json({
      status: "completed",
      workout_id: workout.id,
      job_id: job.id,
      metrics: metrics.logSummary,
    });
  } catch (error) {
    console.error("[deterministic-finalize-worker] fatal error", error);
    return json(
      {
        error: error instanceof Error ? error.message : "Internal error",
      },
      500,
    );
  }
}

async function fetchQueuedJob(
  supabase: SupabaseAdminClient,
  input: { workoutId: string; jobId: string; dispatchNonce: string },
): Promise<ProcessingJobRow | null> {
  const query = supabase
    .from("workout_processing_jobs")
    .select("id, workout_id, attempt_count, dispatch_nonce")
    .eq("job_type", JOB_TYPE)
    .eq("status", "queued")
    .eq("id", input.jobId)
    .eq("workout_id", input.workoutId)
    .eq("dispatch_nonce", input.dispatchNonce)
    .lt("attempt_count", MAX_ATTEMPTS)
    .order("created_at", { ascending: true })
    .limit(1);

  const { data, error } = await query.maybeSingle();
  if (error) throw error;
  return data;
}

async function fetchWorkout(
  supabase: SupabaseAdminClient,
  workoutId: string,
): Promise<WorkoutRow | null> {
  const { data, error } = await supabase
    .from("workout_sessions")
    .select(
      "id, user_id, activity_type, mode, started_at, ended_at, duration_sec, moving_time_sec, distance_km, avg_speed_kmh, calories_kcal, steps, filtered_route_json, client_research_result_json",
    )
    .eq("id", workoutId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

// PostgREST's default row cap is not a complete workout. Stable pagination
// prevents treating an arbitrarily truncated route as a full raw audit.
export async function collectRawPages<T>(
  loadPage: (from: number, to: number) => Promise<T[]>,
  pageSize = 500,
): Promise<T[]> {
  const rows: T[] = [];
  for (let from = 0;; from += pageSize) {
    const page = await loadPage(from, from + pageSize - 1);
    rows.push(...page);
    if (page.length < pageSize) return rows;
  }
}

async function fetchRawGpsPoints(
  supabase: SupabaseAdminClient,
  workoutId: string,
): Promise<RawGpsPoint[]> {
  return collectRawPages<RawGpsPoint>(async (from, to) => {
    const { data, error } = await supabase
      .from("raw_gps_points")
      .select(
        "timestamp, latitude, longitude, altitude, speed, accuracy, heading, device_source",
      )
      .eq("workout_id", workoutId)
      .order("timestamp", { ascending: true })
      .order("id", { ascending: true })
      .range(from, to);
    if (error) throw error;
    return data ?? [];
  });
}

async function fetchRawStepIntervals(
  supabase: SupabaseAdminClient,
  workoutId: string,
): Promise<RawStepInterval[]> {
  return collectRawPages<RawStepInterval>(async (from, to) => {
    const { data, error } = await supabase
      .from("raw_step_intervals")
      .select("interval_start, interval_end, steps_count")
      .eq("workout_id", workoutId)
      .order("interval_start", { ascending: true })
      .order("id", { ascending: true })
      .range(from, to);
    if (error) throw error;
    return data ?? [];
  });
}

async function fetchUserProfile(
  supabase: SupabaseAdminClient,
  userId: string,
): Promise<UserProfileRow | null> {
  const { data, error } = await supabase
    .from("user_profiles")
    .select("weight_kg, gender")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function markJobStarted(
  supabase: SupabaseAdminClient,
  job: ProcessingJobRow,
): Promise<boolean> {
  const { data, error } = await supabase
    .from("workout_processing_jobs")
    .update({
      status: "running",
      started_at: new Date().toISOString(),
      attempt_count: Number(job.attempt_count ?? 0) + 1,
      dispatch_nonce: null,
      finished_at: null,
      error_message: null,
    })
    .eq("id", job.id)
    .eq("status", "queued")
    .eq("attempt_count", Number(job.attempt_count ?? 0))
    .eq("dispatch_nonce", job.dispatch_nonce)
    .select("id").maybeSingle();
  if (error) throw error;
  return data != null;
}

async function completeJob(
  supabase: SupabaseAdminClient,
  jobId: string,
) {
  const { error } = await supabase
    .from("workout_processing_jobs")
    .update({
      status: "completed",
      finished_at: new Date().toISOString(),
      error_message: null,
    })
    .eq("id", jobId);
  if (error) throw error;
}

async function failJob(
  supabase: SupabaseAdminClient,
  jobId: string,
  errorMessage: string,
) {
  const { error } = await supabase
    .from("workout_processing_jobs")
    .update({
      status: "failed",
      finished_at: new Date().toISOString(),
      error_message: errorMessage,
    })
    .eq("id", jobId);
  if (error) throw error;
}

async function persistMetrics(
  supabase: SupabaseAdminClient,
  workoutId: string,
  metrics: CanonicalMetrics,
) {
  const update: Record<string, unknown> = {
    duration_sec: metrics.durationSec,
    moving_time_sec: metrics.movingTimeSec,
    distance_km: metrics.distanceKm,
    avg_speed_kmh: metrics.avgSpeedKmh,
    calories_kcal: metrics.caloriesKcal,
    steps: metrics.steps,
    lap_splits: metrics.lapSplits,
    processing_status: "client_finalized",
    data_quality_score: metrics.dataQualityScore,
    metrics_version: METRICS_VERSION,
  };
  // Never clobber a client live-snapshot route with an empty recompute:
  // route fields are only written when this run actually produced a route.
  {
    update.filtered_route_json = metrics.filteredRouteJson;
    update.route_match_status = metrics.routeMatchStatus;
    update.route_distance_source = metrics.routeDistanceSource;
    update.route_match_metrics_json = metrics.routeMatchMetricsJson;
    // A fresh deterministic audit invalidates an earlier matching verdict.
    // Unreplayed P03 geometry remains exclusively in the client artifact.
    update.matched_route_json = [];
    update.matched_distance_km = null;
    update.route_match_confidence = null;
  }
  const { error } = await supabase
    .from("workout_sessions")
    .update(update)
    .eq("id", workoutId);
  if (error) throw error;
}

async function insertLog(
  supabase: SupabaseAdminClient,
  workoutId: string,
  jobId: string,
  logLevel: string,
  eventType: string,
  message: string,
  payload: Record<string, unknown>,
) {
  const { error } = await supabase
    .from("workout_processing_logs")
    .insert({
      workout_id: workoutId,
      job_id: jobId,
      log_level: logLevel,
      event_type: eventType,
      message,
      payload,
    });
  if (error) throw error;
}

async function persistSegmentAudits(
  supabase: SupabaseAdminClient,
  workoutId: string,
  segmentAudits: SegmentAuditRow[],
) {
  const { error: deleteError } = await supabase
    .from("workout_segment_audits")
    .delete()
    .eq("workout_id", workoutId);
  if (deleteError) throw deleteError;

  if (segmentAudits.length === 0) return;

  const rows = segmentAudits.map((audit) => ({
    workout_id: workoutId,
    segment_index: audit.segmentIndex,
    started_at: audit.startedAt,
    ended_at: audit.endedAt,
    duration_sec: audit.durationSec,
    distance_m: audit.distanceM,
    pace_sec_per_km: audit.paceSecPerKm,
    avg_speed_kmh: audit.avgSpeedKmh,
    max_speed_kmh: audit.maxSpeedKmh,
    avg_accuracy_m: audit.avgAccuracyM,
    status: audit.status,
    reason: audit.reason,
    features: audit.features,
  }));

  const { error } = await supabase.from("workout_segment_audits").insert(rows);
  if (error) throw error;
}

/// Parses the client's live-snapshot route (jsonb array or JSON string of
/// segments) into RoutePoint[][]. Returns [] for anything malformed.
export function parseClientRoute(raw: unknown): DisplayRoutePoint[][] {
  try {
    const parsed = typeof raw === "string" ? JSON.parse(raw) : raw;
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter(Array.isArray)
      .map((segment) =>
        segment
          .filter(
            (point: unknown) =>
              typeof point === "object" && point !== null &&
              typeof (point as Record<string, unknown>).lat === "number" &&
              typeof (point as Record<string, unknown>).lng === "number" &&
              Number.isFinite((point as Record<string, unknown>).lat) &&
              Number.isFinite((point as Record<string, unknown>).lng) &&
              Math.abs((point as Record<string, number>).lat) <= 90 &&
              Math.abs((point as Record<string, number>).lng) <= 180,
          )
          .map((point: Record<string, unknown>) => ({
            lat: point.lat as number,
            lng: point.lng as number,
            ...(typeof point.timestamp === "string" &&
                Number.isFinite(Date.parse(point.timestamp))
              ? { timestamp: point.timestamp }
              : {}),
          }))
      )
      .filter((segment) => segment.length > 0);
  } catch (_) {
    return [];
  }
}

export function computeCanonicalMetrics(input: {
  workout: WorkoutRow;
  rawGpsPoints: RawGpsPoint[];
  rawStepIntervals: RawStepInterval[];
  userProfile: UserProfileRow | null;
  clientFilteredRoute?: unknown;
}): CanonicalMetrics {
  const durationSec = resolveDurationSec(input.workout, input.rawGpsPoints);
  const stepCount = input.workout.activity_type.toLowerCase() === "cycling"
    ? 0
    : resolveSteps(input.rawStepIntervals, input.workout.steps);

  const declaredAudit = objectRecord(
    objectRecord(input.workout.client_research_result_json)?.audit,
  );
  const hasScientificGps = input.workout.client_research_result_json != null &&
    (input.rawGpsPoints.length > 0 ||
      declaredAudit?.distance_selection_policy ===
        "segmented_gps_plus_step_distance");
  if (
    input.workout.mode === "indoor" && !hasScientificGps &&
    declaredAudit?.distance_selection_policy !== "live_step_distance_only"
  ) {
    const indoorDistanceKm = sanitizeNonNegative(input.workout.distance_km);
    const indoorAvgSpeedKmh = durationSec > 0
      ? round2(indoorDistanceKm / (durationSec / 3600))
      : 0;
    const indoorMovingTimeSec = resolveMovingTimeSec({
      persistedMovingTimeSec: input.workout.moving_time_sec,
      durationSec,
      mode: input.workout.mode,
      restDurationSec: 0,
    });
    const indoorCaloriesKcal = resolveCaloriesKcal({
      activityType: input.workout.activity_type,
      weightKg: input.userProfile?.weight_kg ?? null,
      distanceKm: indoorDistanceKm,
      activeSeconds: indoorMovingTimeSec,
      fallbackCalories: input.workout.calories_kcal,
    });
    return {
      durationSec,
      movingTimeSec: indoorMovingTimeSec,
      distanceKm: indoorDistanceKm,
      avgSpeedKmh: indoorAvgSpeedKmh,
      caloriesKcal: indoorCaloriesKcal,
      steps: stepCount,
      lapSplits: [],
      filteredRouteJson: [],
      dataQualityScore: round2(stepCount > 0 ? 92 : 72),
      routeMatchStatus: "not_requested",
      routeDistanceSource: "filtered",
      segmentAudits: [],
      routeMatchMetricsJson: {
        mode: "indoor",
        workout_validity_status: "unverified",
        distance_provenance: "client_reported_indoor_unreplayed",
        ...(input.workout.client_research_result_json != null
          ? {
            client_scientific_reconciliation: {
              version: 1,
              selected: false,
              reason: "indoor_client_distance_unreplayed",
              exact_replay: false,
            },
          }
          : {}),
        rawGpsPointCount: input.rawGpsPoints.length,
        rawStepIntervalCount: input.rawStepIntervals.length,
      },
      logSummary: {
        mode: "indoor",
        workoutValidityStatus: "unverified",
        ...(input.workout.client_research_result_json != null
          ? {
            client_scientific_reconciliation: {
              version: 1,
              selected: false,
              reason: "indoor_client_distance_unreplayed",
              exact_replay: false,
            },
          }
          : {}),
        durationSec,
        movingTimeSec: indoorMovingTimeSec,
        distanceKm: indoorDistanceKm,
        steps: stepCount,
        rawGpsPointCount: input.rawGpsPoints.length,
        rawStepIntervalCount: input.rawStepIntervals.length,
      },
    };
  }

  const processedGps = processRawGpsPoints(
    input.rawGpsPoints,
    input.workout.activity_type,
  );
  const fallbackDistanceKm = sanitizeNonNegative(input.workout.distance_km);
  const distanceKm = input.workout.client_research_result_json != null
    ? processedGps.distanceKm
    : processedGps.distanceKm > 0 ||
        (input.rawGpsPoints.length >= 2 &&
          (processedGps.suspiciousSegmentCount > 0 ||
            processedGps.invalidSegmentCount > 0 ||
            processedGps.droppedSegmentCount > 0))
    ? processedGps.distanceKm
    : fallbackDistanceKm;
  const avgSpeedKmh = durationSec > 0
    ? round2(distanceKm / (durationSec / 3600))
    : 0;
  const lapSplits = buildLapSplits(processedGps.acceptedSegments);
  const movingTimeSec = resolveMovingTimeSec({
    persistedMovingTimeSec: input.workout.moving_time_sec,
    durationSec,
    mode: input.workout.mode,
    restDurationSec: processedGps.restDurationSec,
  });
  const caloriesKcal = resolveCaloriesKcal({
    activityType: input.workout.activity_type,
    weightKg: input.userProfile?.weight_kg ?? null,
    distanceKm,
    activeSeconds: movingTimeSec,
    fallbackCalories: input.workout.calories_kcal,
  });
  const dataQualityScore = computeDataQualityScore({
    rawPointCount: input.rawGpsPoints.length,
    acceptedPointCount: processedGps.acceptedPointCount,
    suspiciousSegmentCount: processedGps.suspiciousSegmentCount,
    droppedSegmentCount: processedGps.droppedSegmentCount,
    invalidSegmentCount: processedGps.invalidSegmentCount,
    gpsGapCount: processedGps.gpsGapCount,
    poorAccuracyPointCount: processedGps.poorAccuracyPointCount,
  });

  // When the worker had no raw GPS to process at all (e.g. web sessions,
  // where raw points are not buffered locally and never reach
  // raw_gps_points), keep the client's live-snapshot route instead of
  // overwriting it with an empty recompute. The fallback must never apply
  // when raw points exist: an empty worker route then means the points were
  // filtered out (e.g. suspicious movement) and the server verdict wins.
  const workerRoute = processedGps.filteredRoute;
  const hasWorkerRoute = workerRoute.flat().length > 0;
  const fallbackRoute = !hasWorkerRoute && input.rawGpsPoints.length === 0 &&
      input.workout.client_research_result_json == null
    ? parseClientRoute(input.clientFilteredRoute)
    : [];
  const effectiveRoute = hasWorkerRoute ? workerRoute : fallbackRoute;
  const routeSource = hasWorkerRoute
    ? "raw_gps"
    : fallbackRoute.length > 0
    ? "client_fallback"
    : "none";

  return reconcileClientResearch(input, {
    durationSec,
    movingTimeSec,
    distanceKm,
    avgSpeedKmh,
    caloriesKcal,
    steps: stepCount,
    lapSplits,
    filteredRouteJson: effectiveRoute,
    dataQualityScore,
    routeMatchStatus: effectiveRoute.flat().length >= 10
      ? "pending"
      : "not_requested",
    routeDistanceSource: "filtered",
    segmentAudits: processedGps.segmentAudits,
    routeMatchMetricsJson: {
      route_source: routeSource,
      gps_gap_count: processedGps.gpsGapCount,
      gps_gap_duration_sec: processedGps.gpsGapDurationSec,
      accepted_point_count: processedGps.acceptedPointCount,
      suspicious_segment_count: processedGps.suspiciousSegmentCount,
      dropped_segment_count: processedGps.droppedSegmentCount,
      invalid_segment_count: processedGps.invalidSegmentCount,
      valid_distance_km: processedGps.distanceKm,
      suspicious_distance_km: processedGps.suspiciousDistanceKm,
      invalid_distance_km: processedGps.invalidDistanceKm,
      suspicious_distance_ratio: processedGps.suspiciousDistanceRatio,
      workout_validity_status:
        !hasWorkerRoute || processedGps.droppedSegmentCount > 0 ||
          processedGps.invalidSegmentCount > 0 ||
          processedGps.suspiciousDistanceRatio > 0.3
          ? "unverified"
          : processedGps.suspiciousDistanceRatio > 0.1
          ? "partial"
          : "verified",
      rest_after_fast_duration_sec: processedGps.restAfterFastDurationSec,
      max_segment_speed_kmh: processedGps.maxSegmentSpeedKmh,
      median_segment_speed_kmh: processedGps.medianSegmentSpeedKmh,
      poor_accuracy_point_count: processedGps.poorAccuracyPointCount,
      recovery_break_count: processedGps.recoveryBreakCount,
      raw_gps_point_count: input.rawGpsPoints.length,
      finalized_by: JOB_TYPE,
      finalized_metrics_version: METRICS_VERSION,
    },
    logSummary: {
      mode: input.workout.mode,
      durationSec,
      movingTimeSec,
      distanceKm,
      avgSpeedKmh,
      caloriesKcal,
      steps: stepCount,
      rawGpsPointCount: input.rawGpsPoints.length,
      acceptedPointCount: processedGps.acceptedPointCount,
      suspiciousSegmentCount: processedGps.suspiciousSegmentCount,
      droppedSegmentCount: processedGps.droppedSegmentCount,
      invalidSegmentCount: processedGps.invalidSegmentCount,
      validDistanceKm: processedGps.distanceKm,
      suspiciousDistanceKm: processedGps.suspiciousDistanceKm,
      invalidDistanceKm: processedGps.invalidDistanceKm,
      suspiciousDistanceRatio: processedGps.suspiciousDistanceRatio,
      workoutValidityStatus:
        !hasWorkerRoute || processedGps.droppedSegmentCount > 0 ||
          processedGps.invalidSegmentCount > 0 ||
          processedGps.suspiciousDistanceRatio > 0.3
          ? "unverified"
          : processedGps.suspiciousDistanceRatio > 0.1
          ? "partial"
          : "verified",
      restAfterFastDurationSec: processedGps.restAfterFastDurationSec,
      gpsGapCount: processedGps.gpsGapCount,
      gpsGapDurationSec: processedGps.gpsGapDurationSec,
      recoveryBreakCount: processedGps.recoveryBreakCount,
      dataQualityScore,
    },
  });
}

/**
 * Engineering reconciliation, NOT a server reproduction of P01/P02.
 * The client's claim is archived independently. Bounded AEKF and segmented
 * client-reported totals may be retained, with explicit non-replay
 * provenance. The raw audit is separate; P03 is archive only.
 */
function reconcileClientResearch(
  input: Parameters<typeof computeCanonicalMetrics>[0],
  raw: CanonicalMetrics,
): CanonicalMetrics {
  const claim = input.workout.client_research_result_json;
  if (claim == null) return raw;
  const record = objectRecord(claim);
  const audit = objectRecord(record?.audit);
  const mark = (reason: string, selected = false) => {
    const reconciliation = {
      version: 1,
      selected,
      reason,
      server_raw_distance_km: raw.distanceKm,
      server_raw_validity_status:
        raw.routeMatchMetricsJson.workout_validity_status,
      client_distance_km: typeof record?.distance_km === "number" &&
          Number.isFinite(record.distance_km)
        ? record.distance_km
        : null,
      exact_replay: false,
      client_distance_policy: audit?.distance_selection_policy ?? null,
      client_step_distance_m: audit?.step_distance_m ?? null,
      client_gps_live_distance_m: audit?.gps_live_distance_m ?? null,
      reconstruction_archived_only: true,
    };
    return {
      ...raw,
      reconstructedRouteJson: [],
      routeMatchStatus: "not_requested",
      routeMatchMetricsJson: {
        ...raw.routeMatchMetricsJson,
        client_scientific_reconciliation: reconciliation,
      },
      logSummary: {
        ...raw.logSummary,
        client_scientific_reconciliation: reconciliation,
      },
    };
  };
  if (
    !record || !audit || record.version !== 1 ||
    record.session_id !== input.workout.id ||
    record.activity_type !== input.workout.activity_type.toLowerCase() ||
    record.mode !== input.workout.mode ||
    audit.scientific_result_version !== 1
  ) {
    return mark("unsupported_client_contract");
  }
  const policy = audit.distance_selection_policy;
  if (
    policy === "segmented_gps_plus_step_distance" ||
    policy === "live_step_distance_only"
  ) {
    const stepDistance = audit.step_distance_m;
    const distance = record.distance_km;
    const rawSteps = resolveSteps(input.rawStepIntervals, 0);
    const activity = input.workout.activity_type.toLowerCase();
    const route = strictDisplayRoute(record.filtered_route);
    const stepOnly = policy === "live_step_distance_only";
    const gpsDistance = stepOnly ? 0 : route ? routeDistanceKm(route) : NaN;
    const tolerance = 0.001 + raw.distanceKm * 0.01;
    if (
      !["walking", "running"].includes(activity) ||
      !finitePositive(stepDistance) || !finitePositive(distance) ||
      !Number.isInteger(record.steps) || record.steps !== rawSteps ||
      rawSteps !== raw.steps || rawSteps <= 0 ||
      record.duration_sec !== raw.durationSec ||
      record.moving_time_sec !== raw.movingTimeSec ||
      raw.movingTimeSec <= 0 ||
      distance * 1000 / raw.movingTimeSec > maxExpectedSpeedMs(activity) ||
      audit.raw_gps_fix_count !== input.rawGpsPoints.length ||
      !Number.isFinite(gpsDistance) ||
      Math.abs(distance - gpsDistance - stepDistance / 1000) > tolerance ||
      (stepOnly && (route != null || raw.distanceKm > 0)) ||
      (!stepOnly && (!route || raw.distanceKm <= 0 ||
        gpsDistance > raw.distanceKm + tolerance ||
        raw.segmentAudits.some((segment) => segment.status !== "valid") ||
        raw.routeMatchMetricsJson.dropped_segment_count !== 0 ||
        !routeCorroboratedByRaw(
          route,
          input.rawGpsPoints,
          raw.filteredRouteJson,
        )))
    ) {
      return mark("mixed_or_step_claim_not_corroborated_archive_preserved");
    }
    // Keep the reported total, not a sum of all server GPS observations
    // and estimated steps: their time coverage may overlap. There is no
    // per-step length input or source timeline in this contract.
    const selected = mark(
      "client_reported_segmented_distance_unverified",
      true,
    );
    const avgSpeedKmh = round2(distance / (raw.durationSec / 3600));
    const caloriesKcal = resolveCaloriesKcal({
      activityType: activity,
      weightKg: input.userProfile?.weight_kg ?? null,
      distanceKm: distance,
      activeSeconds: raw.movingTimeSec,
      fallbackCalories: input.workout.calories_kcal,
    });
    return {
      ...selected,
      distanceKm: distance,
      avgSpeedKmh,
      caloriesKcal,
      // Keep server GPS audit geometry; client route stays archived.
      lapSplits: validClientLaps(record.lap_splits, distance, raw.durationSec),
      routeMatchStatus: "not_requested",
      routeMatchMetricsJson: {
        ...selected.routeMatchMetricsJson,
        distance_provenance: "client_reported_segmented_unverified",
        workout_validity_status: "unverified",
        step_distance_verified: false,
        source_interval_overlap_verified: false,
        lap_split_policy: "bounded_client_live_laps_not_replayed",
      },
      logSummary: {
        ...selected.logSummary,
        distanceKm: distance,
        avgSpeedKmh,
        caloriesKcal,
        workoutValidityStatus: "unverified",
      },
    };
  }
  if (
    audit.gps_algorithm !== "aekf_4state" ||
    policy !== "aekf_filtered_then_preprocessed_clean"
  ) {
    return mark("unsupported_client_contract");
  }
  if (
    input.rawGpsPoints.length < 2 ||
    audit.raw_gps_fix_count !== input.rawGpsPoints.length ||
    (audit.adaptive_step_count ?? 0) !== 0 ||
    (audit.step_distance_m ?? 0) !== 0
  ) {
    return mark("incomplete_or_mixed_runtime_observations");
  }
  if (
    raw.distanceKm <= 0 || raw.segmentAudits.length === 0 ||
    raw.segmentAudits.some((segment) => segment.status !== "valid") ||
    raw.routeMatchMetricsJson.dropped_segment_count !== 0
  ) {
    return mark("raw_audit_not_clean");
  }
  const route = strictDisplayRoute(record.filtered_route);
  const distance = record.distance_km;
  if (
    !route || typeof distance !== "number" || !Number.isFinite(distance) ||
    distance <= 0 || record.duration_sec !== raw.durationSec ||
    record.moving_time_sec !== raw.movingTimeSec ||
    record.steps !== raw.steps
  ) {
    return mark("inconsistent_client_metrics");
  }
  const routeDistance = routeDistanceKm(route);
  // 1% + 1m is a declared engineering tolerance for spherical/ellipsoidal
  // distance conventions and rounded server kilometres, not a paper threshold.
  const tolerance = 0.001 + raw.distanceKm * 0.01;
  if (
    Math.abs(routeDistance - distance) > tolerance ||
    distance > raw.distanceKm + tolerance ||
    raw.movingTimeSec <= 0 ||
    distance * 1000 / raw.movingTimeSec >
      maxExpectedSpeedMs(input.workout.activity_type)
  ) {
    return mark("distance_not_corroborated");
  }
  if (
    !routeCorroboratedByRaw(route, input.rawGpsPoints, raw.filteredRouteJson)
  ) {
    return mark("filtered_geometry_not_corroborated");
  }
  const selected = mark("bounded_client_aekf_with_raw_audit", true);
  // Preserve valid completed client live laps, but mark their timing as
  // client estimates: corrected geometry has no independently replayable times.
  const lapSplits = validClientLaps(
    record.lap_splits,
    distance,
    raw.durationSec,
  );
  const caloriesKcal = resolveCaloriesKcal({
    activityType: input.workout.activity_type,
    weightKg: input.userProfile?.weight_kg ?? null,
    distanceKm: distance,
    activeSeconds: raw.movingTimeSec,
    fallbackCalories: input.workout.calories_kcal,
  });
  const avgSpeedKmh = raw.durationSec > 0
    ? round2(distance / (raw.durationSec / 3600))
    : 0;
  return {
    ...selected,
    distanceKm: distance,
    avgSpeedKmh,
    caloriesKcal,
    lapSplits,
    filteredRouteJson: route,
    reconstructedRouteJson: [],
    routeMatchStatus: "not_requested",
    routeDistanceSource: "filtered",
    routeMatchMetricsJson: {
      ...selected.routeMatchMetricsJson,
      route_source: "client_aekf_bounded",
      distance_provenance: "bounded_client_aekf_unreplayed",
      workout_validity_status: "partial",
      lap_split_policy: "bounded_client_live_laps_not_replayed",
      reconstruction_display_only: false,
      reconstruction_archived_only: true,
    },
    logSummary: {
      ...selected.logSummary,
      distanceKm: distance,
      avgSpeedKmh,
      caloriesKcal,
      workoutValidityStatus: "partial",
    },
  };
}

function finitePositive(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value > 0;
}

function routeDistanceKm(route: DisplayRoutePoint[][]): number {
  return route.reduce(
    (sum, segment) =>
      sum +
      segment.slice(1).reduce(
        (legs, point, i) => legs + haversineMeters(segment[i], point),
        0,
      ),
    0,
  ) / 1000;
}

// A missing upload is not evidence of an empty workout. Use the existing
// scientific count and explicit step total, if present, to defer publication.
export function incompleteRawEvidence(
  workout: WorkoutRow,
  gps: RawGpsPoint[],
  steps: RawStepInterval[],
): string | null {
  const claim = objectRecord(workout.client_research_result_json);
  const audit = objectRecord(claim?.audit);
  if (
    !claim || !audit || claim.version !== 1 ||
    claim.session_id !== workout.id
  ) return null;
  const expectedGps = audit.raw_gps_fix_count;
  if (
    typeof expectedGps === "number" && Number.isSafeInteger(expectedGps) &&
    expectedGps > gps.length
  ) return "awaiting_raw_gps_upload";
  const expectedSteps = claim.steps;
  if (
    workout.activity_type.toLowerCase() !== "cycling" &&
    typeof expectedSteps === "number" && Number.isSafeInteger(expectedSteps) &&
    expectedSteps > resolveSteps(steps, 0)
  ) return "awaiting_raw_step_upload";
  return null;
}

function routeCorroboratedByRaw(
  route: DisplayRoutePoint[][],
  rawPoints: RawGpsPoint[],
  acceptedRoute: DisplayRoutePoint[][],
): boolean {
  const accuracyByTime = new Map(
    rawPoints.map((point) => [Date.parse(point.timestamp), point.accuracy]),
  );
  // Monotone consistency within each *accepted contiguous* raw segment.
  // No client segment may bridge gaps or rejected observations. A reported
  // accuracy radius is only a consistency check, not a confidence interval.
  let rawSegment = 0;
  let offset = 0;
  for (const segment of route) {
    let matched = false;
    for (; rawSegment < acceptedRoute.length; rawSegment++, offset = 0) {
      const raw = acceptedRoute[rawSegment];
      let index = offset;
      for (const point of segment) {
        while (index < raw.length) {
          const observed = raw[index];
          const accuracy = accuracyByTime.get(
            Date.parse(observed.timestamp ?? ""),
          );
          if (
            typeof accuracy === "number" && Number.isFinite(accuracy) &&
            accuracy > 0 && accuracy <= POOR_ACCURACY_METERS &&
            haversineMeters(point, observed) <= accuracy
          ) break;
          index++;
        }
        if (index >= raw.length) break;
      }
      if (index < raw.length) {
        matched = true;
        offset = index;
        break;
      }
    }
    if (!matched) return false;
  }
  return true;
}

function validClientLaps(
  value: unknown,
  distanceKm: number,
  durationSec: number,
): CanonicalMetrics["lapSplits"] {
  if (!Array.isArray(value)) return [];
  const result: CanonicalMetrics["lapSplits"] = [];
  let elapsed = 0;
  let totalDistance = 0;
  for (const item of value) {
    const lap = objectRecord(item);
    if (
      !lap || lap.index !== result.length + 1 ||
      typeof lap.distanceKm !== "number" || !Number.isFinite(lap.distanceKm) ||
      lap.distanceKm <= 0 || lap.distanceKm > 1 ||
      typeof lap.durationSeconds !== "number" ||
      !Number.isInteger(lap.durationSeconds) ||
      lap.durationSeconds <= 0
    ) break;
    if (
      totalDistance + lap.distanceKm > distanceKm + 1e-9 ||
      elapsed + lap.durationSeconds > durationSec
    ) break;
    elapsed += lap.durationSeconds;
    totalDistance += lap.distanceKm;
    result.push({
      index: result.length + 1,
      distanceKm: lap.distanceKm,
      durationSeconds: lap.durationSeconds,
      paceMinPerKm: lap.durationSeconds / 60 / lap.distanceKm,
    });
  }
  return result;
}

function objectRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function strictDisplayRoute(value: unknown): DisplayRoutePoint[][] | null {
  if (
    !Array.isArray(value) || value.length === 0 ||
    value.some((segment) => !Array.isArray(segment) || segment.length === 0)
  ) {
    return null;
  }
  const parsed = parseClientRoute(value);
  if (
    parsed.length !== value.length ||
    parsed.some((segment, index) => segment.length !== value[index].length) ||
    !parsed.some((segment) => segment.length >= 2)
  ) return null;
  return parsed;
}

function resolveDurationSec(
  workout: WorkoutRow,
  rawGpsPoints: RawGpsPoint[],
): number {
  if (typeof workout.duration_sec === "number" && workout.duration_sec >= 0) {
    return Math.round(workout.duration_sec);
  }

  if (workout.started_at && workout.ended_at) {
    const diffSec =
      (Date.parse(workout.ended_at) - Date.parse(workout.started_at)) / 1000;
    if (Number.isFinite(diffSec) && diffSec >= 0) {
      return Math.round(diffSec);
    }
  }

  if (rawGpsPoints.length >= 2) {
    const diffSec = (Date.parse(rawGpsPoints.at(-1)!.timestamp) -
      Date.parse(rawGpsPoints[0].timestamp)) / 1000;
    if (Number.isFinite(diffSec) && diffSec >= 0) {
      return Math.round(diffSec);
    }
  }

  return 0;
}

function resolveSteps(
  rawStepIntervals: RawStepInterval[],
  fallbackSteps: number | null,
): number {
  const rawSteps = rawStepIntervals.reduce((sum, interval) => {
    const safeSteps = Number(interval.steps_count);
    return sum + (Number.isFinite(safeSteps) && safeSteps > 0 ? safeSteps : 0);
  }, 0);
  if (rawSteps > 0) return rawSteps;
  return Math.max(0, Math.round(Number(fallbackSteps ?? 0)));
}

function resolveMovingTimeSec(input: {
  persistedMovingTimeSec: number | null;
  durationSec: number;
  mode: string;
  restDurationSec: number;
}): number {
  const persisted = Number(input.persistedMovingTimeSec ?? 0);
  if (
    input.persistedMovingTimeSec != null &&
    Number.isFinite(persisted) && persisted >= 0
  ) {
    return Math.max(0, Math.min(input.durationSec, Math.round(persisted)));
  }

  if (input.mode === "indoor") {
    return input.durationSec;
  }

  return Math.max(
    0,
    Math.min(
      input.durationSec,
      Math.round(input.durationSec - input.restDurationSec),
    ),
  );
}

function processRawGpsPoints(rawPoints: RawGpsPoint[], activityType: string) {
  const normalized = rawPoints
    .map((point) => ({
      timestamp: point.timestamp,
      latitude: Number(point.latitude),
      longitude: Number(point.longitude),
      accuracy: point.accuracy == null ? null : Number(point.accuracy),
      deviceSource: point.device_source,
    }))
    .filter((point) =>
      Number.isFinite(Date.parse(point.timestamp)) &&
      Number.isFinite(point.latitude) &&
      Number.isFinite(point.longitude) &&
      Math.abs(point.latitude) <= 90 &&
      Math.abs(point.longitude) <= 180
    )
    .sort((a, b) => Date.parse(a.timestamp) - Date.parse(b.timestamp));

  const deduped = normalized.filter((point, index, points) => {
    if (index === 0) return true;
    const prev = points[index - 1];
    return !(
      prev.timestamp === point.timestamp &&
      prev.latitude === point.latitude &&
      prev.longitude === point.longitude
    );
  });

  const maxSpeedMs = maxExpectedSpeedMs(activityType);
  const validLegs: MovementLeg[] = [];
  const filteredRoute: RoutePoint[][] = [];
  let acceptedPointCount = deduped.length > 0 ? 1 : 0;
  let suspiciousSegmentCount = 0;
  let invalidSegmentCount = 0;
  let droppedSegmentCount = 0;
  let poorAccuracyPointCount = 0;
  let gpsGapCount = 0;
  let gpsGapDurationSec = 0;
  let recoveryBreakCount = 0;
  let restDurationSec = 0;
  let validDistanceM = 0;
  let suspiciousDistanceM = 0;
  let invalidDistanceM = 0;
  let restAfterFastDurationSec = 0;
  let lastAuditWasFast = false;

  const rawLegs: MovementLeg[] = [];

  for (let i = 0; i < deduped.length; i += 1) {
    const point = deduped[i];
    if ((point.accuracy ?? 0) > POOR_ACCURACY_METERS) {
      poorAccuracyPointCount += 1;
    }

    const routePoint: RoutePoint = {
      lat: point.latitude,
      lng: point.longitude,
      timestamp: new Date(point.timestamp).toISOString(),
    };

    if (i === 0) continue;

    const prev = deduped[i - 1];
    const prevRoutePoint = {
      lat: prev.latitude,
      lng: prev.longitude,
      timestamp: new Date(prev.timestamp).toISOString(),
    };
    const durationSec =
      (Date.parse(point.timestamp) - Date.parse(prev.timestamp)) /
      1000;
    const distanceM = haversineMeters(
      { lat: prev.latitude, lng: prev.longitude },
      { lat: point.latitude, lng: point.longitude },
    );
    const avgAccuracy = averageNullable(prev.accuracy, point.accuracy);
    const speedMs = durationSec > 0
      ? distanceM / durationSec
      : Number.POSITIVE_INFINITY;
    const deviceRequestedBreak =
      (point.deviceSource ?? "").includes("recovery") ||
      (prev.deviceSource ?? "").includes("recovery");

    if (!Number.isFinite(durationSec) || durationSec <= 0) {
      droppedSegmentCount += 1;
      continue;
    }

    if (deviceRequestedBreak) {
      recoveryBreakCount += 1;
      acceptedPointCount += 1;
      continue;
    }

    if (durationSec > GAP_THRESHOLD_SEC) {
      gpsGapCount += 1;
      gpsGapDurationSec += Math.round(durationSec);
      acceptedPointCount += 1;
      continue;
    }

    if (distanceM < MIN_SEGMENT_DISTANCE_M && speedMs < 0.3) {
      restDurationSec += durationSec;
      acceptedPointCount += 1;
      rawLegs.push({
        from: prevRoutePoint,
        to: routePoint,
        durationSec,
        distanceM: 0,
        avgAccuracy,
        speedMs: 0,
      });
      continue;
    }

    if (
      durationSec > HARD_GAP_THRESHOLD_SEC ||
      avgAccuracy > MAX_ACCURACY_METERS ||
      distanceM < MIN_SEGMENT_DISTANCE_M ||
      speedMs > maxSpeedMs * 1.35
    ) {
      droppedSegmentCount += 1;
      acceptedPointCount += 1;
      continue;
    }

    if (distanceM < 1.0 || speedMs < 0.3) {
      restDurationSec += durationSec;
    }

    acceptedPointCount += 1;
    rawLegs.push({
      from: prevRoutePoint,
      to: routePoint,
      durationSec,
      distanceM,
      avgAccuracy,
      speedMs,
    });
  }

  const segmentAudits = buildSegmentAudits(rawLegs, activityType);
  for (const audit of segmentAudits) {
    const isIdleAudit = audit.avgSpeedKmh < 1 ||
      audit.reason === "stationary_or_too_short" ||
      audit.reason === "pace_too_slow";
    if (lastAuditWasFast && isIdleAudit) {
      restAfterFastDurationSec += audit.durationSec;
    }

    if (audit.status === "valid") {
      const segmentLegs = rawLegs.slice(
        Number(audit.features.start_leg_index ?? 0),
        Number(audit.features.end_leg_index ?? -1) + 1,
      );
      validLegs.push(...segmentLegs);
      validDistanceM += audit.distanceM;
      appendValidRouteSegment(filteredRoute, segmentLegs);
      lastAuditWasFast = false;
    } else if (audit.status === "suspicious") {
      suspiciousSegmentCount += 1;
      suspiciousDistanceM += audit.distanceM;
      lastAuditWasFast = audit.reason.includes("fast");
    } else {
      invalidSegmentCount += 1;
      invalidDistanceM += audit.distanceM;
      lastAuditWasFast = lastAuditWasFast && isIdleAudit;
    }
  }

  const speedSamplesKmh = segmentAudits
    .map((audit) => audit.avgSpeedKmh)
    .filter((value) => Number.isFinite(value) && value > 0)
    .sort((a, b) => a - b);
  const totalClassifiedDistanceM = validDistanceM + suspiciousDistanceM +
    invalidDistanceM;

  return {
    acceptedSegments: validLegs,
    filteredRoute,
    segmentAudits,
    distanceKm: round3(validDistanceM / 1000),
    suspiciousDistanceKm: round3(suspiciousDistanceM / 1000),
    invalidDistanceKm: round3(invalidDistanceM / 1000),
    suspiciousDistanceRatio: totalClassifiedDistanceM > 0
      ? round3(suspiciousDistanceM / totalClassifiedDistanceM)
      : 0,
    restDurationSec: Math.round(restDurationSec >= 60 ? restDurationSec : 0),
    restAfterFastDurationSec,
    acceptedPointCount,
    suspiciousSegmentCount,
    invalidSegmentCount,
    droppedSegmentCount,
    poorAccuracyPointCount,
    gpsGapCount,
    gpsGapDurationSec,
    recoveryBreakCount,
    maxSegmentSpeedKmh: speedSamplesKmh.length > 0
      ? round2(Math.max(...speedSamplesKmh))
      : 0,
    medianSegmentSpeedKmh: median(speedSamplesKmh),
  };
}

function buildSegmentAudits(
  legs: MovementLeg[],
  activityType: string,
): SegmentAuditRow[] {
  const audits: SegmentAuditRow[] = [];
  let bucket: MovementLeg[] = [];
  let bucketDistanceM = 0;
  let bucketDurationSec = 0;
  let bucketStartLegIndex = 0;

  for (let i = 0; i < legs.length; i += 1) {
    const leg = legs[i];
    if (
      bucket.length > 0 && bucket.at(-1)!.to.timestamp !== leg.from.timestamp
    ) {
      audits.push(classifySegmentAudit({
        legs: bucket,
        activityType,
        segmentIndex: audits.length,
        startLegIndex: bucketStartLegIndex,
        endLegIndex: i - 1,
      }));
      bucket = [];
      bucketDistanceM = 0;
      bucketDurationSec = 0;
    }
    if (bucket.length === 0) bucketStartLegIndex = i;

    bucket.push(leg);
    bucketDistanceM += leg.distanceM;
    bucketDurationSec += leg.durationSec;

    if (bucketDistanceM >= 100 || bucketDurationSec >= 30) {
      audits.push(classifySegmentAudit({
        legs: bucket,
        activityType,
        segmentIndex: audits.length,
        startLegIndex: bucketStartLegIndex,
        endLegIndex: i,
      }));
      bucket = [];
      bucketDistanceM = 0;
      bucketDurationSec = 0;
    }
  }

  if (bucket.length > 0) {
    audits.push(classifySegmentAudit({
      legs: bucket,
      activityType,
      segmentIndex: audits.length,
      startLegIndex: bucketStartLegIndex,
      endLegIndex: legs.length - 1,
    }));
  }

  return audits;
}

function classifySegmentAudit(input: {
  legs: MovementLeg[];
  activityType: string;
  segmentIndex: number;
  startLegIndex: number;
  endLegIndex: number;
}): SegmentAuditRow {
  const distanceM = input.legs.reduce((sum, leg) => sum + leg.distanceM, 0);
  const durationSec = input.legs.reduce((sum, leg) => sum + leg.durationSec, 0);
  const avgSpeedKmh = durationSec > 0 ? (distanceM / durationSec) * 3.6 : 0;
  const maxSpeedKmh = input.legs.reduce(
    (max, leg) => Math.max(max, leg.speedMs * 3.6),
    0,
  );
  const avgAccuracyM = averageNumbers(input.legs.map((leg) => leg.avgAccuracy));
  const paceSecPerKm = distanceM > 0 ? durationSec / (distanceM / 1000) : null;
  const thresholds = segmentThresholdForActivity(input.activityType);
  let status: "valid" | "suspicious" | "invalid" = "valid";
  let reason = "valid";

  if (distanceM < MIN_SEGMENT_DISTANCE_M) {
    status = "invalid";
    reason = "stationary_or_too_short";
  } else if ((avgAccuracyM ?? 0) > MAX_ACCURACY_METERS) {
    status = "invalid";
    reason = "low_gps_accuracy";
  } else if (
    paceSecPerKm != null && paceSecPerKm < thresholds.minPaceSecPerKm
  ) {
    status = "suspicious";
    reason = input.activityType.toLowerCase() === "cycling"
      ? "suspicious_fast_for_cycling"
      : "pace_too_fast";
  } else if (maxSpeedKmh > thresholds.maxSpeedKmh) {
    status = "suspicious";
    reason = input.activityType.toLowerCase() === "cycling"
      ? "suspicious_fast_for_cycling"
      : "speed_too_fast";
  } else if (
    paceSecPerKm != null && paceSecPerKm > thresholds.maxPaceSecPerKm
  ) {
    status = "invalid";
    reason = "pace_too_slow";
  }

  const first = input.legs[0];
  const last = input.legs.at(-1)!;
  return {
    segmentIndex: input.segmentIndex,
    startedAt: first.from.timestamp,
    endedAt: last.to.timestamp,
    durationSec: Math.max(0, Math.round(durationSec)),
    distanceM: round2(distanceM),
    paceSecPerKm: paceSecPerKm == null ? null : round2(paceSecPerKm),
    avgSpeedKmh: round2(avgSpeedKmh),
    maxSpeedKmh: round2(maxSpeedKmh),
    avgAccuracyM: avgAccuracyM == null ? null : round2(avgAccuracyM),
    status,
    reason,
    features: {
      activity_type: input.activityType,
      start_leg_index: input.startLegIndex,
      end_leg_index: input.endLegIndex,
      leg_count: input.legs.length,
      min_pace_sec_per_km: thresholds.minPaceSecPerKm,
      max_pace_sec_per_km: thresholds.maxPaceSecPerKm,
      max_speed_kmh_threshold: thresholds.maxSpeedKmh,
    },
  };
}

function segmentThresholdForActivity(activityType: string) {
  switch (activityType.toLowerCase()) {
    case "cycling":
      return {
        minPaceSecPerKm: 180,
        maxPaceSecPerKm: 900,
        maxSpeedKmh: 20,
      };
    case "walking":
      return {
        minPaceSecPerKm: 300,
        maxPaceSecPerKm: 1800,
        maxSpeedKmh: 9,
      };
    case "hiking":
      return {
        minPaceSecPerKm: 240,
        maxPaceSecPerKm: 2400,
        maxSpeedKmh: 12,
      };
    case "running":
    default:
      return {
        minPaceSecPerKm: 150,
        maxPaceSecPerKm: 720,
        maxSpeedKmh: 24,
      };
  }
}

function appendValidRouteSegment(
  filteredRoute: RoutePoint[][],
  legs: MovementLeg[],
) {
  if (legs.length === 0) return;
  const route = [legs[0].from, ...legs.map((leg) => leg.to)];
  const previous = filteredRoute.at(-1);
  if (previous?.at(-1)?.timestamp === route[0].timestamp) {
    previous!.push(...route.slice(1));
  } else if (route.length >= 2) filteredRoute.push(route);
}

function buildLapSplits(segments: CandidateSegment[]) {
  const splits: Array<{
    index: number;
    distanceKm: number;
    durationSeconds: number;
    paceMinPerKm: number;
  }> = [];
  let cumulativeDistanceM = 0;
  let cumulativeDurationSec = 0;
  let splitStartDistanceM = 0;
  let splitStartDurationSec = 0;
  let nextLapBoundaryM = 1000;
  let lapIndex = 1;

  for (const segment of segments) {
    cumulativeDistanceM += segment.distanceM;
    cumulativeDurationSec += segment.durationSec;

    while (cumulativeDistanceM >= nextLapBoundaryM) {
      const lapDurationSec = Math.max(
        1,
        Math.round(cumulativeDurationSec - splitStartDurationSec),
      );
      splits.push({
        index: lapIndex,
        distanceKm: 1,
        durationSeconds: lapDurationSec,
        paceMinPerKm: round2(lapDurationSec / 60),
      });
      splitStartDistanceM = nextLapBoundaryM;
      splitStartDurationSec = cumulativeDurationSec;
      nextLapBoundaryM += 1000;
      lapIndex += 1;
    }
  }

  const trailingDistanceKm = (cumulativeDistanceM - splitStartDistanceM) / 1000;
  const trailingDurationSec = cumulativeDurationSec - splitStartDurationSec;
  if (trailingDistanceKm >= 0.25 && trailingDurationSec > 0) {
    splits.push({
      index: lapIndex,
      distanceKm: round2(trailingDistanceKm),
      durationSeconds: Math.round(trailingDurationSec),
      paceMinPerKm: round2((trailingDurationSec / 60) / trailingDistanceKm),
    });
  }

  return splits;
}

function computeDataQualityScore(input: {
  rawPointCount: number;
  acceptedPointCount: number;
  suspiciousSegmentCount: number;
  droppedSegmentCount: number;
  invalidSegmentCount: number;
  gpsGapCount: number;
  poorAccuracyPointCount: number;
}): number {
  if (input.rawPointCount === 0) return 35;

  const acceptanceRatio = input.acceptedPointCount / input.rawPointCount;
  let score = 100;
  score -= (1 - acceptanceRatio) * 35;
  score -= input.suspiciousSegmentCount * 3.5;
  score -= input.droppedSegmentCount * 4.5;
  score -= input.invalidSegmentCount * 6.5;
  score -= input.gpsGapCount * 6;
  score -= (input.poorAccuracyPointCount / input.rawPointCount) * 15;
  return round2(Math.max(0, Math.min(100, score)));
}

function resolveCaloriesKcal(input: {
  activityType: string;
  weightKg: number | null;
  distanceKm: number;
  activeSeconds: number;
  fallbackCalories: number | null;
}): number {
  const distanceKm = sanitizeNonNegative(input.distanceKm);
  const speedKmh = input.activeSeconds > 0
    ? distanceKm / (input.activeSeconds / 3600)
    : 0;
  const entry = compendiumDistanceMet(input.activityType, speedKmh);
  if (!entry) return Math.round(sanitizeNonNegative(input.fallbackCalories));
  if (distanceKm <= 0 || input.activeSeconds <= 0) return 0;
  if (
    !input.weightKg || !Number.isFinite(input.weightKg) || input.weightKg <= 0
  ) {
    return Math.round(sanitizeNonNegative(input.fallbackCalories));
  }
  return Math.round(entry.met * input.weightKg * input.activeSeconds / 3600);
}

function maxExpectedSpeedMs(activityType: string): number {
  switch (activityType.toLowerCase()) {
    case "walking":
      return 3.0;
    case "hiking":
      return 2.7;
    case "running":
      return 7.2;
    case "cycling":
      return 20;
    default:
      return 8;
  }
}

function averageNullable(a: number | null, b: number | null): number {
  if (a == null && b == null) return 0;
  if (a == null) return b ?? 0;
  if (b == null) return a;
  return (a + b) / 2;
}

function averageNumbers(values: number[]): number | null {
  const safe = values.filter((value) => Number.isFinite(value));
  if (safe.length === 0) return null;
  return safe.reduce((sum, value) => sum + value, 0) / safe.length;
}

function median(values: number[]): number {
  if (values.length === 0) return 0;
  const middle = Math.floor(values.length / 2);
  if (values.length % 2 === 1) return round2(values[middle]);
  return round2((values[middle - 1] + values[middle]) / 2);
}

function sanitizeNonNegative(value: number | null | undefined): number {
  const safe = Number(value ?? 0);
  if (!Number.isFinite(safe) || safe < 0) return 0;
  return safe;
}

function haversineMeters(
  a: { lat: number; lng: number },
  b: { lat: number; lng: number },
): number {
  const toRadians = (degrees: number) => (degrees * Math.PI) / 180;
  const earthRadiusMeters = 6371000;
  const dLat = toRadians(b.lat - a.lat);
  const dLng = toRadians(b.lng - a.lng);
  const lat1 = toRadians(a.lat);
  const lat2 = toRadians(b.lat);
  const hav = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLng / 2) * Math.sin(dLng / 2) * Math.cos(lat1) * Math.cos(lat2);
  const c = 2 * Math.atan2(Math.sqrt(hav), Math.sqrt(1 - hav));
  return earthRadiusMeters * c;
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

function round3(value: number): number {
  return Math.round(value * 1000) / 1000;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}
