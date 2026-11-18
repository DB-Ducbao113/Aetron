# Aetron — scientific runtime and evidence closure, 2026-11-18

Branch/worktree: ekf (tooling/data/worktrees/stride-ekf). This is the current
decision record, superseding older runtime selections in linked reports.
A passing software test is not evidence of physical measurement accuracy.
“Author data” means a verified publication-associated dataset, not an exact
reproduction of the publication's algorithm or protocol.

## Evidence and runtime matrix

| Component | Current implementation and basis | Public evidence | Scope / measured result |
|---|---|---|---|
| P01 | Active causal kinematic preprocessing + batch checks; adaptations of Li 2025 (10.3390/electronics14234694) and Zheng (10.1145/2743025, 10.1145/1526709.1526816) | Independent TU Wien, 10.48436/y6gxm-6mg51 | No extra rejection on matched cohort; original experiment not reproduced |
| P02 | Active NIS adaptive 4-state EKF; Sukhenko survey 10.3390/app152212304 and standard Kalman theory | Same TU Wien replay; 3396 fixes, 2694 common phase-RTK epochs | Raw RMSE 2.113212 m; legacy service EKF 10.180802 m; active P01+P02 3.431657 m coordinate bearing or 3.718451 m exported course. Adjacent-distance error 4.150474%, 11.551362%, 1.336400%, 2.702035% respectively. This is not independent confirmation after tuning; raw position RMSE remains better. |
| P03 | Default monotonePchip, per-pair Hermite with Fritsch-Carlson limiter (10.1137/0717021); display/archive only | TU Wien artificial gaps, 2150 held-out interior epochs | Linear 2.107651 m vs Hermite 2.124616 m RMSE. Selection follows research direction, not a performance win. Czerwiński 2026 (10.3390/app16188972) original GPX/checkpoint arrays absent from public supplement; known-route method is NOT reproduced. No claim of global C1 or verified bound on entire curve speed. |
| Indoor/outdoor | DeepIOD-inspired C-Mobile using actual available feature window (10.3390/s24165125); hint only | CIOD 10.17863/CAM.82668, 201731 rows | Macro-F1 69.57%, coverage 99.94%, evaluated accuracy 73.63%, outdoor recall 45.3%. Adapted model, not original checkpoint. No device/transition validation. |
| Walking steps | Oxford WPD (10.1109/EMBC.2018.8513319), causal Dart detector; measured OS fallback | Author validation data, 12 traces, 242411 samples | 4107 reference steps, 4236 detected; macro count accuracy 93.1646%, WAPE 6.8420%; author recorded 93.3582% and 6.6472%. Back-pocket trace +46.65%; native hardware outperformed detector on paired subset. Not event classification accuracy. |
| Walking cadence | Causal raw detector stream and six-second benchmark | Oxford author data, 2347 windows | MAE 12.092 spm vs reference-device increments; not independently confirmed heel strikes or full production cadence parity |
| Running steps/cadence | Active Xu 2022 causal variable-window/adaptive-threshold detector; OS fallback, existing cadence service | Xu Group 3 source data (10.3390/rs14122926), 5 traces, 25,034 samples, 1,280 reference steps | Actual Dart and runtime replay both 1,279 steps, macro accuracy 98.69%, WAPE 1.17%; full-session count/min MAE 2.02 spm. Oxford comparator 85.46%; author Xu 98.94%. No instantaneous event reference. See [current Running report](XU_RUNNING_RUNTIME_20261118.md). |
| Walking step length | Renaudin Eq.8 structure (10.3390/s120708507), fitted coefficients | SLEDataset2 (10.3390/s21103527), 10 subjects, 114 sessions | LOSO session-mean MAE 9.506 to 8.612 cm; independent dataset, not original Renaudin experiment |
| Running step length | Same equation structure, running fit | Fukuchi RBDS (10.7717/peerj.3298), original force files DOI 10.6084/m9.figshare.4543435.v5, 28 runners, 84 trials | LOSO trial MAE 20.419 to 17.798 cm; treadmill/force reference, not independent smartphone step-distance test |
| Missing cadence | Cohort mean frequency conditional on available height; population mean step length if height absent | SLEDataset2/RBDS LOSO | Known-height MAE walking 9.05 cm, running 20.89 cm; missing-height 9.23 and 20.41 cm. Not measured cadence; running fallback does not uniformly improve baseline. |
| Energy | 2024 Adult Compendium (10.1016/j.jshs.2023.10.010), standard MET x kg x moving hours | Published activity MET table; Dart/TS regression parity | Gross estimated kcal, not subject-specific calorimetry validation |

## Client/server integrity

* Raw step observations retain actual timestamp and source. Cycling does not
  produce steps; GPS distance never manufactures missing step observations.
* Separate GPS and step distances; split discontinuous accepted GPS routes,
  never bridge a gap or add overlapping GPS/step distance again. Final summary
  reflects finalization distance/steps/laps.
* Archive client claim separately from canonical server verdict. Server retains
  bounded mixed totals only when raw GPS/step counts, decomposition, speed
  bounds and clean corroborated geometry are consistent. It labels them
  client_reported_segmented_unverified, exact_replay=false; step distance and
  source-interval overlap are not independently verified. Pure bounded AEKF
  is likewise not exact server replay. A rejected claim does not replace the
  server raw verdict.
