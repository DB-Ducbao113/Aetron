# Raw IMU step counting and cadence — Oxford WPD adaptation (18 November 2026)

**Status:** Implemented and independently replayed; selected only for explicit walking mode. OS counter remains the default and fallback until the workout caller opts in. Not a reproduction of the paper's entire experimental protocol or a phone field-validation claim.

## Source and exact algorithm

Salvi D, Velardo C, Brynes J, Tarassenko L. *An optimised algorithm for accurate steps counting from smart-phone accelerometry*. IEEE EMBC 2018, pp. 4423–4427.
DOI: <https://doi.org/10.1109/EMBC.2018.8513319>. [Oxford project](https://oxford-step-counter.github.io/) supplies published [Java reference](https://github.com/Oxford-step-counter/Java-Step-Counter/tree/dfd079a2678c8d29adbba08de840367f4d4fcd41), MIT license. The paper's sections III.A and Table III specify the magnitude, linear interpolation, Gaussian 13-tap window (normalized SD 0.35), mean-difference scoring window 35 samples, outlier coefficient 1.2 and 200 ms minimum separation. At the paper's 100 Hz processing grid:

1. Raw acceleration magnitude (including gravity): a = sqrt(ax² + ay² + az²). Units m/s². Linear interpolation to a uniform 10 ms grid.
2. Gaussian smoothing: w[j] = exp(-0.5*((j-6)/(0.35*6))²), j=0..12; y[i] = sum(w[j]*a[i+j-6])/sum(w[j]).
3. Mean-difference score: p[i] = sum(y[i]-y[i+k], k=-17..17 excluding 0)/34.
4. Online mean mu and SD s use the identical recurrence in the author's DetectionStage.java (including its n=2 initialization). Candidate requires n>15 and p-mu>1.2s.
5. Cluster nearby candidates within 200 ms, retaining the strongest. Aetron confirms a pending peak when the score-time clock passes its refractory period instead of waiting for the next distinct candidate to arrive. This explicit adaptation avoids indefinite terminal-step delay in the Java reference. It does not flush unknown incomplete windows at session end.

The filter and scoring context require 230 ms of already received right-side samples. Confirmation waits another >200 ms on the scoring timeline; actual event delivery depends on sample arrival, OS scheduling and peak selection. Input with non-finite values or a >250 ms gap resets windows; exactly constant input is protected against floating-point roundoff (1e-9). These are engineering adaptations, not paper-tuned constants. No test-label optimization or parameter fitting was performed. Paper-reported 95% ± 4.5% optimized accuracy and 93% ± 13% real-time validation accuracy concern the authors' own walking data and are not our results. Paper limitations explicitly leave running, stairs, soft surfaces and false-walking activity for further evaluation.

## Raw independent benchmark

Mattfeld, Jesch and Hoover, *Evaluating Pedometer Algorithms on Semi-Regular and Unstructured Gaits*, Sensors 2021, DOI <https://doi.org/10.3390/s21134260>; [public synchronized dataset description](https://sites.google.com/view/rmattfeld/pedometer-dataset), [Clemson dataset site](https://cecas.clemson.edu/~ahoover/pedometer/).

Replay all 90 existing PedEval recordings (30 volunteers × three protocols); each has nine acceleration columns in g, three separate XYZ groups of wearable accelerometers sampled at 15 Hz, synchronized video step annotations in sample indices. Convert acceleration to m/s² by multiplying 9.80665; convert raw row index and annotation index to microseconds by dividing by 15 Hz. All three XYZ groups are reported separately in original column order; the local files lack the original placement-column README, so we do not infer the body-location mapping or select the best group after seeing the results. Annotation labels left/right are locomotor steps; shifts excluded. The dataset includes 56,668 such steps (31,435 regular; 19,917 semi-regular; 5,316 irregular). Previously documented archive-versus-paper annotation count differences remain unchanged.

Actual detector consumes exclusively raw IMU. The video labels are never features and are used only for scoring. Evaluate the complete cohort using fixed published parameters, no training or tuning. One-to-one event matching at ±300 ms is our explicit tolerance (peak time is not guaranteed anatomically identical to heel strike). WAPE is sum(session absolute count error)/sum(session reference count), not aggregate signed bias. Cadence MAE uses causal six-second trailing windows at one-second boundaries, with predicted steps counted at the time they become available, rather than retrospectively backdating them. It characterizes the raw step stream and this fixed-window metric; it does not claim exact equivalence to the app's existing cadence service.

