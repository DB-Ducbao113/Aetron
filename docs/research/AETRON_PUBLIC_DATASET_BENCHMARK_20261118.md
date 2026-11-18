# Aetron — public dataset benchmark (2026-11-18)

Branch ekf, base 2d42c57 plus local research implementation changes.
All results below were replayed with the current working algorithms. No
parameter tuning based on this run. These are algorithm-level public-data
experiments; physical phone collection is not required for this scope.
The GNSS replay shares production services, not the entire app lifecycle.
Walking and Running step-count replays invoke the actual runtime adapter
and StepTrackingService. No aggregate app accuracy is defined.

## GNSS and reconstruction

TU Wien public data DOI 10.48436/y6gxm-6mg51. Ten walking traces on two
devices, 3396 raw fixes; 2694 exact common phase-RTK epochs. Same evaluation
mask for all methods. Position RMSE and MAE are in metres. Distance error
is mean per-trace relative absolute error on contiguous matched epochs,
not official whole-workout distance error.

| Pipeline | Position RMSE m | MAE m | Adjacent distance error % |
|---|---:|---:|---:|
| Raw GPS | 2.113 | 1.886 | 4.150 |
| Legacy EKF | 10.181 | 7.400 | 11.551 |
| P01 + legacy EKF | 10.181 | 7.400 | 11.551 |
| P01 + AEKF (coordinate heading) | 3.432 | 2.514 | 1.336 |
| P01 + AEKF (exported course) | 3.718 | 2.563 | 2.702 |

P01 (Li 2025, 10.3390/electronics14234694; Zheng 2015,
10.1145/2743025) component replay retains 3396/3396 points. The clean cohort
does not establish outlier detection sensitivity. P02 (Sukhenko 2025,
10.3390/app152212304, and standard Kalman theory) improves distance error
versus raw and legacy EKF on this cohort, but position RMSE remains worse
than raw. Coordinate heading is the available fallback; native heading
accuracy is absent so the exported-course result is conditional.
Not an independent post-tuning cohort or exact reproduction of a survey.
No separate running/cycling GNSS cohort in this evaluation.

P03: same 2150 artificially masked interior epochs, linear chord RMSE
2.108 m / MAE 1.881 m, active monotone Hermite 2.125 m / 1.893 m.
The latter is the research-based default, not a numerical improvement.
Fritsch-Carlson DOI 10.1137/0717021. Original Czerwiński data
(10.3390/app16188972) not available in supplement; independent masked-gap
protocol, not exact paper reproduction. Display-only reconstruction.

## Steps and cadence

Oxford WPD (10.1109/EMBC.2018.8513319) author validation data,
commit 922cc0d8511a7189f7a667d173c21e9472729603: 12 traces, two
participants, six placements, 242411 samples. 4107 reference steps.
Runtime 4236 steps, mean per-trace count accuracy 93.1646%, WAPE 6.8420%.
Author recorded algorithm 4220, accuracy 93.3582%, WAPE 6.6472%.
Six traces with recorded hardware reference: hardware accuracy 99.03%,
Aetron 97.69% on the identical subset. Worst back-pocket error +46.65%.
Actual runtime cadence MAE 11.8628 spm over 2347 one-second evaluation
points against trailing six-second reference counter increments. Separate
detector-only count-window MAE 12.0920 spm; not the same estimator.
Reference increments are not independent heel-strike event times.
All 12 runtime counts match detector totals, no OS fallback.

Xu Running (10.3390/rs14122926), author data commit
3da2d6e683f56e39eb74cda79eaa8ee93e033d6c, Group 3, five constrained
traces, 25034 samples. Reference 1280, runtime 1279 steps, mean count
accuracy 98.6907%, WAPE 1.171875%; session count/min MAE 2.0234 spm.
Reported paper Xu 98.94%, Stepcount 89.92%; measured Oxford comparator
85.46%. The five runtime totals match detector counts. No instantaneous
cadence ground truth. Count accuracy is 100*(1-abs(pred-ref)/ref);
WAPE is 100*sum(abs(pred-ref))/sum(ref). No claim of original code parity.

## Environment classification

DeepIOD-inspired C-Mobile (10.3390/s24165125), CIOD public data
10.17863/CAM.82668, zero-based sessions 72..84, all 201731 rows.

| Actual | Predicted indoor | Predicted outdoor | Unknown |
|---|---:|---:|---:|
| Indoor | 110985 | 7880 | 99 |
| Outdoor | 45278 | 37471 | 18 |

