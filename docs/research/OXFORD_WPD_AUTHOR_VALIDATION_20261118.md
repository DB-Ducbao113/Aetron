# Oxford WPD — replay of the authors' original validation dataset

## Provenance and integrity

Paper: Salvi et al., *An optimised algorithm for accurate steps counting from smart-phone accelerometry*, IEEE EMBC 2018, DOI <https://doi.org/10.1109/EMBC.2018.8513319>.

Original validation data: <https://github.com/Oxford-step-counter/DataSet/tree/922cc0d8511a7189f7a667d173c21e9472729603/validation>. Commit `922cc0d8511a7189f7a667d173c21e9472729603` (2022-03-07), with complete non-truncated GitHub tree. Both the root README and validation README explicitly specify [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); the GitHub license API returned 404, not an absence of the documented license. Attribution: Oxford-step-counter, Salvi et al.; the downloaded original files are unchanged.

Retrieved all 12 validation CSVs, original analysis.xlsx, and both READMEs (15 files, 13,300,296 bytes), excluding the 165-byte Excel temporary lock file. Verified each downloaded file against the upstream Git blob SHA-1 and byte count, and recorded SHA-256 in `tooling/data/oxford_wpd_validation_20261118/manifest.json` in the main checkout's shared data directory. The separate optimisation set was neither downloaded nor used here.

The author README specifies Samsung S6 smartphone accelerometry; two people, six phone positions each (hand, front pocket, back pocket, bag, neck pouch, armband). CSV columns: timestamp in nanoseconds since boot, raw acceleration XYZ, cumulative algorithm count, cumulative ground-truth-device count, cumulative hardware step counter. Each cumulative counter begins at zero, remains monotonic, and the reference increases by one at each recorded update. There are three non-increasing sensor timestamp transitions; the existing detector rejects these as usual. The median per-file interval is approximately 9.26–10.00 ms. All 242,411 rows, 2,411.92 seconds, and 4,107 reference steps are included; no trace removed.

## Frozen implementation and method

The existing Dart detector `lib/core/services/sensor/oxford_step_detector.dart` is **unchanged**, SHA-256 `30559d0e41e8e7e1719ae6ce136a5b85dced9cc716204056c21d505374aeb73a`. No threshold, filter coefficient, duration, or model parameter was selected using these validation data. No optimization data used. The reference Java implementation and explicit bounded-delay adaptations are described in [the previous research report](OXFORD_WPD_RAW_STEP_RESEARCH_20261118.md).

Run from stride-ekf worktree root:

```sh
~/development/flutter/bin/dart run tooling/step_benchmark/run_oxford_author_validation.dart
```

The runner feeds only columns 1–4 (time and raw XYZ; zero-based columns 0–3) to the existing detector. Timestamps are rebased to the first recorded timestamp and converted from nanoseconds to integer microseconds. The other columns are read strictly for evaluation. No synthetic steps, label-driven corrections, post-run flush, or changes to production code. The original algorithm's recorded count is a comparator, not a newly executed Java benchmark. The hardware count is a recorded device output rather than a replay of Android/iOS code.

## Actual validation results

| User / position | Reference | Dart | Author CSV | Hardware CSV |
|---|---:|---:|---:|---:|
| 1 / armband | 335 | 316 | 316 | unavailable |
| 1 / back pocket | 343 | 503 | 501 | unavailable |
| 1 / bag | 346 | 323 | 321 | unavailable |
| 1 / front pocket | 327 | 342 | 338 | unavailable |
| 1 / hand | 326 | 312 | 311 | unavailable |
| 1 / neck pouch | 346 | 345 | 344 | unavailable |
| 2 / armband | 343 | 340 | 339 | 341 |
| 2 / back pocket | 337 | 347 | 345 | 345 |
| 2 / bag | 361 | 379 | 376 | 359 |
| 2 / front pocket | 343 | 341 | 340 | 339 |
| 2 / hand | 340 | 342 | 341 | 338 |
| 2 / neck pouch | 360 | 346 | 348 | 362 |
| Total | 4,107 | 4,236 | 4,220 | 2,084 (six available traces) |

Count accuracy is defined as 1 minus the mean of absolute per-trace relative count errors (macro MAPE), not event classification accuracy. WAPE is total per-trace absolute errors divided by total reference count.

| Metric | Dart adaptation (12) | Author CSV (12) |
|---|---:|---:|
| Mean count accuracy | 93.1646% | 93.3582% |
| Sample SD of count accuracy | 12.7260 pp | 12.5986 pp |
| Count MAPE | 6.8354% | 6.6418% |
| Count WAPE | 6.8420% | 6.6472% |
| Total predicted steps | 4,236 | 4,220 |

The supplied analysis.xlsx reports author mean accuracy 93.3337%, SD 12.5854 pp. Its user2 hand row says 342, while the actual CSV ends at 341. No correction applied: CSV counts are the reproducible comparator. Dart accuracy is 0.1936 percentage points lower than the recorded author CSV comparator. The user1 back-pocket trace has a genuine large count error (Dart +160, 46.65%; author +158, 46.06%) and remains included.

Hardware comparison uses **only six user2 traces** because the user1 hardware column is zero throughout despite hundreds of ground-truth steps, so availability is unknown/unusable and is not scored as six zero-count failures.

| Comparable subset (2,084 GT, 6 traces) | Dart | Author CSV | Hardware CSV |
|---|---:|---:|---:|
| Mean count accuracy | 97.6853% | 97.9671% | 99.0298% |
| WAPE | 2.3512% | 2.0633% | 0.9597% |
| Predicted steps | 2,095 | 2,089 | 2,084 |

The existing Dart adaptation therefore does not outperform the hardware count on this subset. This is a measured result, not a gate requiring numerical superiority.

Raw-stream cadence evaluation on 2,347 trailing six-second windows (one-second reporting interval) gives MAE 12.0920 spm against the reference device's counter increments, counting each detector event at its causal availability time. Reference increments are not independently verified heel-strike timestamps; device and recording delays are unknown, so no claimed event F1, clinical stride timing accuracy or physical latency guarantee follows. The original validation data support count accuracy, not broad generalization.

## Limits and status

This is an actual replay of the paper authors' original validation data on the already implemented Dart adaptation, not an exact rerun of their original Java app. Two users and one phone model are insufficient to claim smartphone-wide performance, running accuracy, battery behavior, or real device runtime timing. PedEval external replay remains a separate cross-domain benchmark. The raw detector is unchanged; no shared provider/controller or other production edits, no commit/push.

Detailed machine-readable results: `tooling/step_benchmark/results/oxford_author_validation.json`.
