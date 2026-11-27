import {
  assertEquals,
  assertAlmostEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  estimateBeta,
  estimateSigmaZ,
  matchTrajectoryHmm,
  RoadGraph,
  TimedGpsObs,
} from "./hmm_map_matcher.ts";

// Synthetic 2-parallel-road graph (Main St at lng=0.0, Side St 30m east, connected only at south end)
const LNG_30M = 30.0 / 111320.0;
const LAT_100M = 100.0 / 111320.0;

const TEST_GRAPH: RoadGraph = {
  nodes: {
    A: { id: "A", lat: 0.0, lng: 0.0 },
    B: { id: "B", lat: LAT_100M, lng: 0.0 },
    C: { id: "C", lat: 0.0, lng: LNG_30M },
    D: { id: "D", lat: LAT_100M, lng: LNG_30M },
  },
  edges: [
    { id: "main_st", from: "A", to: "B", bidirectional: true },
    { id: "side_st", from: "C", to: "D", bidirectional: true },
    { id: "south_link", from: "A", to: "C", bidirectional: true },
  ],
};

Deno.test("SDD-07 MAD estimators match Newson & Krumm (2009) Section 4", () => {
  assertAlmostEquals(estimateSigmaZ([1.0, 2.0, 3.0, 4.0, 5.0]), 1.4826 * 3.0, 1e-9);
  assertAlmostEquals(estimateBeta([2.0, 4.0, 6.0]), 4.0 / Math.LN2, 1e-9);
});

Deno.test("SDD-07 Viterbi stays on main_st despite single noisy outlier closer to side_st", () => {
  // User walks north along main_st (lng=0), but epoch 2 has a 20m eastward GPS jump
  // closer to side_st (10m from side_st vs 20m from main_st). Because switching to
  // side_st requires backtracking ~100m via south_link, transition penalty keeps Viterbi on main_st!
  const obs: TimedGpsObs[] = [
    { lat: 0.1 * LAT_100M, lng: 0.0, timestampSec: 0 },
    { lat: 0.4 * LAT_100M, lng: 0.0, timestampSec: 5 },
    { lat: 0.6 * LAT_100M, lng: (20.0 / 30.0) * LNG_30M, timestampSec: 10 }, // outlier toward side_st
    { lat: 0.8 * LAT_100M, lng: 0.0, timestampSec: 15 },
    { lat: 0.95 * LAT_100M, lng: 0.0, timestampSec: 20 },
  ];

  const out = matchTrajectoryHmm(TEST_GRAPH, obs, {
    sigmaZ: 5.0,
    beta: 5.0,
    searchRadiusM: 50.0,
    maxGapSec: 15.0,
  });

  assertEquals(out.status, "matched");
  assertEquals(out.segments.length, 1);
  assertEquals(out.segments[0].matchedEdgeIds, [
    "main_st",
    "main_st",
    "main_st",
    "main_st",
    "main_st",
  ]);
});

Deno.test("SDD-07 Temporal gap > maxGapSec splits segments without bridging", () => {
  const obs: TimedGpsObs[] = [
    { lat: 0.1 * LAT_100M, lng: 0.0, timestampSec: 0 },
    { lat: 0.2 * LAT_100M, lng: 0.0, timestampSec: 5 },
    // 60s gap -> must split into second segment
    { lat: 0.7 * LAT_100M, lng: LNG_30M, timestampSec: 65 },
    { lat: 0.9 * LAT_100M, lng: LNG_30M, timestampSec: 70 },
  ];

  const out = matchTrajectoryHmm(TEST_GRAPH, obs, { maxGapSec: 15.0 });
  assertEquals(out.status, "matched");
  assertEquals(out.segments.length, 2);
  assertEquals(out.segments[0].matchedEdgeIds, ["main_st", "main_st"]);
  assertEquals(out.segments[1].matchedEdgeIds, ["side_st", "side_st"]);
});
