// @deno-types="https://esm.sh/@supabase/supabase-js@2.105.1"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.1";

type RoutePoint = {
  lat: number;
  lng: number;
};

type RouteSegment = RoutePoint[];

type MatchStatus =
  | "pending"
  | "not_requested"
  | "matched_success_high_confidence"
  | "matched_success_medium_confidence"
  | "partial_match"
  | "match_failed_fallback_filtered";

type DistanceSource =
  | "filtered"
  | "matched"
  | "filtered_display_matched";

type RouteMatchResult = {
  matchedRoute: RouteSegment[];
  status: MatchStatus;
  confidence: number | null;
  distanceSource: DistanceSource;
  matchedDistanceKm: number | null;
  metrics: Record<string, unknown>;
};

type MatchedChunk = {
  geometry: RouteSegment;
  coverageRatio?: number;
  unmatchedCount?: number;
};

type ProcessingJobRow = {
  id: string;
  workout_id: string;
  attempt_count: number | null;
};

type WorkoutRouteRow = {
  processing_status: string;
  metrics_version: number;
  client_research_result_json?: unknown;
  filtered_route_json: unknown;
  distance_km: number | null;
  route_match_metrics_json: Record<string, unknown> | null;
};

type SupabaseAdminClient = any;

const ROUTE_CORRECTION_JOB_TYPE = "route_correction_finalize";
const MAX_ATTEMPTS = 3;
const MIN_POINTS = 10;
const MIN_DISTANCE_KM = 0.15;
const DEFAULT_CHUNK_SIZE = 100;
const DEFAULT_CHUNK_OVERLAP = 8;

const corsHeaders = {
  "Content-Type": "application/json",
};

if (import.meta.main) Deno.serve(handleRequest);

