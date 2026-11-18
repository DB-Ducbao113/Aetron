# IOD live input alignment — 18 November 2026

## Decision and scope

The live IOD provider uses the existing CIOD-trained DeepIOD Model C-Mobile
adaptation only with a complete observed four-feature window. It does not
substitute GNSS or LTE for light, acceleration or magnetometer readings.
If the neural model cannot evaluate its window, a separately identified
GPS-only evidence source is available using the published DeepIOD accuracy
criterion. If neither source is available, the state is unknown. All IOD
outputs remain observational; no workout handover, distance, pace or
Auto-Pause code was modified in this work.

Sources: Dastagir, Tariq and Han, **DeepIOD: Towards A Context-Aware Indoor–Outdoor
Detection Framework Using Smartphone Sensors**, Sensors 2024, 24(16), 5125,
[DOI 10.3390/s24165125](https://doi.org/10.3390/s24165125), Table 1, equations
9/35, section 4.5 equation 34 / Table 4 and section 5.1.1. The Cambridge
dataset is Bakirtzis et al., [DOI 10.17863/CAM.82668](https://doi.org/10.17863/CAM.82668),
CC BY-NC-SA 4.0; [paper DOI 10.1109/JIOT.2022.3190555](https://doi.org/10.1109/JIOT.2022.3190555).
The authors' original deployed checkpoint and exact preprocessing are not
available in this repository. C-Mobile uses locally trained four-feature
weights, a ten-row causal window and local feature standardization, not the
paper's exact eight-feature training protocol. The paper describes min/max
normalization and removal of extreme observations; these are not proven
identical to Aetron's training. The published scores are not Aetron scores.

## Actual live sensor audit

| Signal | Android | iOS | Role in selected live model |
| --- | --- | --- | --- |
| Lux | TYPE_LIGHT, only if physical sensor/bridge | No public bridge in current Aetron | Required observed feature; no substitute |
| Magnetic magnitude | sensors_plus magnetometer, if available | Same, if available | Required observed feature |
| Acceleration magnitude | sensors_plus userAccelerometer (gravity removed) | Same, if available | Required observed feature; matching raw CIOD preprocessing is not independently verified |
| Daytime | Solar elevation if recent GPS, local time otherwise | Same | Contextual estimated feature; not a measured light replacement |
| Position / horizontal accuracy | Geolocator, with permissions | Geolocator, with permissions | Separate GPS-only rule, not a neural input |
| C/N0 / satellites | Native GNSS callback, permission dependent | Not present in current bridge | Telemetry only |
| Gyroscope, step delta | Sensor and OS step streams | Same, if available | Telemetry only; not C-Mobile feature |
| LTE PHY, proximity, sound | No acquisition subscription in current IOD service | Not acquired | Unavailable, never proxied |
| Wi-Fi/BLE | Native Android scans, permissions/throttling dependent | Not present in this IOD bridge | Existing experimental telemetry; no surveyed radio map is configured |

Code anchors: acquisition `iod_sensor_acquisition_service.dart:47–180,225–350`;
native bridge `native_sensor_platform_channel.dart:185–220`; snapshot schema
`iod_sensor_snapshot.dart:13–111`. The prior default used C-Mobile prediction
even when only an unrelated GPS/LTE/CN0 channel was available. The legacy
classifier's mean imputation and padded warm-up are preserved in the research
modes for reproducibility, not selected in the new live path.

## Implementation

* `iod_composite_classifier.dart:148–263`: `liveMobile` requires finite
  nonnegative real Lux/Mag/Acc, plus contextual daytime. It resets on missing
  input, duplicate/backward timestamps or a gap longer than two nominal 1 Hz
  epochs; returns neural decisions only after 10 accepted epochs. This is
  an engineering input-integrity safeguard, not a learned research parameter.
  Source: `deepiod_c_mobile_adapted:indoor/outdoor`, version
  `aetron-deepiod-c-mobile-live-v1.0`; retains the original model score.
* When C-Mobile is missing or warming up, a finite, positive, available
  GPS horizontal accuracy smaller than 5 m yields outdoor evidence, larger
  than 5 m yields indoor evidence, exactly 5 m abstains. This is the explicit
  Table 4 rule; the paper specifies Android. Output has source
  `deepiod_gps_table4_adapted:indoor/outdoor`, version
  `aetron-deepiod-gps-table4-adapted-v1.0`, no neural probability and
  confidence 0 (no calibrated confidence available). It is advisory only,
  including on iOS where accuracy semantics/field performance have not been
  calibrated. Weak GNSS alone is not proof of being indoors. No available GPS
  means unknown; retain existing workout sensor fallback.
* `iod_controller.dart:65–67,106–128`: live provider selects the new mode and
  a new session clears previous prediction/ground-truth metadata.
* Acquisition keeps the last valid on-change light reading while the active
  sensor stream remains healthy; missing/invalid readings and stream errors
  clear it, and the cache is reset across sessions. GPS/GNSS observations
  older than 5 seconds (existing workout raw-GPS outage convention) or future
  dated are excluded. An asynchronous Wi-Fi/BLE callback from an old
  session cannot restore its cache. This is timestamp hygiene, not paper
  classification tuning. On-change light holding is not proof of fresh
  per-second hardware sampling; a silently broken sensor remains a field
  validation risk.
* `iod_record_entry.dart:75–77`: CSV includes native class, model version and
  observational-only flag; JSON already preserves these fields. Historical
  research-mode implementations and source dataset labels were not changed.

## Actual CIOD replay

Dataset SHA-256:
`46da63af4ee24190f7db0524a1ae3b8d685a11078548c8ece4489b1a751abfe1`.
Source schema `RSRP,RSRQ,Light,Mag,Acc,Sound,Proximity,Daytime,New_Recording,IO`.
The existing adapter preserves IO=1 indoor, IO=0 outdoor and resets state
at each source sequence. CIOD has no native GPS, C/N0, OS steps or actual
doorway coordinates. Its CSV lacks absolute timestamps; the existing adapter
constructs one-second sequential timestamps. It ignores Sound even when
present, so the 8-channel model and full AMV are *sound-imputed*, not true
eight-channel replay. Miscellaneous adapter proxies such as stepDelta=1,
accelVariance=0.5, and isScreenOff from proximity are not inputs of the
C-Mobile model. The full ensemble includes locally chosen fusion weights and
heuristic light/GPS modules; it is not the paper's original trained model.
CIOD has only binary environment labels; no physical transition-latency
or on-device inference/battery benchmark can be inferred.

Run directly inside this worktree:

```sh
AETRON_CIOD_CSV=/absolute/path/to/Data_Supporting_IOD_DL_MTSC_JIoT.csv \
  AETRON_CIOD_CAP=800 flutter test --no-pub test/iod_ciod_live_input_benchmark_test.dart --reporter expanded
AETRON_CIOD_CSV=/absolute/path/to/Data_Supporting_IOD_DL_MTSC_JIoT.csv \
  AETRON_CIOD_CAP=0 flutter test --no-pub test/iod_ciod_live_input_benchmark_test.dart --reporter expanded
```

Both executed. Sessions 72..84 zero-based (13 sessions), no parameter
selection or training on these runs. The cap-800 cohort is the first 800
rows from each session. It is not interchangeable with the uncapped cohort
or with earlier weighted-checkpoint metadata. These sessions have been used
in prior Aetron studies, not an untouched model-selection holdout.

| Cohort / actual variant | Rows | Accuracy among evaluated | Macro-F1 incl. abstention in recall | Outdoor recall | Coverage |
| --- | ---: | ---: | ---: | ---: | ---: |
| Capped, C-Mobile legacy | 10,400 | 89.66% | 79.80% | 52.0% | 100% |
| Capped, C 8-channel sound imputed | 10,400 | 96.93% | 94.82% | 86.9% | 100% |
| Capped, A/B/C AMV sound imputed GPS absent | 10,400 | 91.66% | 83.61% | 56.7% | 100% |
| Capped, new live C-Mobile | 10,400 | 89.73% | 79.49% | 51.7% | 98.88% |
| Uncapped, C-Mobile legacy | 201,731 | 73.64% | 69.59% | 45.3% | 100% |
| Uncapped, C 8-channel sound imputed | 201,731 | 90.59% | 90.17% | 85.2% | 100% |
| Uncapped, new live C-Mobile | 201,731 | 73.63% | 69.57% | 45.3% | 99.94% |

Full AMV was executed on the capped subset only. Use
`AETRON_CIOD_FULL_AMV=1` to include it in uncapped replay.
Capped support 8,422 indoor / 1,978 outdoor; uncapped 118,964 / 82,767.
Confusion counts (true indoor row: predicted indoor,outdoor,unknown; true
outdoor row: predicted indoor,outdoor,unknown):

| Cohort/model | Indoor row | Outdoor row |
| --- | --- | --- |
| Capped C-Mobile | 8296,126,0 | 949,1029,0 |
| Capped C research | 8362,60,0 | 259,1719,0 |
| Capped AMV | 8411,11,0 | 856,1122,0 |
| Capped live | 8205,118,99 | 938,1022,18 |
| Uncapped C-Mobile | 111076,7888,0 | 45289,37478,0 |
| Uncapped C research | 112222,6742,0 | 12250,70517,0 |
| Uncapped live | 110985,7880,99 | 45278,37471,18 |

117 abstentions = 13 sessions x 9 warm-up observations. No parameter/sensor
parity claim is based on score superiority. Real iOS has no lux channel in
the current app, implying zero C-Mobile coverage there unless its physical
input path changes; it can only produce labelled GPS evidence or unknown.
The GPS fallback cannot be evaluated on CIOD and has NOT VERIFIED
cross-platform performance. CIOD's training/data rights should be reviewed
for distribution or commercial reuse given its noncommercial license.

## Handover integration recommendation to prime

At initial audit, workout `record_providers.dart:327,1192,1455` started and
fed IOD but did not listen to its prediction to change tracking mode.
`_onEnvironmentChanged:1091–1167` instead used the legacy environment
controller's indoor hint and fallbackSuggested, a GPS/step corroboration
policy, and a cooldown. Running/walking have a step-fallback path; cycling
must remain GPS based. Accepted GPS segments can restore outdoor.

If integrating the research adaptation, consume fresh predictions from the
same session via the already published IOD provider. Only
`nativeClass.startsWith('deepiod_c_mobile_adapted:')` represents independent
non-GPS learned evidence; when available use it to inform an environment
hint or corroborate existing GPS-quality/step evidence, not to fabricate GPS
loss or insert distance. Do not count the GPS-only Table 4 fallback as two
independent confirmations of GNSS (the existing handover already uses GPS).
Keep the existing GPS/step handover when source is GPS-only or unknown, avoid
flapping, preserve valid GPS recovery and never change cycling to step
distance. No changes were made to record providers, environment controller,
Auto-Pause, backend, assets or Git history by this worker.

## Test evidence

Focused IOD analyzer returned no issues. The existing native sensor, neural
weight parity, benchmark adapter, IOD UI/lifecycle and new input-policy suites
passed together (49 tests at the initial verification); the new on-change-light
regression is verified separately. The two explicit CIOD runs passed. These
are desktop Dart/Flutter test results, not mobile hardware field acceptance.
