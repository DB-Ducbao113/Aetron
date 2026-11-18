# P01/P02 active runtime alignment — 2026-11-18

This supersedes the shadow-only decision in RUNNING_GNSS_RUNTIME_SELECTION_20261118.md.
Research selection is an explicit project requirement; benchmark results characterize
the selected method and do not decide whether it is enabled.

## Active client pipeline

Raw GNSS persistence -> existing input/continuity safety -> P01 streaming
kinematic preprocessing -> P02 NIS adaptive GNSS correction within 4-state EKF
-> corrected display route -> local finalizer (segmented filtered distance,
P01 batch fallback). P03 remains offline display-only. Raw points remain immutable.

- P01 source basis: Li et al., Electronics 2025, DOI 10.3390/electronics14234694;
  Zheng, ACM TIST 2015, DOI 10.1145/2743025; Zheng et al., WWW 2009,
  DOI 10.1145/1526709.1526816. Mode-specific physical velocity/acceleration
  and accuracy thresholds, median-window statistics, dwell and outage handling
  are Aetron adaptations, not paper-original numerical parameters. Median and
  dwell clustering are batch operations; the streaming path applies the causal
  kinematic checks.
- P02: Sukhenko et al., Applied Sciences 2025 (survey), DOI
  10.3390/app152212304, with standard innovation testing and Kalman math from
  Groves and Bar-Shalom et al. Retain NIS=innovation^T S^-1 innovation,
  2-DOF chi-square 95% and 99.9% gates (5.991, 13.816), covariance inflation,
  turn scaling and low-speed heading deadband. Mode-specific thresholds,
  reacceptance rule and numerical parameters are Aetron adaptations, not a
  reproduction of a per-satellite correction method.
- Compile-time defaults: PREPROCESSING true, GNSS_CORRECTION true, both
  shadow flags false. Enhanced Mobile-GVIO-derived gate remains disabled.
  Explicit rollback overrides are retained. P03 default unchanged.

## Integration tuning

1. Restore P01 bearing history through the streaming gate (previously null).
2. Preserve legacy safety rejection and distinguish actual raw signal outage
   from elapsed accepted-fix age; rejected recovery samples cannot become route
   anchors merely because P01 marked a temporal gap.
3. In active P02 mode, treat short displacement as stationary only if speed
   <=0.8 m/s (or implied speed if sensor speed unavailable); remove the 1 Hz
   duration-based false-stationary condition. Use unrounded distances for that
   decision. Keep internal filter updates even if a stationary display is frozen.
4. Prefer native finite course in [0,360) when heading accuracy is positive
   and <=45 degrees (engineering gate); use coordinate bearing only after
   >=2 m displacement. Reset smoothing state for explicit segment breaks,
   and reset streaming/filter histories for manual resume.
5. Local finalizer uses filtered route then P01 clean distance for outdoor
   sessions with >=2 raw fixes; indoor and no-data cases retain their
   existing fallback. Live session distance is still accumulated from accepted
   raw segment distances, not the same downsampled corrected display geometry;
   local saved distance can differ. Server deterministic-finalize worker
   independently recomputes from raw GNSS; its P01/P02 algorithm parity
   is not implemented in this change. Do not claim cloud metric parity.

## Public dataset replay

TU Wien DOI 10.48436/y6gxm-6mg51, 5 routes x 2 devices, 3396 raw fixes,
2694 same-time phase RTK matches. Shared production validation, P01
decision resolver and smoothing service; no UI, IOD, sensor lifecycle or cloud
replay. Hold prior estimate for rejected observations. 2574 accepted route
fixes in each variant, no additional P01 rejections or route breaks on this
cohort. Dataset uses proxy accuracy; native course accuracy is unavailable.

| Method | Position RMSE (m) | Mean adjacent matched path distance error (%) |
|---|---:|---:|
| Raw | 2.113212 | 4.150474 |
| Legacy service EKF | 10.180802 | 11.551362 |
| P01 + legacy EKF | 10.180802 | 11.551362 |
| P01 + tuned P02 (coordinate bearing fallback) | 3.431657 | 1.336400 |
| P01 + tuned P02 (exported course treated as valid) | 3.718451 | 2.702035 |

The aggregate distance metric is contiguous matched one-second path length
error, not full workout error. Motion/heading integration changes accompany
P02; the comparison is not a pure AEKF-only ablation. No independent
holdout was established for these tuning changes. The same cohort has been
used for exploratory diagnosis, so results are descriptive. Raw GPS retains
the lower position RMSE, and the course branch assumes usable course.
The data do not independently verify all sports, iOS sensor accuracy, or
improved real workout metrics.

Replay:
```sh
flutter test --no-pub tooling/benchmark/gnss_p01_p02_active_replay_test.dart
flutter test --no-pub test/gnss_research_runtime_selection_test.dart test/gnss_correction_runtime_integration_test.dart test/trajectory_preprocessing_runtime_integration_test.dart test/gps_smoothing_service_test.dart
flutter analyze --no-pub
```
Manifest: tooling/benchmark/results/gnss_p01_p02_active_20261118/manifest.json.

Focused tests: 21 passed. Public dataset replay: 1 passed. Analyzer clean.
Full Flutter suite: 551 passed, 1 skipped, 14 failures caused by absent
historical GPS CSVs or Isar device fixtures/directories (including an additional
missing environment directory in isar_open_investigation_test.dart this run).
No fixture fabrication or suppressed assertions. The final historical
EKF/Fix Alpha comparator explicitly disables P02 to preserve baseline meaning.
No deploy, commit, push or real-device verification. Worktree ekf only.
