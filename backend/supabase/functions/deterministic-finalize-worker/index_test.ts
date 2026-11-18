import {
  collectRawPages,
  computeCanonicalMetrics,
  incompleteRawEvidence,
  parseClientRoute,
} from "./index.ts";

function assert(condition: unknown, message = "Assertion failed") {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, got ${actual}`);
  }
}

const workout = {
  id: "00000000-0000-0000-0000-000000000001",
  user_id: "00000000-0000-0000-0000-000000000002",
  activity_type: "cycling",
  mode: "outdoor",
  started_at: "2026-04-26T00:00:00.000Z",
  ended_at: "2026-04-26T00:05:00.000Z",
  duration_sec: 300,
  moving_time_sec: null,
  distance_km: null,
  avg_speed_kmh: null,
  calories_kcal: null,
  steps: null,
};

function gpsPoint(seconds: number, northMeters: number) {
  return {
    timestamp: new Date(Date.parse(workout.started_at) + seconds * 1000)
      .toISOString(),
    latitude: northMeters / 111_320,
    longitude: 0,
    altitude: null,
    speed: null,
    accuracy: 8,
    heading: null,
    device_source: "test",
  };
}

Deno.test("cycling at allowed 3:00/km or slower remains valid", () => {
  const metrics = computeCanonicalMetrics({
    workout,
    rawGpsPoints: [
      gpsPoint(0, 0),
      gpsPoint(5, 25),
      gpsPoint(10, 50),
      gpsPoint(15, 75),
      gpsPoint(20, 100),
      gpsPoint(25, 125),
      gpsPoint(30, 150),
      gpsPoint(35, 175),
      gpsPoint(40, 200),
    ],
    rawStepIntervals: [],
    userProfile: null,
  });

  assert(metrics.distanceKm > 0.15);
  assertEquals(
    metrics.segmentAudits.every((audit) => audit.status === "valid"),
    true,
  );
  assertEquals(metrics.routeMatchMetricsJson.suspicious_segment_count, 0);
});

Deno.test("cycling at 2:00/km is flagged and excluded from canonical distance", () => {
  const metrics = computeCanonicalMetrics({
    workout,
    rawGpsPoints: [
      gpsPoint(0, 0),
      gpsPoint(5, 41.67),
      gpsPoint(10, 83.34),
      gpsPoint(15, 125.01),
      gpsPoint(20, 166.68),
    ],
    rawStepIntervals: [],
    userProfile: null,
  });

  assertEquals(metrics.distanceKm, 0);
  assertEquals(metrics.segmentAudits[0].status, "suspicious");
  assertEquals(metrics.segmentAudits[0].reason, "suspicious_fast_for_cycling");
  assertEquals(metrics.routeMatchMetricsJson.suspicious_segment_count, 2);
  assertEquals(metrics.logSummary.workoutValidityStatus, "unverified");
});

Deno.test("fast cycling followed by idle time remains flagged", () => {
  const idlePoints = Array.from(
    { length: 13 },
    (_, index) => gpsPoint(15 + index * 5, 125.01),
  );
  const metrics = computeCanonicalMetrics({
    workout: { ...workout, duration_sec: 180 },
    rawGpsPoints: [
      gpsPoint(0, 0),
      gpsPoint(5, 41.67),
      gpsPoint(10, 83.34),
      gpsPoint(15, 125.01),
      ...idlePoints,
    ],
    rawStepIntervals: [],
    userProfile: null,
  });

  assertEquals(metrics.distanceKm, 0);
  assertEquals(metrics.segmentAudits[0].status, "suspicious");
  assertEquals(metrics.routeMatchMetricsJson.suspicious_segment_count, 1);
  assert(
    Number(metrics.routeMatchMetricsJson.rest_after_fast_duration_sec ?? 0) >=
      60,
  );
});

// --- Route preservation: never wipe the client's live-snapshot route ---

const clientRoute = [
  Array.from({ length: 12 }, (_, index) => ({ lat: index * 0.0001, lng: 0 })),
];

Deno.test("outdoor with no raw GPS keeps the client live-snapshot route", () => {
  const metrics = computeCanonicalMetrics({
    workout,
    clientFilteredRoute: clientRoute,
    rawGpsPoints: [],
    rawStepIntervals: [],
    userProfile: null,
  });

  assertEquals(metrics.filteredRouteJson.length, 1);
  assertEquals(metrics.filteredRouteJson[0].length, 12);
  assertEquals(metrics.filteredRouteJson[0][0].lat, 0);
  assertEquals(metrics.routeMatchStatus, "pending");
  assertEquals(metrics.routeMatchMetricsJson.route_source, "client_fallback");
});

Deno.test("outdoor with no raw GPS and no client route stays empty", () => {
  const metrics = computeCanonicalMetrics({
    workout,
    rawGpsPoints: [],
    rawStepIntervals: [],
    userProfile: null,
  });

  assertEquals(metrics.filteredRouteJson.length, 0);
  assertEquals(metrics.routeMatchStatus, "not_requested");
  assertEquals(metrics.routeMatchMetricsJson.route_source, "none");
});

Deno.test(
  "suspicious raw points are NOT overridden by the client route fallback",
  () => {
    const metrics = computeCanonicalMetrics({
      workout,
      clientFilteredRoute: clientRoute,
      rawGpsPoints: [
        gpsPoint(0, 0),
        gpsPoint(5, 41.67),
        gpsPoint(10, 83.34),
        gpsPoint(15, 125.01),
        gpsPoint(20, 166.68),
      ],
      rawStepIntervals: [],
      userProfile: null,
    });

    assertEquals(metrics.filteredRouteJson.length, 0);
    assertEquals(metrics.routeMatchMetricsJson.route_source, "none");
  },
);

Deno.test("parseClientRoute accepts jsonb arrays, JSON strings, and garbage", () => {
  assertEquals(parseClientRoute(clientRoute).length, 1);
  assertEquals(parseClientRoute(clientRoute)[0].length, 12);
  assertEquals(parseClientRoute(JSON.stringify(clientRoute))[0].length, 12);
  assertEquals(parseClientRoute("[]").length, 0);
  assertEquals(parseClientRoute(null).length, 0);
  assertEquals(parseClientRoute({ not: "a route" }).length, 0);
  assertEquals(parseClientRoute("not json at all").length, 0);
});

Deno.test("Compendium MET uses moving time, not elapsed time or gender", () => {
  for (const mode of ["indoor", "outdoor"]) {
    const metrics = computeCanonicalMetrics({
      workout: {
        ...workout,
        activity_type: "running",
        mode,
        duration_sec: 1800,
        moving_time_sec: 1500,
        distance_km: 5,
      },
      rawGpsPoints: [],
      rawStepIntervals: [],
      userProfile: { weight_kg: 70, gender: "female" },
    });
    assertEquals(metrics.caloriesKcal, 306);
    assertEquals(metrics.movingTimeSec, 1500);
  }
});

Deno.test("Compendium MET preserves zero when known moving time is zero", () => {
  const metrics = computeCanonicalMetrics({
    workout: {
      ...workout,
      activity_type: "walking",
      mode: "indoor",
      duration_sec: 300,
      moving_time_sec: 0,
      distance_km: 0.1,
    },
    rawGpsPoints: [],
    rawStepIntervals: [],
    userProfile: { weight_kg: 70, gender: "male" },
  });
  assertEquals(metrics.caloriesKcal, 0);
});

Deno.test("Compendium walking and cycling use published speed-specific MET", () => {
  for (
    const [activity, mph, met] of [
      ["walking", 3, 3.8],
      ["walking", 3.7, 4.8],
      ["running", 5.6, 9],
      ["running", 6.2, 9.3],
      ["cycling", 11, 6.8],
      ["cycling", 15, 10],
    ] as const
  ) {
    const metrics = computeCanonicalMetrics({
      workout: {
        ...workout,
        activity_type: activity,
        mode: "indoor",
        duration_sec: 3600,
        moving_time_sec: 1800,
        distance_km: mph * 1.609344 * .5,
      },
      rawGpsPoints: [],
      rawStepIntervals: [],
      userProfile: { weight_kg: 70, gender: "female" },
    });
    assertEquals(metrics.caloriesKcal, Math.round(met * 35));
  }
});

const cleanRaw = Array.from({ length: 9 }, (_, i) => gpsPoint(i * 5, i * 25));
const clientDistance = 175 / 111_320 * Math.PI / 180 * 6_371_000 / 1000;
const researchRoute = [
  cleanRaw.slice(0, 8).map((point) => ({
    lat: point.latitude,
    lng: point.longitude,
  })),
];

function scientificResult(overrides: Record<string, unknown> = {}) {
  return {
    version: 1,
    session_id: workout.id,
    activity_type: "cycling",
    mode: "outdoor",
    distance_km: clientDistance,
    duration_sec: 300,
    moving_time_sec: 300,
    steps: 0,
    filtered_route: researchRoute,
    reconstructed_route: researchRoute,
    reconstruction_status: "reconstructed_pchip",
    audit: {
      scientific_result_version: 1,
      gps_algorithm: "aekf_4state",
      distance_selection_policy: "aekf_filtered_then_preprocessed_clean",
      raw_gps_fix_count: cleanRaw.length,
      step_distance_m: 0,
      reconstruction_enabled: true,
      reconstruction_method: "monotonePchip",
    },
    ...overrides,
  };
}

function replayScientific(claim: unknown, rawGpsPoints = cleanRaw) {
  return computeCanonicalMetrics({
    workout: {
      ...workout,
      distance_km: clientDistance,
      client_research_result_json: claim,
    },
    rawGpsPoints,
    rawStepIntervals: [],
    userProfile: null,
  });
}

Deno.test("clean bounded client AEKF distance is retained; P03 is archived only", () => {
  const result = replayScientific(scientificResult());
  assertEquals(result.distanceKm, clientDistance);
  assertEquals(result.routeMatchStatus, "not_requested");
  assertEquals(result.routeDistanceSource, "filtered");
  assertEquals(result.routeMatchMetricsJson.reconstruction_display_only, false);
  assertEquals(result.routeMatchMetricsJson.reconstruction_archived_only, true);
  assertEquals(result.reconstructedRouteJson?.length, 0);
  assertEquals(result.filteredRouteJson[0][0].timestamp, undefined);
  const audit = result.routeMatchMetricsJson
    .client_scientific_reconciliation as Record<string, unknown>;
  assertEquals(audit.selected, true);
  assertEquals(audit.exact_replay, false);
  assert(Number(audit.server_raw_distance_km) > result.distanceKm);
});

Deno.test("unverified remote P03 geometry is never promoted by a clean AEKF claim", () => {
  const result = replayScientific(scientificResult({
    reconstructed_route: [[{ lat: 80, lng: 150 }, { lat: 81, lng: 151 }]],
  }));
  assertEquals(result.distanceKm, clientDistance);
  assertEquals(result.reconstructedRouteJson?.length, 0);
  assertEquals(result.routeMatchStatus, "not_requested");
});

Deno.test("mixed walking ending indoors or outdoors retains bounded reported total and raw audit", () => {
  const raw = Array.from({ length: 9 }, (_, i) => gpsPoint(i * 5, i * 6));
  const route = [
    raw.map((point) => ({ lat: point.latitude, lng: point.longitude })),
  ];
  const gpsKm = 48 / 111_320 * Math.PI / 180 * 6_371_000 / 1000;
  const distance = gpsKm + 0.075;
  const intervals = [{
    interval_start: workout.started_at,
    interval_end: workout.ended_at,
    steps_count: 100,
  }];
  for (const mode of ["indoor", "outdoor"]) {
    const claim = scientificResult({
      activity_type: "walking",
      mode,
      steps: 100,
      distance_km: distance,
      filtered_route: route,
      audit: {
        scientific_result_version: 1,
        distance_selection_policy: "segmented_gps_plus_step_distance",
        raw_gps_fix_count: raw.length,
        step_distance_m: 75,
        gps_live_distance_m: gpsKm * 1000,
      },
    });
    const result = computeCanonicalMetrics({
      workout: {
        ...workout,
        activity_type: "walking",
        mode,
        distance_km: distance,
        steps: 100,
        client_research_result_json: claim,
      },
      rawGpsPoints: raw,
      rawStepIntervals: intervals,
      userProfile: null,
    });
    const audit = result.routeMatchMetricsJson
      .client_scientific_reconciliation as Record<string, unknown>;
    assertEquals(result.distanceKm, distance);
    assertEquals(result.steps, 100);
    assertEquals(audit.selected, true);
    assertEquals(audit.exact_replay, false);
    assertEquals(
      result.routeMatchMetricsJson.workout_validity_status,
      "unverified",
    );
    assertEquals(
      result.routeMatchMetricsJson.source_interval_overlap_verified,
      false,
    );
    assert(result.segmentAudits.length > 0);
    assert(result.filteredRouteJson.length > 0);
    assertEquals(result.reconstructedRouteJson?.length, 0);
  }
});

Deno.test("mixed claim cannot replace audit with missing step observations", () => {
  const walkingRaw = Array.from(
    { length: 9 },
    (_, i) => gpsPoint(i * 5, i * 6),
  );
  const claim = scientificResult({
    activity_type: "walking",
    mode: "indoor",
    steps: 100,
    audit: {
      scientific_result_version: 1,
      distance_selection_policy: "segmented_gps_plus_step_distance",
      step_distance_m: 75,
      raw_gps_fix_count: walkingRaw.length,
    },
  });
  const row = {
    ...workout,
    activity_type: "walking",
    mode: "indoor",
    steps: 100,
    client_research_result_json: claim,
  };
  assertEquals(
    incompleteRawEvidence(row, walkingRaw, []),
    "awaiting_raw_step_upload",
  );
  assertEquals(
    incompleteRawEvidence(row, walkingRaw.slice(0, 8), []),
    "awaiting_raw_gps_upload",
  );
  const result = computeCanonicalMetrics({
    workout: row,
    rawGpsPoints: walkingRaw,
    rawStepIntervals: [],
    userProfile: null,
  });
  const audit = result.routeMatchMetricsJson
    .client_scientific_reconciliation as Record<string, unknown>;
  assertEquals(audit.selected, false);
  assertEquals(audit.client_step_distance_m, 75);
  assert(result.segmentAudits.length > 0);
  assertEquals(result.reconstructedRouteJson?.length, 0);
});

Deno.test("raw route and audit do not bridge a gap inside one audit bucket", () => {
  const raw = [
    gpsPoint(0, 0),
    gpsPoint(5, 6),
    gpsPoint(50, 200),
    gpsPoint(55, 206),
  ];
  const result = computeCanonicalMetrics({
    workout: { ...workout, activity_type: "walking" },
    rawGpsPoints: raw,
    rawStepIntervals: [],
    userProfile: null,
  });
  assertEquals(result.filteredRouteJson.length, 2);
  assertEquals(result.segmentAudits.length, 2);
  assertEquals(result.routeMatchMetricsJson.gps_gap_count, 1);
  assert(result.distanceKm < 0.02);
});

Deno.test("scientific marker does not bypass suspicious raw audit", () => {
  const raw = Array.from({ length: 9 }, (_, i) => gpsPoint(i * 5, i * 41.67));
  const result = replayScientific(scientificResult(), raw);
  assertEquals(result.distanceKm, 0);
  const audit = result.routeMatchMetricsJson
    .client_scientific_reconciliation as Record<string, unknown>;
  assertEquals(audit.selected, false);
  assertEquals(audit.reason, "raw_audit_not_clean");
  assertEquals(result.reconstructedRouteJson?.length, 0);
});

Deno.test("incomplete raw data, mixed contributions and malformed payload do not select client", () => {
  for (
    const [claim, raw] of [
      [scientificResult(), cleanRaw.slice(0, 8)],
      [
        scientificResult({
          audit: { ...scientificResult().audit, step_distance_m: 30 },
        }),
        cleanRaw,
      ],
      [
        scientificResult({
          filtered_route: [[{ lat: 200, lng: 0 }, { lat: 201, lng: 0 }]],
        }),
        cleanRaw,
      ],
      [scientificResult({ distance_km: 42 }), cleanRaw],
      [
        scientificResult({
          filtered_route: [
            researchRoute[0].map((p) => ({ lat: p.lat + 20, lng: p.lng })),
          ],
        }),
        cleanRaw,
      ],
      [scientificResult({ duration_sec: 10 }), cleanRaw],
    ] as const
  ) {
    const result = replayScientific(claim, raw);
    const audit = result.routeMatchMetricsJson
      .client_scientific_reconciliation as Record<string, unknown>;
    assertEquals(audit.selected, false);
    assertEquals(result.reconstructedRouteJson?.length, 0);
  }
});

Deno.test("cycling never produces steps even when raw pedometer counts exist", () => {
  const result = computeCanonicalMetrics({
    workout: { ...workout, steps: 99 },
    rawGpsPoints: cleanRaw,
    rawStepIntervals: [{
      interval_start: workout.started_at,
      interval_end: workout.ended_at,
      steps_count: 99,
    }],
    userProfile: null,
  });
  assertEquals(result.steps, 0);
});

Deno.test("raw paging reads all samples and empty terminal page", async () => {
  const rows = [1, 2, 3, 4, 5, 6];
  const calls: number[] = [];
  const result = await collectRawPages((from, to) => {
    calls.push(from);
    return Promise.resolve(rows.slice(from, to + 1));
  }, 2);
  assertEquals(JSON.stringify(result), JSON.stringify(rows));
  assertEquals(JSON.stringify(calls), "[0,2,4,6]");
});
