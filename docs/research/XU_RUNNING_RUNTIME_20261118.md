# Xu Running — active runtime adaptation and author-data evaluation

## Research method

Xu et al. (2022), Remote Sensing 14, 2926,
DOI 10.3390/rs14122926, sections 2–3 and Table 1.
Aetron implements the method direction in Dart, not the unpublished original
source. The unchanged Oxford WPD comparator remains the Walking detector.

Runtime: lib/core/services/sensor/xu_running_step_detector.dart.
The predeclared implementation (before first evaluation of this detector):

- Raw XYZ magnitude, including gravity; interpolate onto a 50 Hz time grid.
- Unity-DC-gain eleven-tap Hamming-windowed sinc low-pass FIR, nominal
  5 Hz cutoff, and a parallel 15-sample moving mean; align filter centers
  with 140 ms observation delay. Fixed 50 Hz is an adaptation of the
  paper's use of actual device sampling frequency.
- 256-point real DFT, demeaned FIR samples, updated every second after
  warm-up. Use the dominant non-DC bin; Table 1 chooses 1.6/1.8/3.5 Hz
  boundaries, 10.6/11.0/11.6 m/s² fixed thresholds and 333/286 ms time
  thresholds. Use the Running threshold before sufficient spectral samples.
  Suppress candidates when the spectral frequency exceeds 3.5 Hz.
- One-second peak windows with one sample at each edge. The adaptive
  threshold is the smaller of the fixed threshold and the minimum local
  maximum in the moving-mean window (literal section 3.1 cap rule);
  use fixed threshold when no mean peak is available.
- Select FIR local maxima above threshold. Advance just after the last
  eligible peak, or two samples when there is none. Preserve a pending
  peak across windows, choose the stronger close candidate, and confirm
  only after sufficient processed evidence. This is an explicitly bounded
  streaming interpretation of the paper's cross-window rules, not original
  pseudocode/source parity. No future input is used before its arrival.
- Reset pending evidence at discontinuities >250 ms, invalid inputs or
  manual pause/resume. No retrospective terminal flush. Confirmation delay
  can lose steps near start/stop/pause; the synthetic test checks the
  chosen periodic example, not a universal hardware latency bound.
- No fit, optimization or threshold tuning on Group 3 after implementation.
  Cohort is previously inspected during Oxford comparison; not an independent
  unseen external test. The paper has some underspecified details, so exact
  reproduction of its reported numbers is neither asserted nor required.

## Author-associated data and measured outcomes

Source: https://github.com/jackleenotjackma/StepCountingData
commit 3da2d6e683f56e39eb74cda79eaa8ee93e033d6c.
Five constrained Running traces, Group 3, 25,034 samples, 1,280 counted
reference steps. Metadata and source provenance documented in
XU_RUNNING_AUTHOR_DATA_BENCHMARK_20261118.md. No event timing ground truth,
no unstructured source cohort, no native OS count stream.

Accuracy = 100 * (1 - abs(N_detected - N_reference)/N_reference).
Macro mean across the five records, matching the paper's count-based protocol.

| Subject | Reference | Oxford WPD | Xu adaptation | Xu accuracy (%) |
|---|---:|---:|---:|---:|
| 11 | 240 | 207 | 236 | 98.33 |
| 12 | 343 | 256 | 339 | 98.83 |
| 13 | 230 | 171 | 231 | 99.57 |
| 14 | 183 | 184 | 189 | 96.72 |
| 15 | 284 | 263 | 284 | 100.00 |
| Total | 1280 | 1081 | 1279 | — |

| Method | Macro accuracy (%) | WAPE (%) | Full-session count/min MAE (spm) |
|---|---:|---:|---:|
| Oxford WPD | 85.4585 | 15.703125 | 22.6693 |
| Aetron Xu | 98.6907 | 1.171875 | 2.0234 |
| Reported author Xu | 98.94 | Not derived | Not reported |

The authors' reported Stepcount mean is 89.92%. The reported comparator
numbers are NOT executed implementations in this experiment. Positive and
negative errors cancel in the aggregate; 1 step net error is not the
absolute count error. Total absolute error 15 steps. Sample SD of Xu
per-record accuracy: 1.2753 percentage points. Session count/min divides
each count by full recorded duration, not a validation of instantaneous
cadence or runtime moving-time average cadence.

## Runtime and verification

- StepTrackingService selects Oxford for Walking and Xu for Running when
  the workout sensor controller requests research IMU. The existing
  ResearchWalkingStepSensorAdapter now supports both modes and the selected
  mode owns a single cumulative count. Running requests a 20 ms sampling
  period. Unavailable/stale/too-sparse input (15 consecutive intervals
  >45 ms) triggers the existing one-way OS fallback; its first count
  establishes a baseline without inventing intervening steps.
- Source xuRunning propagates through WorkoutStepUpdate, raw interval
  device_source and final audit xu_detected_step_count. Separate Oxford
  counter retained. Existing cadence service consumes confirmed count
  deltas/availability times; no per-step reference timing is invented.
  Existing Renaudin running step length receives cadence; Cycling workout
  path remains non-step. No Auto-Pause changes.
- All 5 source traces replayed through actual production adapter and
  StepTrackingService with injected timestamped accelerometer samples:
  1279 steps; all five totals match detector replay, all deltas sum to
  active count, source xuRunning, zero OS fallbacks. Last emitted average
  cadence is recorded separately; no claim of instantaneous accuracy.
- 36 focused tests passed, including constant/periodic signals, monotonic
  events, discontinuity/reset, spectral interference, pause/resume, cadence
  decay and OS handover. Full Flutter suite: 579 passed, 3 skipped,
  13 existing failures from unavailable historical CSV/Isar fixtures.
  No new failures. Additional audit assertions and replay verified separately.

Reproduce from ekf worktree:
```sh
dart run tooling/step_benchmark/run_xu_running_adaptation.dart
flutter test --no-pub tooling/step_benchmark/xu_running_runtime_replay_test.dart
flutter test --no-pub test/xu_running_step_detector_test.dart test/research_walking_step_sensor_adapter_test.dart
flutter analyze --no-pub
```

Outputs: tooling/step_benchmark/results/xu_running_adaptation.json and
xu_running_runtime_replay.json. Detector SHA256
d0a146541db08f50012b180d29fc874de65fe211cd166475b61934dca97e79d1.

Running research implementation and author-data count benchmark are complete
within constrained Group 3 scope. This is not clinical event detection,
unconstrained placement generalization, physical-device validation or exact
author-code reproduction. New owner-phone data collection is not required
for this benchmark. No commit, push, deployment or device installation.
