/**
 * SDD-07: Hidden Markov Model Map Matching
 *
 * Implements the probabilistic formulation of:
 *   Newson, P., & Krumm, J. (2009). "Hidden Markov Map Matching Through Noise
 *   and Sparseness." ACM SIGSPATIAL GIS 2009, pp. 336–343.
 *   DOI: 10.1145/1653771.1653818.
 *
 * Equations:
 *   - Emission:   p(z_t | r_i) = (1 / (sqrt(2*pi) * sigma_z)) * exp(-0.5 * (dist_gc / sigma_z)^2)
 *   - Transition: p(d_t) = (1 / beta) * exp(-d_t / beta),
 *                 where d_t = |dist_gc(z_t, z_{t+1}) - dist_route(x_{t,i}, x_{t+1,j})|
 *   - Estimators: sigma_z = 1.4826 * median_t(||z_t - x_{t,i*}||_gc)
 *                 beta    = (1 / ln(2)) * median_t(d_t)
 *   - Decoding:   Viterbi algorithm in log-space with segment splitting on breaks.
 *
 * Production status:
 *   Standalone verified HMM engine. Production route-correction-worker remains
 *   fail-safe (`routeMatchingAvailable() = false`) until a fixed OSM road graph
 *   and Seattle reference benchmark are connected (NOT REPRODUCED on Seattle).
 */

export interface GeoPoint {
  lat: number;
  lng: number;
}

export interface TimedGpsObs extends GeoPoint {
  timestampSec: number;
}

export interface RoadNode {
  id: string;
  lat: number;
  lng: number;
}

export interface RoadEdge {
  id: string;
  from: string;
  to: string;
  bidirectional?: boolean;
}

export interface RoadGraph {
  nodes: Record<string, RoadNode>;
  edges: RoadEdge[];
}

export interface CandidateMatch {
  edgeId: string;
  projectedPoint: GeoPoint;
  fractionAlongEdge: number; // [0, 1]
  greatCircleDistM: number;
}

export interface HmmMatchConfig {
  sigmaZ: number; // meters (Newson & Krumm default ~4.07 m)
  beta: number; // meters (Newson & Krumm ~1/ln(2) * median(d_t))
  searchRadiusM: number; // candidate search radius (default 50 m)
  maxGapSec: number; // split segments across temporal gaps
}

export interface HmmMatchSegmentResult {
  matchedEdgeIds: string[];
  matchedPoints: GeoPoint[];
  logLikelihood: number;
}

export interface HmmMatchOutput {
  status: "matched" | "partial_match" | "unmatched";
  segments: HmmMatchSegmentResult[];
  matchedRatio: number;
}

const EARTH_RADIUS_M = 6371000.0;

export function haversineMeters(a: GeoPoint, b: GeoPoint): number {
  const toRad = (d: number) => (d * Math.PI) / 180.0;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const sinLat = Math.sin(dLat / 2.0);
  const sinLng = Math.sin(dLng / 2.0);
  const h =
    sinLat * sinLat +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * sinLng * sinLng;
  return 2.0 * EARTH_RADIUS_M * Math.asin(Math.min(1.0, Math.sqrt(h)));
}

/** Projects point p orthogonally onto segment [a, b] in local equirectangular coordinates. */
export function projectPointToSegment(
  p: GeoPoint,
  a: GeoPoint,
  b: GeoPoint,
): { point: GeoPoint; fraction: number; distM: number } {
  const cosLat = Math.cos(((a.lat + b.lat) * 0.5 * Math.PI) / 180.0);
  const mPerDegLat = 111320.0;
  const mPerDegLng = 111320.0 * Math.max(cosLat, 1e-6);

  const ax = 0;
  const ay = 0;
  const bx = (b.lng - a.lng) * mPerDegLng;
  const by = (b.lat - a.lat) * mPerDegLat;
  const px = (p.lng - a.lng) * mPerDegLng;
  const py = (p.lat - a.lat) * mPerDegLat;

  const ab2 = bx * bx + by * by;
  let t = 0.0;
  if (ab2 > 1e-12) {
    t = Math.max(0.0, Math.min(1.0, ((px - ax) * bx + (py - ay) * by) / ab2));
  }
  const proj: GeoPoint = {
    lat: a.lat + t * (b.lat - a.lat),
    lng: a.lng + t * (b.lng - a.lng),
  };
  return { point: proj, fraction: t, distM: haversineMeters(p, proj) };
}