| Raw XYZ group | Protocol | GT steps | Detected | Count WAPE | Event F1 | Cadence MAE (spm) |
|---|---|---:|---:|---:|---:|---:|
| 1 | Regular | 31,435 | 28,110 | 11.46% | 0.8715 | 20.37 |
| 1 | SemiRegular | 19,917 | 18,472 | 11.66% | 0.7321 | 22.20 |
| 1 | Irregular | 5,316 | 20,210 | 280.17% | 0.3737 | 31.85 |
| 1 | All | 56,668 | 66,792 | 36.74% | 0.7253 | 26.00 |
| 2 | Regular | 31,435 | 30,099 | 5.52% | 0.9043 | 14.05 |
| 2 | SemiRegular | 19,917 | 18,894 | 9.76% | 0.7904 | 17.74 |
| 2 | Irregular | 5,316 | 8,549 | 60.82% | 0.6959 | 7.14 |
| 2 | All | 56,668 | 57,542 | 12.20% | 0.8403 | 11.97 |
| 3 | Regular | 31,435 | 30,733 | 2.62% | 0.9125 | 9.23 |
| 3 | SemiRegular | 19,917 | 18,296 | 11.41% | 0.7812 | 16.57 |
| 3 | Irregular | 5,316 | 6,714 | 26.30% | 0.7581 | 3.64 |
| 3 | All | 56,668 | 55,743 | 7.93% | 0.8514 | 8.73 |

The especially high irregular-gait error is a real negative result and confirms sensor placement and non-step movement matter. These are separate body-worn accelerometers, not a phone; resampling 15 Hz to 100 Hz cannot restore lost frequency information. The published study is smartphone walking, but our independent cohort is an external wearable cross-domain check. No physical smartphone accuracy, energy, background suspension, running or cycling validation is claimed.

OxWalk DOI <https://doi.org/10.5287/bodleian:ORQ2abnbR> exists locally only as extracted GT timestamps and metadata (39 sessions), without the original raw acceleration archive/CSV. Therefore OxWalk is not used for this raw detection benchmark. Previous counter-transport tests injected ground-truth counts and cannot be compared against raw detector error. Neither dataset contains actual Android/iOS step-counter outputs in the current local copy. No superiority claim is possible; an OS-vs-detector comparison needs synchronized real device sensor outputs. PedEval public download is documented; explicit redistribution rights for the raw dataset have not been verified. No copy of someone else's dataset is newly included in the change.

Reproduce from the worktree root:

```sh
~/development/flutter/bin/dart run tooling/step_benchmark/run_oxford_raw_imu_benchmark.dart
```

Outputs detailed 270 session-position metric rows and grouped summaries to `tooling/step_benchmark/results/oxford_raw_imu_benchmark.json`.

## Runtime integration

- `OxfordStepDetector` is a bounded-memory single-stream Dart adaptation. Runtime input is `sensors_plus.accelerometerEventStream` (gravity-inclusive, requested 10 ms sampling), not IOD's linear-acceleration magnitudes. It preserves sensor intervals by mapping the first sensor timestamp to wall time and using subsequent event-time differences.
- `StepTrackingService.startTracking(activityType: 'walking', useResearchImu: true)` explicitly selects raw input. A new `StepSensorSource.oxfordWpd` identifies the method. Existing calls/defaults and running/cycling continue to use the OS counter. Workout provider/controller integration is assigned separately to the prime worker.
- Only one source contributes to the step count. Raw startup failure, stream error/closure, inactivity watchdog or repeated inadequate sampling intervals selects OS fallback. First OS cumulative value is a new baseline anchored to already counted research steps; no OS history is added or fabricated. Counts in the handover gap may be lost. Raw availability tests are engineering checks, not published classifier rules. Raw permission policy follows existing service permissions.
- Manual pause/resume clears incomplete detector windows before subsequent motion is processed, and retains existing active/paused step accounting. Pending peaks may be discarded at boundaries. Heartbeats publish zero-delta cadence decay without adding steps. Existing cadence service continues to calculate steps/min from the selected source; the detector does not change the average cadence or step-length formulas.
- Unit tests cover stationary/no synthetic steps, periodic motion, reset/gap/order, source failure/rebase and no duplicates, mode preservation, pause segregation and cessation cadence. No Auto-Pause, shared record provider, UI or unrelated production file is modified.

## Reference software license notice

Source: <https://github.com/Oxford-step-counter/Java-Step-Counter/blob/dfd079a2678c8d29adbba08de840367f4d4fcd41/LICENSE.md>. The upstream file includes the following notice; the source headers credit Jamie Brynes. The Dart implementation is an adaptation, not the upstream Java implementation.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