async function handleRequest(req: Request): Promise<Response> {
  try {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
      Deno.env.get("AETRON_SERVICE_ROLE_KEY");
    const authHeader = req.headers.get("Authorization") ?? "";
    const apiKeyHeader = req.headers.get("apikey") ?? "";
    const bearerToken = authHeader.replace(/^Bearer\s+/i, "").trim();

    if (
      !serviceRoleKey ||
      (bearerToken !== serviceRoleKey && apiKeyHeader !== serviceRoleKey)
    ) {
      return json({ error: "Unauthorized" }, 401);
    }

    const payload = await req.json().catch(() => ({}));
    const workoutId = payload.workout_id as string | undefined;
    const jobId = payload.job_id as string | undefined;

    if (!workoutId && !jobId) {
      return json({ error: "Missing workout_id or job_id" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      serviceRoleKey,
    );

    const job = await fetchQueuedJob(supabase, { workoutId, jobId });
    if (!job) {
      return json({ status: "noop", reason: "job_not_found" });
    }

    const workout = await fetchWorkout(supabase, job.workout_id);
    if (!workout) {
      await failJob(supabase, job.id, "workout_not_found");
      return json({ status: "failed", reason: "workout_not_found" }, 404);
    }
    // The dispatcher is not the only caller. Check dependency even for
    // direct requests and a deterministic job that exhausted its retries.
    const { data: finalizeJob, error: finalizeError } = await supabase
      .from("workout_processing_jobs").select("id, status")
      .eq("workout_id", job.workout_id)
      .eq("job_type", "deterministic_finalize")
      .order("created_at", { ascending: false })
      .order("id", { ascending: false })
      .limit(1).maybeSingle();
    if (finalizeError) throw finalizeError;
    if (!routeCorrectionReady(workout, finalizeJob?.status)) {
      return json({
        status: "deferred",
        reason: "deterministic_finalize_not_completed",
      });
    }
    if (!await markJobStarted(supabase, job)) {
      return json({ status: "noop", reason: "job_already_claimed" });
    }

    const reconciliation = workout.route_match_metrics_json
      ?.client_scientific_reconciliation;
    if (
      workout.client_research_result_json != null ||
      reconciliation != null
    ) {
      await completeJob(supabase, job.id);
      return json({
        status: "completed",
        reason: "scientific_server_audit_preserved",
      });
    }

    // The only implementation was identity geometry ("stub"), not a
    // map matcher. Never award matched confidence or bridge GPS gaps.
    const provider = Deno.env.get("ROUTE_MATCH_PROVIDER") ?? "stub";
    if (!routeMatchingAvailable(provider)) {
      const result = fallbackResult("no_verified_route_matching_adapter");
      await persistRouteMatchResult(
        supabase,
        job.workout_id,
        result,
        workout.route_match_metrics_json,
      );
      await completeJob(supabase, job.id);
      return json({ status: "completed", result });
    }

    const filteredRoute = parseRouteSegments(workout.filtered_route_json);
    const routePointCount = countRoutePoints(filteredRoute);
    const filteredDistanceKm = Number(workout.distance_km ?? 0);
    const gpsGapCount = Number(
      workout.route_match_metrics_json?.gps_gap_count ?? 0,
    );
    const gpsGapDurationSec = Number(
      workout.route_match_metrics_json?.gps_gap_duration_sec ?? 0,
    );

    if (
      routePointCount < MIN_POINTS || filteredDistanceKm < MIN_DISTANCE_KM ||
      filteredRoute.length === 0
    ) {
      const result = fallbackResult("trace_too_short");
      await persistRouteMatchResult(
        supabase,
        job.workout_id,
        result,
        workout.route_match_metrics_json,
      );
      await completeJob(supabase, job.id);
      return json({ status: "completed", result });
    }

    const chunks = chunkRouteSegments(
      filteredRoute,
      DEFAULT_CHUNK_SIZE,
      DEFAULT_CHUNK_OVERLAP,
    );

    const matchedChunks: MatchedChunk[] = [];
    let failedChunks = 0;

    for (const chunk of chunks) {
      try {
        const matched = await matchChunk(chunk);
        matchedChunks.push(matched);
      } catch (error) {
        console.error("[route-correction-worker] chunk match failed", error);
        failedChunks += 1;
      }
    }

    const mergedMatchedRoute = mergeMatchedChunks(matchedChunks);
    const result = scoreAndResolve({
      filteredRoute,
      mergedMatchedRoute,
      filteredDistanceKm,
      gpsGapCount,
      gpsGapDurationSec,
      failedChunks,
      totalChunks: chunks.length,
    });

    await persistRouteMatchResult(
      supabase,
      job.workout_id,
      result,
      workout.route_match_metrics_json,
    );
    await completeJob(supabase, job.id);

    return json({
      status: "completed",
      workout_id: job.workout_id,
      job_id: job.id,
      result,
    });
  } catch (error) {
    console.error("[route-correction-worker] fatal error", error);
    return json(
      {
        error: error instanceof Error ? error.message : "Internal error",
      },
      500,
    );
  }
}

export function routeCorrectionReady(
  workout: Pick<WorkoutRouteRow, "processing_status" | "metrics_version">,
  latestFinalizeStatus: string | undefined,
): boolean {
  return workout.processing_status === "client_finalized" &&
    workout.metrics_version >= 2 && latestFinalizeStatus === "completed";
}

export function routeMatchingAvailable(_provider: string): boolean {
  // No real provider is implemented in matchChunk; the stub is not evidence.
  return false;
}

async function fetchQueuedJob(
  supabase: SupabaseAdminClient,
  input: { workoutId?: string; jobId?: string },
): Promise<ProcessingJobRow | null> {
  let query = supabase
    .from("workout_processing_jobs")
    .select("*")
    .eq("job_type", ROUTE_CORRECTION_JOB_TYPE)
    .eq("status", "queued")
    .lt("attempt_count", MAX_ATTEMPTS)
    .order("created_at", { ascending: true })
    .limit(1);

  if (input.jobId) {
    query = query.eq("id", input.jobId);
  } else if (input.workoutId) {
    query = query.eq("workout_id", input.workoutId);
  }

  const { data, error } = await query.maybeSingle();
  if (error) throw error;
  return data;
}

async function fetchWorkout(
  supabase: SupabaseAdminClient,
  workoutId: string,
): Promise<WorkoutRouteRow | null> {
  const { data, error } = await supabase
    .from("workout_sessions")
    .select("*")
    .eq("id", workoutId)
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
      finished_at: null,
      error_message: null,
    })
    .eq("id", job.id)
    .eq("status", "queued")
    .eq("attempt_count", Number(job.attempt_count ?? 0))
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

function parseRouteSegments(raw: unknown): RouteSegment[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((segment) => {
      if (!Array.isArray(segment)) return [];
      return segment
        .map((point) => {
          if (!point || typeof point !== "object") return null;
          const lat = Number((point as Record<string, unknown>).lat);
          const lng = Number((point as Record<string, unknown>).lng);
          if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
          return { lat, lng };
        })
        .filter((point): point is RoutePoint => point !== null);
    })
    .filter((segment) => segment.length > 0);
}

function countRoutePoints(route: RouteSegment[]): number {
  return route.reduce((sum, segment) => sum + segment.length, 0);
}

function chunkRouteSegments(
  route: RouteSegment[],
  chunkSize: number,
  overlap: number,
): RouteSegment[] {
  const flat = route.flat();
  if (flat.length <= chunkSize) return [flat];

  const chunks: RouteSegment[] = [];
  let index = 0;
  while (index < flat.length) {
    const end = Math.min(index + chunkSize, flat.length);
    chunks.push(flat.slice(index, end));
    if (end >= flat.length) break;
    index = Math.max(end - overlap, index + 1);
  }
  return chunks;
}

async function matchChunk(chunk: RouteSegment): Promise<MatchedChunk> {
  const provider = Deno.env.get("ROUTE_MATCH_PROVIDER") ?? "stub";

  if (provider === "stub") {
    return {
      geometry: chunk,
      coverageRatio: 1,
      unmatchedCount: 0,
    };
  }

  throw new Error(
    `No route matching adapter implemented for provider "${provider}"`,
  );
}

function mergeMatchedChunks(chunks: MatchedChunk[]): RouteSegment[] {
  if (chunks.length === 0) return [];

  const merged: RouteSegment = [];
  for (const chunk of chunks) {
    for (const point of chunk.geometry) {
      const last = merged.at(-1);
      if (last && last.lat === point.lat && last.lng === point.lng) {
        continue;
      }
      merged.push(point);
    }
  }

  return merged.length > 0 ? [merged] : [];
}

function scoreAndResolve(input: {
  filteredRoute: RouteSegment[];
  mergedMatchedRoute: RouteSegment[];
  filteredDistanceKm: number;
  gpsGapCount: number;
  gpsGapDurationSec: number;
  failedChunks: number;
  totalChunks: number;
}): RouteMatchResult {
  const matchedPointCount = countRoutePoints(input.mergedMatchedRoute);
  if (matchedPointCount === 0) {
    return fallbackResult("no_matched_geometry");
  }

  const filteredPointCount = countRoutePoints(input.filteredRoute);
  const matchedCoverageRatio = filteredPointCount > 0
    ? matchedPointCount / filteredPointCount
    : 0;
  const matchedDistanceKm = estimateRouteDistanceKm(input.mergedMatchedRoute);
  const distanceDeltaRatio = input.filteredDistanceKm > 0
    ? Math.abs(matchedDistanceKm - input.filteredDistanceKm) /
      input.filteredDistanceKm
    : 0;
  const routeMatchDeviationMeters = estimateDeviationMeters(
    input.filteredRoute,
    input.mergedMatchedRoute,
  );
  const segmentContinuityScore = input.totalChunks > 0
    ? Math.max(0, 1 - input.failedChunks / input.totalChunks)
    : 0;

  const tooManyGaps = input.gpsGapCount > 2 || input.gpsGapDurationSec > 30;
  const metrics = {
    matchedCoverageRatio,
    distanceDeltaRatio,
    routeMatchDeviationMeters,
    unmatchedSegmentCount: input.failedChunks,
    segmentContinuityScore,
    gpsGapCount: input.gpsGapCount,
    gpsGapDurationSec: input.gpsGapDurationSec,
  };

  if (
    !tooManyGaps &&
    matchedCoverageRatio >= 0.9 &&
    distanceDeltaRatio <= 0.08 &&
    segmentContinuityScore >= 0.9
  ) {
    return {
      matchedRoute: input.mergedMatchedRoute,
      status: "matched_success_high_confidence",
      confidence: 0.92,
      distanceSource: "matched",
      matchedDistanceKm,
      metrics,
    };
  }

  if (
    matchedCoverageRatio >= 0.75 &&
    distanceDeltaRatio <= 0.15 &&
    segmentContinuityScore >= 0.7
  ) {
    return {
      matchedRoute: input.mergedMatchedRoute,
      status: "matched_success_medium_confidence",
      confidence: 0.78,
      distanceSource: "filtered_display_matched",
      matchedDistanceKm,
      metrics,
    };
  }

  if (matchedCoverageRatio >= 0.4) {
    return {
      matchedRoute: input.mergedMatchedRoute,
      status: "partial_match",
      confidence: 0.52,
      distanceSource: "filtered_display_matched",
      matchedDistanceKm,
      metrics,
    };
  }

  return fallbackResult("quality_threshold_failed", metrics);
}

async function persistRouteMatchResult(
  supabase: SupabaseAdminClient,
  workoutId: string,
  result: RouteMatchResult,
  existingMetrics: Record<string, unknown> | null,
) {
  const { error } = await supabase
    .from("workout_sessions")
    .update({
      matched_route_json: result.matchedRoute,
      route_match_status: result.status,
      route_match_confidence: result.confidence,
      route_distance_source: result.distanceSource,
      matched_distance_km: result.matchedDistanceKm,
      route_match_metrics_json: { ...existingMetrics, ...result.metrics },
    })
    .eq("id", workoutId);
  if (error) throw error;
}

function fallbackResult(
  reason: string,
  extraMetrics: Record<string, unknown> = {},
): RouteMatchResult {
  return {
    matchedRoute: [],
    status: "match_failed_fallback_filtered",
    confidence: 0,
    distanceSource: "filtered",
    matchedDistanceKm: null,
    metrics: {
      reason,
      ...extraMetrics,
    },
  };
}

function estimateRouteDistanceKm(route: RouteSegment[]): number {
  const flat = route.flat();
  if (flat.length < 2) return 0;
  let meters = 0;
  for (let i = 1; i < flat.length; i += 1) {
    meters += haversineMeters(flat[i - 1], flat[i]);
  }
  return meters / 1000;
}

function estimateDeviationMeters(
  filteredRoute: RouteSegment[],
  matchedRoute: RouteSegment[],
): number {
  const filteredFlat = filteredRoute.flat();
  const matchedFlat = matchedRoute.flat();
  if (filteredFlat.length === 0 || matchedFlat.length === 0) return 0;

  const sampleCount = Math.min(filteredFlat.length, matchedFlat.length, 20);
  let total = 0;
  for (let i = 0; i < sampleCount; i += 1) {
    const filteredPoint = filteredFlat[
      Math.floor((i * filteredFlat.length) / sampleCount)
    ];
    const matchedPoint = matchedFlat[
      Math.floor((i * matchedFlat.length) / sampleCount)
    ];
    total += haversineMeters(filteredPoint, matchedPoint);
  }
  return total / sampleCount;
}

function haversineMeters(a: RoutePoint, b: RoutePoint): number {
  const toRadians = (degrees: number) => (degrees * Math.PI) / 180;
  const earthRadiusMeters = 6371000;
  const dLat = toRadians(b.lat - a.lat);
  const dLng = toRadians(b.lng - a.lng);
  const lat1 = toRadians(a.lat);
  const lat2 = toRadians(b.lat);

  const hav = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLng / 2) * Math.sin(dLng / 2) *
      Math.cos(lat1) * Math.cos(lat2);
  const c = 2 * Math.atan2(Math.sqrt(hav), Math.sqrt(1 - hav));
  return earthRadiusMeters * c;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}
