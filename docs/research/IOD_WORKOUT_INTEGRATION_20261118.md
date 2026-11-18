# IOD workout integration — 18 November 2026

## Implementation boundary

The existing DeepIOD Model C-Mobile adaptation now contributes to the live
workout environment hint. No IOD output changes the recording source,
tracking mode, route, distance, moving time, manual pause, Auto-Pause, or
GPS/step safety policy.

* `record_providers.dart:108–116`: Riverpod listens for changed IOD
  observations, inference output, session ID and lifecycle. It does not
  consume the user's ground-truth annotation as a feature.
* `workout_environment_controller.dart:30–115`: only active GPS-capable
  workouts with matching IOD session, snapshot time not before workout start,
  nonfuture age <= 2 seconds, and at least 10 epochs are eligible.
  Require exact live model version and native class, finite probability
  coherent with the binary 0.5 decision rule, valid confidence, and real
  finite nonnegative lux/magnetometer/accelerometer plus daytime availability.
  The GPS-only Table 4 adaptation, experimental ensemble, warm-up,
  unknown output, and stale data cannot become independent evidence.
* `record_providers.dart:1107–1149`: when the existing GPS classifier is
  still detecting, the recording source remains GPS, no indoor mode/fallback
  is active, and no accepted GPS fix exists within the preceding 5 seconds,
  a qualifying neural prediction may fill the environment hint.
  For a resolved legacy hint, agreement is reported as corroboration;
  disagreement never overrides the legacy hint or increases its confidence.
  The 2-second expiry and reuse of the existing 5-second GPS freshness
  convention are application safeguards, not fitted paper parameters.
* `record_providers.dart:1392,1862,2048–2049`: accepted GPS anchor/segment
  keeps priority; 1 Hz ticker rechecks source age and restores the
  unassisted hint when an IOD stream becomes unavailable.

The existing indoor + fallbackSuggested + supported sport guard, cooldown,
raw GPS recovery, step fallback, and distance path are unchanged. Cycling
does not gain a step-distance fallback. No IOD-driven mode changes occur
during manual pause or indoor-only activity. This worktree does not expose
a separate manual indoor/outdoor selector; modeDecisionLocked is a
bootstrap decision flag rather than a user selection. The new code never
writes trackingMode or modeDecisionLocked. It also explicitly excludes an
indoor tracking mode not selected through GPS fallback.

## Source-labelled CIOD replay

Same public source and model as `IOD_LIVE_INPUT_ALIGNMENT_20261118.md`:

* DeepIOD, Sensors 2024, 24(16), 5125, DOI 10.3390/s24165125.
* Cambridge CIOD dataset, DOI 10.17863/CAM.82668, CC BY-NC-SA 4.0.
* SHA-256 of original CSV independently confirmed:
  `46da63af4ee24190f7db0524a1ae3b8d685a11078548c8ece4489b1a751abfe1`.

`test/iod_workout_integration_test.dart` reruns the actual Dart live model
and the production workout advice function on every available row of
zero-based sessions 72..84. The original source labels are unchanged
(IO=1 indoor, IO=0 outdoor); reset model history at each recorded session.
The no-GPS, unresolved legacy hint is an explicitly isolated evaluation
scenario. CIOD has no GPS accuracy/fixes, OS step stream, real absolute
timestamps or physical doorway transition truth. No GPS measurements or
step evidence are invented to validate routing. Row-order timestamps from
the adapter establish input order and replay time, not real delivery delay.

Actual replay result: PASS, 201,731 rows; 13 sessions.

| Source truth | Hint indoor | Hint outdoor | Remain detecting |
| --- | ---: | ---: | ---: |
| Indoor (118,964) | 110,985 | 7,880 | 99 |
| Outdoor (82,767) | 45,278 | 37,471 | 18 |

201,614 eligible predictions; 117 warm-up abstentions; 148,456 correct.
Coverage 99.94%; evaluated-only accuracy 73.63%; macro-F1 including
abstention in recall 69.57%, outdoor recall 45.3%. These counts match the
previous uncapped C-Mobile live benchmark. No model improvement or
paper-original checkpoint reproduction is claimed. The previous uncapped
8-channel sound-imputed Model C score (90.17% macro-F1) does not establish
live input parity. iOS presently lacks the required lux input in Aetron;
therefore C-Mobile normally cannot advise the workout there. Its GPS-only
fallback remains in IOD telemetry but is rejected as independent advice.
The dataset cannot establish handover accuracy, switching latency,
distance error or actual-device power/latency performance.

## Reproducibility and validation

```sh
AETRON_CIOD_CSV=/absolute/path/to/Data_Supporting_IOD_DL_MTSC_JIoT.csv \
  flutter test --no-pub test/iod_workout_integration_test.dart
flutter analyze --no-pub \
  lib/features/workout/presentation/screens/record/workout_environment_controller.dart \
  lib/features/workout/presentation/screens/record/record_providers.dart \
  test/iod_workout_integration_test.dart
```

New integration tests cover the real Riverpod listener, independent
prediction eligibility, fallback rejection, stale/future/wrong session,
manual pause, indoor-only activities, cycling, and withdrawal of neural
hint without touching source/mode/distance/step count. Five deterministic
tests passed plus the explicitly enabled full CIOD replay. The broader
IOD suite executed serially: 55 pass, 1 expected opt-in replay skip.
Environment controller architecture test also passed. Focused analyzer
reported no issues and diff --check passed.

The initial combined concurrent run with CIOD and eight test files ended
76 passed / 2 failed. Existing single-shot ensemble latency assertion
observed 12 ms against <=10 ms; it passed when retried serially without
changing the assertion. Existing architecture finalizer test expects 1000
estimated steps but current concurrently edited finalizer returned 0.
That failure is outside this IOD change and was reported to prime.
No claim of full-worktree green status or hardware-field acceptance.

Scope: record_providers (IOD integration only), workout environment
controller, new IOD integration test, this report. No deployment,
commit/push, Auto-Pause, backend or other worker code changes.
