# Aetron Cycling GNSS — external public-data stress benchmark

## Source and experimental scope

Branch ekf, base HEAD 1ca6625; production algorithms unchanged.
SignAlign smartphone Cycling data could not be downloaded: repository
https://github.com/PositionRequirements/SignAlign-Dataset at
57b779ea72cc94bfa5c299b1fbbf5e51a83a54ad exposes README and LICENSE only.
Instead, use Jonas Beuchert, SnapperGPS: Collection of GNSS Signal Snapshots 2
(University of Oxford, 2023), DOI 10.5287/ora-xq5b8xva7,
https://github.com/JonasBchrt/snapshot-gnss-data-2 at
1e41879abf6bef3190d6f983280af8329c9c5717 (CC BY 4.0).
All 12 Cycling recordings c00–c11, 27,237 source rows, 7 h 34 min
approximately, urban and rural, nominal 1 s sampling. Baseline unsmoothed
position fixes and independently acquired u-blox ZED-F9P RTK positions.
This is a low-cost dedicated snapshot receiver, NOT a smartphone.
Some recordings share the same ride/reference; twelve files do not imply
twelve independent riders. This is an external stress benchmark, not
an exact reproduction of the Aetron P01/P02/P03 papers or native OS accuracy.

## Protocol

Use shared production WorkoutTrackingEngine, streaming P01 resolver and
GpsSmoothingService with activityType=cycling. Same unchanged thresholds,
with legacy EKF and P01+legacy EKF baselines. No ground-truth-derived input,
no tuning to this cohort. Sensor speed is unavailable (negative missing
sentinel); heading absent. Timestamp is the author's estimated UTC fix
time; match nearest unique RTK second within 500 ms, remove ambiguous
duplicate reference seconds and invalid/non-positive-confidence fixes;
deduplicate identical fix timestamps, sort timestamps and choose closest
fix if multiple match one reference second. Match all methods on a common
mask and separately report output availability, including pre-seed omissions.
On rejection after seed hold last estimate, as in prior TU Wien replay.
The result measures position-level shared services, not full workout
finalizer/lifecycle or official saved workout distance.

Author confidence is a 50% radial confidence radius in metres, NOT reported
native smartphone horizontal accuracy. Main diagnostic directly supplies
this radius as an optimistic accuracy proxy. Sensitivity converts to
68% radial confidence under an isotropic Gaussian assumption via
sqrt(log(1-.68)/log(.5)) = 1.28212955. Neither is a measured smartphone
accuracy. The Gaussian assumption is not validated on this source.
Do not tune to this sensitivity or discard zero-coverage sessions.

P03: keep valid fixes on UTC seconds divisible by five, mask other
observations; batch P01 plus actual Linear Chord or Monotone PCHIP.
Only evaluate reconstructed points on held-out matched source epochs
(no observed endpoint). Common reconstruction mask and coverage reported.
This is a separate component benchmark, not an accuracy measure of gaps
in a complete workout. RTK never enters interpolation. No bridging severe
outages beyond the existing reconstruction policy.

## Results — direct source confidence-radius proxy

26,985 valid unique fixes; 26,171 matched raw epochs across 12 files.
The original author's table reports raw cycling median 14.5 m; our all-raw
matched median is 14.455 m, RMSE 29.504 m. Different time masks and
aggregation definitions may prevent direct comparison of smoother metrics.

20,770 epochs common to all pipelines, 79.36% of raw matched epochs;
9 of 12 tracks have a seeded pipeline. c09/c10/c11 never seed.
P01+P02 accepts 6,650 of 26,985 valid fixes (24.64%), the remainder are
rejected. The output mask includes held estimates and is not acceptance rate.

| Method | RMSE m | MAE m | Median m | P95 m | Mean adjacent-distance error % |
|---|---:|---:|---:|---:|---:|
| Raw (common mask) | 27.670 | 18.380 | 13.681 | 46.462 | 360.343 |
| Legacy EKF | 41.001 | 23.575 | 12.664 | 85.124 | 30.727 |
| P01 + legacy EKF | 64.337 | 33.697 | 15.008 | 137.303 | 13.412 |
| P01 + AEKF | 138.226 | 63.778 | 16.341 | 373.104 | 15.180 |

Distance metric is per-track absolute relative error of the sum of
distances between consecutive matched UTC seconds (9 tracks), averaged
equally, not total ride distance or saved app distance. The AEKF has much
worse position error than raw, legacy EKF and P01+EKF on this cohort.
P01+legacy EKF also has lower mean distance error than P01+AEKF.
The large error tails are preserved, including tracks with RMSE above
190 m. No claim that this proves smartphone performance or P01 outlier
classification accuracy.

P03: 20,934 masked reference epochs, 10,543 reconstructable on both
methods (50.36% coverage).

| Method | RMSE m | MAE m | Median m |
|---|---:|---:|---:|
| Linear chord | 14.114 | 11.733 | 10.198 |
| Monotone PCHIP | 15.486 | 12.857 | 11.186 |

PCHIP is worse by RMSE; retained as the research default without tuning.

## Sensitivity to radius conversion

The 68% proxy makes all 12 tracks fail the existing 20 m first-fix
accuracy gate. Accepted fixes = 0, common output = 0; no RMSE/MAE
is calculable for the tracking pipeline. This is a real negative result,
not an error of the benchmark. Separate P03 component only reconstructs
3,489 of 20,934 held-out epochs, roughly 16.67%; RMSE linear 12.769 m,
PCHIP 14.187 m on that subset. Do not compare these across masks as
performance gains. These results strongly depend on the receiver-specific
confidence semantics and missing speed/heading; no deployment adjustment
is justified from this dataset alone.

## Reproducibility and validation

From repository root:
```sh
python3 tooling/benchmark/download_snappergps_cycling.py
flutter test --no-pub tooling/benchmark/cycling_snappergps_replay_test.dart --reporter expanded
flutter analyze --no-pub tooling/benchmark/cycling_snappergps_replay_test.dart tooling/benchmark/gnss_p01_p02_active_replay_test.dart
```

All 26 source files verified against pinned SHA256 hashes (including
README and LICENSE). Manifest repeat run has identical SHA256
946fae52eb2a4f464d240f596130e7b7651a0f7955150953d4dc18ba82c8f909.
Independent aggregation checks confirm masks, per-session counts and pooled
MAE/RMSE. Targeted analyzer clean. Repo currently contains a pre-existing
unmerged record_screen.dart (conflict markers); not modified by this work.
No full app build or full test suite claim. No deployment, production
changes, commit or push.

Output: tooling/benchmark/results/cycling_snappergps_20261119/
(manifest.json, source_provenance.json and replay.log).
Smartphone Cycling benchmark remains open until a public matched
smartphone+RTK cohort is accessible. This external position-level
benchmark is complete and supports a limited research result.
