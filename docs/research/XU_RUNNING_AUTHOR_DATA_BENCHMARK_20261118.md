# Running step detection — Xu et al. (2022) author-data replay

Historical Oxford comparator. Superseded for runtime selection by
[Xu Running runtime adaptation](XU_RUNNING_RUNTIME_20261118.md).

## Protocol and verified source

Ying Xu et al., *Smartphone-Based Unconstrained Step Detection Fusing a
Variable Sliding Window and an Adaptive Threshold*, Remote Sensing 14(12),
2926. DOI: https://doi.org/10.3390/rs14122926.

Author-linked dataset: https://github.com/jackleenotjackma/StepCountingData,
commit 3da2d6e683f56e39eb74cda79eaa8ee93e033d6c.
Downloaded to tooling/data/xu_step_counting_20261118. Source contains all 25
constrained traces and metadata, but not the further 25 unconstrained traces
described by the paper. The README explicitly says 25 constrained records.
No explicit dataset license was found in this repository; do not redistribute
the raw data without reviewing usage rights.

Paper Tables 2–3 and source metadata identify Group 3 (flat ground running,
handheld phone kept flat), subject IDs 11–15, with manually counted total
steps. XLSX SHA256:
f8d611485ca36ab554df2bfe606fc309d2f16293764e13b460e1488f16a38f58.
Individually named raw files map to the numbered metadata records. Group 3
reference counts (240,343,230,183,284) agree exactly with Table 5.
25,034 samples, four columns: seconds and raw XYZ accelerations in m/s².
All five timestamp sequences strictly increase. The paper uses counts, not
independent per-event ground-truth labels; no F1 or rolling-cadence accuracy
can be inferred from these totals.

## Actual replay

Run the existing, unchanged OxfordStepDetector Dart class (Salvi et al.,
10.1109/EMBC.2018.8513319), resetting between traces, processing every sample
at its recorded timestamp, no ground-truth inputs, no tuning, no trimming and
no end flush. This is an offline comparison of the Walking detector candidate
on running data, not a replay of the active Running native OS pedometer.
The dataset contains no OS step stream.

Accuracy = 100 × (1 - abs(detected - reference)/reference), macro averaged
over the same five trials as the paper's constrained Running group.
The authors' Stepcount and Xu percentages below are reported Table 5 results
(rounded to one decimal by authors), not algorithms executed in this replay.

| Subject | GT | Dart WPD | Dart accuracy % | Reported Stepcount % | Reported Xu % |
|---|---:|---:|---:|---:|---:|
| 11 | 240 | 207 | 86.25 | 94.2 | 98.3 |
| 12 | 343 | 256 | 74.64 | 95.3 | 99.1 |
| 13 | 230 | 171 | 74.35 | 84.3 | 99.1 |
| 14 | 183 | 184 | 99.45 | 88.5 | 98.9 |
| 15 | 284 | 263 | 92.61 | 87.3 | 99.3 |
| Total / macro accuracy | 1280 | 1081 | 85.4585 | 89.92 | 98.94 |

Dart macro accuracy sample SD: 11.0471 percentage points.
WAPE: 15.703125%. Session count-per-minute MAE: 22.6693 steps/min
(count divided by full recording duration, NOT instantaneous cadence MAE).
OxfordWPD undercounts substantially in 3 traces; no Running activation.
No claim that the paper's 98.94% has been reproduced.

Xu method is a relevant alternative: paper §2–3 uses magnitude, order-10
Hamming FIR with reported 5 Hz passband, FFT with 256 samples and 1 s hop,
adaptive peak threshold and variable-window timing rejection. Table 1 gives
running range 1.8–3.5 Hz, peak threshold 11.6 m/s² and time threshold >286 ms.
Narrative §2.2 instead describes running as 2–3.5 Hz; paper §3.1 describes
an empirical cap on the adaptive threshold even though Figure 7's narrative
describes removal of peaks missed by the fixed threshold. No author source
implementation was included in the verified dataset tree. These details require
explicit reproducibility decisions before calling a new implementation an
exact reproduction. No Xu code implementation or production change was made.

## Reproducibility and verification

From ekf worktree:
```sh
dart run tooling/step_benchmark/run_xu_running_validation.dart
flutter analyze --no-pub tooling/step_benchmark/run_xu_running_validation.dart
```

Outputs: tooling/step_benchmark/results/xu_running_validation.json.
Independent metadata/count arithmetic and SHA256 checks passed; repeat replay
produced identical JSON SHA256
d59e25b0d0c11507fc6f0c61166244253eae4fcd51aecdce0bf17dfc57805951.
Detector source SHA256 unchanged:
30559d0e41e8e7e1719ae6ce136a5b85dced9cc716204056c21d505374aeb73a.

Thesis scope: use public author-associated or independent datasets with
reference labels and matching published evaluation procedures. New collection
on owner's smartphone is not a mandatory algorithm benchmark gate.
Physical sensor integration, battery and deployment validation are separate
claims beyond this offline benchmark. The 5-run group does not establish
generalization across phone placement, unconstrained running or all devices.