/** Computes shortest path distance (meters) between two nodes using Dijkstra. */
function shortestNodeDistanceM(
  graph: RoadGraph,
  startId: string,
  endId: string,
): number {
  if (startId === endId) return 0.0;
  const adj: Record<string, Array<{ to: string; w: number }>> = {};
  for (const e of graph.edges) {
    const a = graph.nodes[e.from];
    const b = graph.nodes[e.to];
    if (!a || !b) continue;
    const w = haversineMeters(a, b);
    (adj[e.from] ??= []).push({ to: e.to, w });
    if (e.bidirectional !== false) {
      (adj[e.to] ??= []).push({ to: e.from, w });
    }
  }

  const dist: Record<string, number> = { [startId]: 0.0 };
  const visited = new Set<string>();

  while (true) {
    let bestNode: string | null = null;
    let bestDist = Infinity;
    for (const [k, v] of Object.entries(dist)) {
      if (!visited.has(k) && v < bestDist) {
        bestDist = v;
        bestNode = k;
      }
    }
    if (bestNode === null || bestNode === endId) break;
    visited.add(bestNode);
    for (const nb of adj[bestNode] ?? []) {
      const nd = bestDist + nb.w;
      if (nd < (dist[nb.to] ?? Infinity)) {
        dist[nb.to] = nd;
      }
    }
  }
  return dist[endId] ?? Infinity;
}

/** Shortest route distance between two projected candidates on the road graph. */
export function routeDistanceMeters(
  graph: RoadGraph,
  c1: CandidateMatch,
  c2: CandidateMatch,
): number {
  if (c1.edgeId === c2.edgeId) {
    return haversineMeters(c1.projectedPoint, c2.projectedPoint);
  }
  const e1 = graph.edges.find((e) => e.id === c1.edgeId);
  const e2 = graph.edges.find((e) => e.id === c2.edgeId);
  if (!e1 || !e2) return Infinity;

  const a1 = graph.nodes[e1.from];
  const b1 = graph.nodes[e1.to];
  const a2 = graph.nodes[e2.from];
  const b2 = graph.nodes[e2.to];
  if (!a1 || !b1 || !a2 || !b2) return Infinity;

  const len1 = haversineMeters(a1, b1);
  const len2 = haversineMeters(a2, b2);

  const exits1 = e1.bidirectional !== false
    ? [
      { node: e1.from, d: c1.fractionAlongEdge * len1 },
      { node: e1.to, d: (1.0 - c1.fractionAlongEdge) * len1 },
    ]
    : [{ node: e1.to, d: (1.0 - c1.fractionAlongEdge) * len1 }];

  const entries2 = e2.bidirectional !== false
    ? [
      { node: e2.from, d: c2.fractionAlongEdge * len2 },
      { node: e2.to, d: (1.0 - c2.fractionAlongEdge) * len2 },
    ]
    : [{ node: e2.from, d: c2.fractionAlongEdge * len2 }];

  let best = Infinity;
  for (const ex of exits1) {
    for (const en of entries2) {
      const mid = shortestNodeDistanceM(graph, ex.node, en.node);
      if (Number.isFinite(mid)) {
        best = Math.min(best, ex.d + mid + en.d);
      }
    }
  }
  return best;
}

/** Newson & Krumm (2009) Gaussian emission log-probability. */
export function logEmissionProb(distM: number, sigmaZ: number): number {
  const z = distM / sigmaZ;
  return -Math.log(Math.sqrt(2.0 * Math.PI) * sigmaZ) - 0.5 * z * z;
}

/** Newson & Krumm (2009) Exponential transition log-probability. */
export function logTransitionProb(
  greatCircleM: number,
  routeM: number,
  beta: number,
): number {
  if (!Number.isFinite(routeM)) return -Infinity;
  const dt = Math.abs(greatCircleM - routeM);
  return -Math.log(beta) - dt / beta;
}

function median(values: number[]): number {
  if (values.length === 0) return 0.0;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 1
    ? sorted[mid]
    : 0.5 * (sorted[mid - 1] + sorted[mid]);
}

/** Newson & Krumm Section 4 MAD estimator: sigma_z = 1.4826 * median(|z_t - x_{t,i*}|). */
export function estimateSigmaZ(greatCircleErrorsM: number[]): number {
  return 1.4826 * median(greatCircleErrorsM);
}

/** Newson & Krumm Section 4 MAD estimator: beta = (1 / ln(2)) * median(d_t). */
export function estimateBeta(routeDiffsM: number[]): number {
  return median(routeDiffsM) / Math.LN2;
}