* P03 can appear in local provisional display; reconstructed geometry is
  retained in the scientific archive, not server matched_route_json or
  official map-matched distance. No true map matcher is configured. Completed
  server status/empty geometry wins over stale local display; pending status
  cannot erase client audit.
* Raw upload completeness precedes job enqueue; pending sessions remain
  retryable. Expected raw fix count follows the DB unique conflict key
  (timestamp, latitude, longitude within workout); observation count retained
  separately. SQL protects finalized artifacts against delayed/repeated client
  requests. Atomic queued-to-running claims; route correction depends on
  completed deterministic finalization. No unsupported identity route matcher.

## Reproducibility and detailed audit

- [P01/P02 active runtime](P01_P02_ACTIVE_RUNTIME_20261118.md); manifests
  tooling/benchmark/results/gnss_p01_p02_active_20261118 and gnss_phase_selection_20261118.
- [P03 original dataset access audit](P03_ORIGINAL_DATASET_ACCESS_AUDIT_20261118.md);
  actual public supplement inspected and hashed. No original data fabricated.
- [Oxford author validation](OXFORD_WPD_AUTHOR_VALIDATION_20261118.md);
  [external raw IMU replay](OXFORD_WPD_RAW_STEP_RESEARCH_20261118.md).
  Dart runner tooling/step_benchmark/run_oxford_author_validation.dart,
  outputs tooling/step_benchmark/results/oxford_author_validation.json.
- [IOD runtime alignment](IOD_LIVE_INPUT_ALIGNMENT_20261118.md);
  [workout integration](IOD_WORKOUT_INTEGRATION_20261118.md).
- [Walking fit](SCIENTIFIC_RUNTIME_ALIGNMENT_20261118.md);
  [Running fit](RUNNING_GNSS_RUNTIME_SELECTION_20261118.md);
  tooling/benchmark/renaudin_step_length_replay.py,
  renaudin_running_rbds.py and renaudin_fallback_replay.py; manifests under
  tooling/benchmark/results/renaudin_*_20261118.
- [Compendium](COMPENDIUM_CALORIE_MODEL_20261117.md).
- Prior [stride paper replay](STRIDE_PAPER_REPLAY_20261118.md) is exploratory,
  not the selected runtime path.

## Validation

- Flutter full suite after integration: 573 passed, 13 failed due to missing
  historical GPS/device fixtures, 3 skipped. Subsequently added unique-fix
  conflict-key regression: scientific_result_integration_test.dart 4/4 pass
  (the full suite was not rerun after this one additional regression).
- Existing missing inputs: exports/research_7_sessions/aetron_7_new_sessions_raw.csv,
  exports/aetron_raw_gps_combined.csv, exports/research_7_sessions/ios_device_backup_20261105,
  /tmp/iphone_post_launch/Documents/default.isar,
  /tmp/iphone_live_check/Documents/default.isar. No substitutions or assertion suppression.
- Flutter analyzer clean; git diff --check clean.
- Deno: 19 deterministic-finalize-worker + 2 route-correction-worker tests pass;
  deno check both workers pass. Migration 202611180001_scientific_client_result.sql
  applied twice to disposable PostgreSQL 17.11 against relevant baseline schema
  with mock JWT auth helpers/roles; scientific_client_result_test.sql passes
  and rolls back. This is not a Supabase HTTP integration test or deployment.
- Full suite regenerates docs/algorithms/route_points_dump.json visualizer data.

## Open evidence / release gates

Original publication reproduction is NOT universally closed. P01/P02 use an
independent dataset, P03 lacks original arrays, Renaudin coefficients are fitted
adaptations, IOD uses adapted feature/model alignment, Running raw smartphone
step detection has been implemented and replayed on the constrained author
cohort (no unconstrained/event-level validation), and MET lacks
individual calorimetry. Raw sensor/device tests and IOD feature availability
(especially iOS light), CIOD license review, and independent post-tuning GNSS
evaluation remain open.

Backend still lacks transactional publication across its separate requests and
full Supabase HTTP integration. Exhausted raw-upload deferral attempts require
a new retry enqueue; failed deterministic jobs leave dependent correction
deferred. Legacy claims with duplicate raw counts may fail consistency checks.
Existing raw schema lacks per-step features and source handover timeline.
No exact server replay or production performance guarantee is asserted.

No Auto-Pause change, commit, push, production deployment, or real-device
validation. Completion applies to the local implementation and available
evidence, not the missing external-data or release gates.

## Scope clarification — author-data running benchmark

The previous missing Running dataset statement is superseded by the Xu Group 3
author-data replay above. New collection on the project owner’s phone is not a
mandatory thesis algorithm benchmark gate. Device and deployment verification
are separate limitations, not required for offline benchmarking. Running
native OS-count parity and exact original Xu method reproduction remain unverified.
The Xu adaptation is now active for Running; see XU_RUNNING_RUNTIME_20261118.md.
Latest full Flutter suite: 579 passed, 13 existing missing-fixture failures, 3 skipped.
The new runtime replay matches all five detector counts.
