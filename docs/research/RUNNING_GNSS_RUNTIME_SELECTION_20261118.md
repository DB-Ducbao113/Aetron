# Running step length and GNSS runtime selection (2026-11-18)

Supersedes the Running and GNSS default-selection limitations in
SCIENTIFIC_RUNTIME_ALIGNMENT_20261118.md. Changes apply to the ekf worktree,
not the redesign checkout. No commit, push, backend deployment, or device
validation was performed.

## Running: research-based model integrated

Renaudin et al. (2012), Eq. 8, DOI 10.3390/s120708507:
L = h * (a * f_step + b) + c, metres per individual step, height in metres,
frequency in Hz. The original pedestrian equation structure is reused with
new Running-specific coefficients, not represented as an original published
running equation. The fitting source is Fukuchi et al. (2017),
DOI 10.7717/peerj.3298, RBDS DOI 10.6084/m9.figshare.4543435.v5.
All 84 force files for the original 28 runners and three treadmill speeds
(2.5, 3.5, 4.5 m/s) were downloaded and MD5-checked against source metadata.
Height/sex come from RBDSinfo metadata, not assumed.

Each 30-s force record is sampled at 300 Hz. Vertical force is filtered with
a fourth-order 10 Hz Butterworth (SciPy sosfiltfilt), threshold 20 N. A complete
contact must last at least 100 ms to suppress spurious crossings (additional
processing choice); 1,889 crossings rejected and 7,086 reference inter-contact
intervals retained. Cadence means by speed: 161.57, 171.29, 183.51 steps/min.
Reference mean step length = treadmill belt speed / force-derived step
frequency. This reference shares cadence with the model input; it is not
an independent spatial foot-contact measurement. Belt speed is not supplied
as a model predictor.

Leave-one-subject-out evaluation; each participant's three trials held out
together. Metrics are equally weighted trial means (84 trials), not per-step
or device accuracy.

| Model | MAE (cm) | RMSE (cm) | Trial MAPE (%) |
|---|---:|---:|---:|
| Legacy height/sex multiplier | 20.4190 | 23.6512 | 17.3014 |
| Renaudin structure, RBDS LOSO | 17.7979 | 20.9354 | 15.2855 |

MAE reduction 12.84%. Speed-specific MAE old/new: 2.5 m/s 24.47/19.46 cm;
3.5 m/s 6.53/12.15 cm (regression); 4.5 m/s 30.26/21.78 cm.
Full fit for runtime a=0.3210564550962659, b=0.7252540911327735,
c=-1.680950042382748. All 84 fold predictions, reference lengths, MAEs
and Dart coefficient parity independently checked.

ResearchRunningStepLength is used by the step-derived distance path;
valid height 162.7–187.2 cm and integer cadence 143–223 spm, finite positive
prediction only. Otherwise retain the existing fallback. GPS-primary
outdoor distance is not replaced. OS cadence differs from force-derived
trial cadence; there is no device parity or slow jog validation. The
treadmill speed range is 9–16.2 km/h. The narrow training domain and
3.5 m/s regression prevent claiming universal improvement.

## GNSS: corrected public dataset comparison

TU Wien, DOI 10.48436/y6gxm-6mg51; five routes and two phones, 3,396 raw
fixes, 2,694 exact common UTC phase-RTK timestamps. All comparison errors
use unrounded geographic distances. Distances in the manifest are
adjacent, matched, one-second epoch segment statistics, not full workout
distance error. Accuracy metadata is a proxy (not native phone accuracy).
Component replay does not include WorkoutTrackingEngine acceptance/handover.

| Comparison | Position RMSE (m) | Adjacent segment distance error (%) |
|---|---:|---:|
| Raw | 2.113212 | 4.150474 |
| EKF core | 2.185049 | 3.366409 |
| AEKF core | 2.179894 | 3.353052 |
| P01 + EKF core | 2.185049 | 3.366409 |
| P01 + enhanced quality gate + EKF core | 2.185049 | 3.366409 |
| P01 + AEKF core | 2.179894 | 3.353052 |
| GpsSmoothingService EKF | 11.528939 | 14.894023 |
| GpsSmoothingService AEKF | 17.070234 | 16.535314 |

P01 accepted all 3,396 fixes with or without the enhanced gate; this dataset
does not establish a benefit from live preprocessing. AEKF core gain is
tiny and reverses for the smoothing service. Raw position RMSE is better
than either filter core. Service replay supplies every raw fix to the service,
not the complete production pipeline. Consequently P01/P02 run in shadow
by default (diagnostics only); live correction/preprocessing and enhanced
quality gate remain off. P02 shadow emits quality/NIS diagnostics without
altering output. Shadow parity is explicitly tested.

P03 masked-gap replay: retain every fifth raw fix, batch preprocess and
reconstruct offline, compare 2,150 common interpolated positions to RTK.
Linear RMSE 2.107651 m; PCHIP RMSE 2.124616 m. Select linearChord by default,
not because the difference establishes statistical superiority but because
it is simpler and slightly better on this benchmark. PCHIP remains an
explicit alternative. PCHIP limiter clips opposing tangents before slope
limiting, and severe gaps take precedence over stationary labels.

P03 is enabled at outdoor session finalization only, for eligible GPS-only
routes, display geometry only, with at least two raw fixes and no known
split, synthetic route, or adaptive steps; the recording provider disables
it after pause or any step-based distance and at checkpoints. Batch P01 is
used as a prerequisite without altering official metrics. Dense routes keep
the existing geometry; gaps beyond 15 seconds remain indeterminate. Tests
assert no official distance, mean speed, calorie or filtered-route changes.
Local reconstructed geometry can subsequently be superseded by the existing
server route workflow; cross-device persistence is not validated.

## Replay and verification

Run from the ekf worktree:
```sh
../../auto_pause_research_env/bin/python tooling/benchmark/renaudin_running_rbds.py --data ../../rbds_research_2026 --out tooling/benchmark/results/renaudin_running_rbds_20261118
flutter test --no-pub tooling/benchmark/gnss_phase_selection_test.dart
flutter test --no-pub
flutter analyze --no-pub
```

Results: tooling/benchmark/results/renaudin_running_rbds_20261118/ and
tooling/benchmark/results/gnss_phase_selection_20261118/.
Targeted Flutter selection 67 passed, 3 failed (missing historical GPS fixture
CSVs). Public TU Wien component replay passed. Full Flutter 550 passed,
1 skipped, 13 failed (same absent GPS/Isar fixtures as previous baseline).
Analyzer clean; git diff --check clean. No fabricated fixtures or skipped
assertions. No change to Auto-Pause research or main redesign checkout.

## Superseding decision

P01 and P02 are now active by default, not shadow-only. See [P01_P02_ACTIVE_RUNTIME_20261118.md](P01_P02_ACTIVE_RUNTIME_20261118.md) for the active replay and limitations.
