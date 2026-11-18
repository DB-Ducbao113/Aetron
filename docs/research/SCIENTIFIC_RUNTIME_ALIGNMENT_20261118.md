# Scientific runtime alignment — ekf, 2026-11-18

## Walking step length

Renaudin et al., Sensors (2012), DOI 10.3390/s120708507, Eq. 8:
single step length = h * (a * f + b) + c; h in metres, f in steps/s.
The authors obtain frequency through spectral analysis of handheld accelerometer
signals. Aetron fits the published equation structure independently, not the
authors' universal coefficients or their complete detection/classification system.

Public data: SLEDataset2, DOI 10.3390/s21103527, repositoryadmin/SLERepository,
commit 6b8a8d475e6984b4d2744ff31fe4ad254cf76896. 114 labeled walking
sessions across 10 participants, 98,320 gait-cycle reference labels. Each
session's mean reference step length is half its mean full-cycle stride.
No per-step alignment or cadence labels are fabricated. The independent cadence
feature is estimated from trailing 256-sample spectral windows (100 Hz, hop 128),
summed demeaned tri-axis power in 0–3 Hz, then the 1.4 Hz discriminator of
Renaudin Eq. 11. These preprocessing choices are an adaptation; the full
reference recording is reduced to a step-frequency-weighted session mean.
No reference step count enters the feature calculation.

Leave-one-subject-out fits on the other nine people; one equally weighted
record per session. This is a cross-validation on an already examined dataset,
not independent external validation. Results:

| Method | MAE of session mean step length (cm) | RMSE (cm) | Mean conditional session distance error (%) |
|---|---:|---:|---:|
| Original height/gender formula | 9.506 | 11.734 | 12.988 |
| Renaudin Eq. 8 fitted on other subjects | 8.612 | 10.877 | 12.013 |

Slow MAE 10.65 -> 9.72 cm, normal 5.93 -> 7.42 cm (regression),
fast 12.19 -> 8.82 cm. Distances assume the source step count is correct;
not end-to-end phone distance accuracy. No significance or running claim.

Final coefficients fitted to all 114 sessions: a=0.13276343484996747,
b=0.02165970371270505, c=0.27545807799439775. Dart constants checked against
manifest. Runtime uses current OS/windowed cadence (SPM/60), not the spectral
feature. Only Walking, height 160–188 cm and cadence 94–144 SPM are admitted;
these bounds derive from the session feature extrema and are an engineering
guard, not independently established physiological limits. Missing/out-of-range
inputs and Running retain original fallback; Cycling unchanged. Existing
walking step-fallback path calls the new estimator per positive step delta,
with no retrospective application to previous steps. Indoor finalization
preserves the accumulated distance. Outdoor-ending mixed sessions keep the
existing GPS-only validation policy; adaptive contributions can be lost on
finalization. Backend cannot independently replay adaptive steps from its raw
intervals; no claim of end-to-end mixed-mode parity. Local audit records the
number of adaptive steps; current remote route metadata schema/path does not
preserve that field. Device-level cadence parity and battery/field accuracy
have not been validated.

The earlier Vezočnik 2021/2022 ASLE equation replay is retained as research
evidence only; it needs stride-segmented acceleration and was not selected
for live tracking.

## Calories

2024 Adult Compendium, DOI 10.1016/j.jshs.2023.10.010: standard MET * kg *
moving hours, published code lookup for Walking, Running, Cycling. Recovered
from the previous WIP stash selectively. Both Dart and deterministic-finalize
worker now implement the same mapping. Explicit zero moving time is zero,
not elapsed time; missing moving time retains legacy fallback. Backend indoor
moving time respects a non-null recorded value. Final values use current
estimate rather than historical running maximum for these three modes; estimates
can decrease when distance/mean speed is corrected. Summary label now says
estimated kcal. This is gross estimated exercise energy, not net active kcal
or measured calorimetry. Legacy non-distance model remains out of scope.
The previous COMPENDIUM_CALORIE_MODEL_20261117.md describes the prior WIP;
this document supersedes its moving-time/ceiling limitations and clarifies
legacy non-distance behavior. MET mapping remains a group-level approximation,
with terrain/age/speed assumptions and discrete bands.

## Reproducibility and scope

Run from worktree:
```sh
python3 tooling/benchmark/renaudin_step_length_replay.py --data ../../sle_research_2026/SLEDataset2 --out tooling/benchmark/results/renaudin_sle_20261118
flutter test test/research_walking_step_length_test.dart test/tracking_logic_test.dart test/workout_recording_architecture_test.dart test/workout_data_consistency_test.dart test/stationary_calories_and_gps_gaps_regression_test.dart
deno test --allow-env --allow-net backend/supabase/functions/deterministic-finalize-worker/index_test.ts
flutter analyze
```

The CSV/manifest contain subject fold coefficients, input source hashes and
subgroup scores. Independent arithmetic check passed for every holdout
prediction and both MAEs; Dart coefficient parity passed. No changes to
EKF/AEKF/IOD defaults, Step/Cadence acquisition, Auto-Pause research, redesign
checkout, or source stash. No backend deployment, commit or push.

## Final verification

- Focused Flutter suite: 93 passed, 0 failed.
- Deterministic finalize worker Deno suite: 10 passed, 0 failed.
- Existing ASLE equation replay Python tests: 3 passed, 0 failed.
- Full Flutter suite (after final integration): 542 passed, 1 skipped, 13 failed.
  All 13 reported failures are missing input fixtures, not assertion
  mismatches in the new estimator or MET computations: 10 GPS benchmark
  tests require the two absent exports CSVs, and 3 Isar inspection tests
  require an absent device backup directory or two missing /tmp device DBs.
  Those fixtures were also absent in the main checkout. No fixtures fabricated
  and no failing tests suppressed.
- Final flutter analyze --no-pub: no issues.
- git diff --check: clean.

## Subsequent update

Running and GNSS runtime configuration have been revised in [RUNNING_GNSS_RUNTIME_SELECTION_20261118.md](RUNNING_GNSS_RUNTIME_SELECTION_20261118.md). Its selection and evaluation supersede the corresponding earlier limitations above.