Evaluated 201614, abstained 117; coverage 99.94%, evaluated accuracy
73.63%, macro-F1 69.57%, outdoor recall 45.3%. C-Replay eight-channel
imputed-sound comparator 90.59% accuracy / 90.17% macro-F1 is NOT
the deployed live classifier. No environment transition labels or
mode-switch accuracy measurement. No claim of original DeepIOD reproduction.

## Step length

Renaudin Eq.8 (10.3390/s120708507), separately fitted Walking and Running
adaptations. Walking: SLEDataset2 (10.3390/s21103527), 10 subjects,
114 sessions, 98320 reference cycles; reference averaged step length =
cycle length/2. Spectral cadence feature, not actual app cadence.
Running: Fukuchi RBDS (10.7717/peerj.3298; dataset
10.6084/m9.figshare.4543435.v5), 28 runners, 84 trials, 7086 force-derived
intervals. Reference belt speed/cadence shares cadence with predictor.

| LOSO (held-out subject) | Legacy MAE cm | Research MAE cm | Research RMSE cm | Research session MAPE % |
|---|---:|---:|---:|---:|
| Walking | 9.506 | 8.612 | 10.877 | 12.013 |
| Running | 20.419 | 17.798 | 20.935 | 15.286 |

Missing-cadence fallback LOSO MAE walking 9.054 cm (height known),
9.233 cm (height absent); running 20.892 and 20.409 cm. The fallback
source CSVs match the freshly generated feature exports numerically
(1e-12 tolerance; walking floating point serialization differs).
Running fallback with height does not outperform legacy.

Additional frozen Dart runtime replay with supplied rounded cadence and height:
Walking 114/114 adaptive, MAE 7.485 cm; Running 84/84 adaptive,
MAE 17.065 cm. These are descriptive same-training-cohort results,
NOT independent accuracy; use LOSO above for primary evaluation.
Neither evaluation is end-to-end smartphone distance.

## Energy

2024 Adult Compendium DOI 10.1016/j.jshs.2023.10.010, published MET codes
and gross kcal = MET * kg * moving hours. Formula/lookup tests include
17 activity-speed rows. No independently measured kcal ground truth,
so no calorie MAE or accuracy claim.

## Reproduction

From ekf worktree, outputs in tooling/benchmark/results/app_benchmark_20261118:
```sh
out=tooling/benchmark/results/app_benchmark_20261118
flutter test --no-pub --concurrency=1 tooling/benchmark/gnss_phase_selection_test.dart tooling/benchmark/gnss_p01_p02_active_replay_test.dart tooling/step_benchmark/xu_running_runtime_replay_test.dart --reporter expanded
AETRON_CIOD_CSV=../../ciod/Data_Supporting_IOD_DL_MTSC_JIoT.csv AETRON_CIOD_CAP=0 flutter test --no-pub test/iod_ciod_live_input_benchmark_test.dart --reporter expanded
dart run tooling/step_benchmark/run_oxford_author_validation.dart
dart run tooling/step_benchmark/run_xu_running_adaptation.dart
flutter test --no-pub tooling/step_benchmark/oxford_walking_runtime_replay_test.dart
../../auto_pause_research_env/bin/python tooling/benchmark/renaudin_step_length_replay.py --data ../../sle_research_2026/SLEDataset2 --out "$out/walking"
../../auto_pause_research_env/bin/python tooling/benchmark/renaudin_running_rbds.py --data ../../rbds_research_2026 --out "$out/running"
../../auto_pause_research_env/bin/python tooling/benchmark/renaudin_fallback_replay.py
dart run tooling/benchmark/step_length_runtime_replay.dart
flutter test --no-pub --concurrency=1 test/workout_data_consistency_test.dart test/stationary_calories_and_gps_gaps_regression_test.dart test/research_walking_step_length_test.dart test/research_running_step_length_test.dart test/scientific_result_integration_test.dart --reporter expanded
flutter analyze --no-pub
```

78 selected Flutter tests passed across these runs (including 73 formula
and integration tests), standalone replays completed and analyzer clean.
Historical full-suite result remains 579 passed, 3 skipped, 13 failures
from missing historical fixtures; not rerun for this benchmark.
No production algorithm changes, deployment, or personal phone recording.
No claim of whole-app accuracy, pure paper-original reproduction across
all components, or exact backend replay. See SCIENTIFIC_CLOSURE_20261118.md
for source constraints and previously verified integration behavior.