/** Runs Newson & Krumm (2009) Viterbi HMM map matching with gap splitting. */
export function matchTrajectoryHmm(
  graph: RoadGraph,
  observations: TimedGpsObs[],
  config: Partial<HmmMatchConfig> = {},
): HmmMatchOutput {
  const cfg: HmmMatchConfig = {
    sigmaZ: config.sigmaZ ?? 4.07,
    beta: config.beta ?? 6.0,
    searchRadiusM: config.searchRadiusM ?? 50.0,
    maxGapSec: config.maxGapSec ?? 15.0,
  };

  if (observations.length === 0) {
    return { status: "unmatched", segments: [], matchedRatio: 0.0 };
  }

  // Split observations into contiguous segments across temporal gaps
  const obsSegments: TimedGpsObs[][] = [];
  let cur: TimedGpsObs[] = [observations[0]];
  for (let i = 1; i < observations.length; i++) {
    const dt = observations[i].timestampSec - observations[i - 1].timestampSec;
    if (dt <= 0 || dt > cfg.maxGapSec) {
      obsSegments.push(cur);
      cur = [observations[i]];
    } else {
      cur.push(observations[i]);
    }
  }
  obsSegments.push(cur);

  const matchedSegments: HmmMatchSegmentResult[] = [];
  let matchedObsCount = 0;

  for (const seg of obsSegments) {
    const candPerStep: CandidateMatch[][] = seg.map((obs) => {
      const cands: CandidateMatch[] = [];
      for (const e of graph.edges) {
        const a = graph.nodes[e.from];
        const b = graph.nodes[e.to];
        if (!a || !b) continue;
        const proj = projectPointToSegment(obs, a, b);
        if (proj.distM <= cfg.searchRadiusM) {
          cands.push({
            edgeId: e.id,
            projectedPoint: proj.point,
            fractionAlongEdge: proj.fraction,
            greatCircleDistM: proj.distM,
          });
        }
      }
      return cands;
    });

    // Sub-split if any step has zero candidates (Viterbi break)
    let subStart = 0;
    while (subStart < seg.length) {
      while (subStart < seg.length && candPerStep[subStart].length === 0) {
        subStart++;
      }
      if (subStart >= seg.length) break;
      let subEnd = subStart;
      while (subEnd < seg.length && candPerStep[subEnd].length > 0) {
        subEnd++;
      }

      const len = subEnd - subStart;
      const dp: number[][] = [];
      const back: number[][] = [];

      // Init step 0
      const c0 = candPerStep[subStart];
      dp.push(c0.map((c) => logEmissionProb(c.greatCircleDistM, cfg.sigmaZ)));
      back.push(c0.map(() => -1));

      let validChain = true;
      for (let t = 1; t < len; t++) {
        const prevCands = candPerStep[subStart + t - 1];
        const curCands = candPerStep[subStart + t];
        const gcStep = haversineMeters(
          seg[subStart + t - 1],
          seg[subStart + t],
        );

        const curDp: number[] = [];
        const curBack: number[] = [];
        let anyFinite = false;

        for (let j = 0; j < curCands.length; j++) {
          const emit = logEmissionProb(curCands[j].greatCircleDistM, cfg.sigmaZ);
          let bestVal = -Infinity;
          let bestIdx = -1;
          for (let i = 0; i < prevCands.length; i++) {
            const prevVal = dp[t - 1][i];
            if (!Number.isFinite(prevVal)) continue;
            const rDist = routeDistanceMeters(graph, prevCands[i], curCands[j]);
            const trans = logTransitionProb(gcStep, rDist, cfg.beta);
            const candVal = prevVal + trans + emit;
            if (candVal > bestVal) {
              bestVal = candVal;
              bestIdx = i;
            }
          }
          if (Number.isFinite(bestVal)) anyFinite = true;
          curDp.push(bestVal);
          curBack.push(bestIdx);
        }

        if (!anyFinite) {
          validChain = false;
          break;
        }
        dp.push(curDp);
        back.push(curBack);
      }

      if (validChain && dp.length === len) {
        const lastDp = dp[len - 1];
        let bestIdx = 0;
        for (let j = 1; j < lastDp.length; j++) {
          if (lastDp[j] > lastDp[bestIdx]) bestIdx = j;
        }
        if (Number.isFinite(lastDp[bestIdx])) {
          const edgeIds = new Array<string>(len);
          const pts = new Array<GeoPoint>(len);
          let idx = bestIdx;
          for (let t = len - 1; t >= 0; t--) {
            const cand = candPerStep[subStart + t][idx];
            edgeIds[t] = cand.edgeId;
            pts[t] = cand.projectedPoint;
            idx = back[t][idx];
          }
          matchedSegments.push({
            matchedEdgeIds: edgeIds,
            matchedPoints: pts,
            logLikelihood: lastDp[bestIdx],
          });
          matchedObsCount += len;
        }
      }

      subStart = subEnd;
    }
  }

  const ratio = matchedObsCount / observations.length;
  const status = ratio >= 0.999
    ? "matched"
    : ratio > 0.0
    ? "partial_match"
    : "unmatched";

  return { status, segments: matchedSegments, matchedRatio: ratio };
}
