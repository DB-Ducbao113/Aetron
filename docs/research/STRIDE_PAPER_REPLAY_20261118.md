# Stride length: published equation replay (2026-11-18)

Status: EQUATIONS_REIMPLEMENTED / FULL ORIGINAL EXPERIMENT NOT REPRODUCED.
Scope: offline research only; no production changes.

## Sources
- Vezočnik, Kamnik & Juric (2021), Sensors 21, 3527, DOI 10.3390/s21103527: Eq. 15, d = beta * range(||a||)^0.1.
- Vezočnik & Juric (2022), Sensors 22, 9452, DOI 10.3390/s22239452: Eq. 2, d = (K1 * F + K2) * range(||a||)^0.1. F is full-cycle frequency in Hz. Both are calibrated by least squares, without new hand-selected coefficients.
- External public reference: Wang et al. (2019), Sensors 19, 840, DOI 10.3390/s19040840; https://github.com/Archeries/StrideLengthEstimation , commit c96f67c79a81a8f2098eee051dd41c0c1ba1d102. Smartphone accelerometer and foot-mounted reference IMU, mixed locomotion. Thirty files, 1,192,505 samples. Not the Vezočnik treadmill dataset. No subject/activity IDs available in the tested records.
- SLEDataset2 was not used here: the available JSON has separate acceleration arrays and stride-length labels, without explicit event alignment.

## Reimplementation
For adjacent reference stride-counter changes, use smartphone acceleration between the events. The closing event's cumulative-distance increment must match its stride-length field. Source records often update the length one sample before the counter changes, so the length from the previous counter group is inappropriate; timestamp columns are in milliseconds in the actual data. The first and final unbracketed intervals are not evaluated. The static file has no completed intervals. No valid bracketed intervals failed the checks. Reference segmentation is supplied, not predicted; the reference length is used only in calibration/scoring. Raw acceleration includes gravity, unlike the linear acceleration in the 2021/2022 experiments. No new gravity removal or outlier thresholds were invented. No clipping was applied; negative predictions remain in the results.

Two fixed protocols:
1. Leave one recorded file out; train on other files, predict the held-out file. 29 files, 8243 cycles; session-level, not subject-disjoint.
2. For files with at least 600 seconds of annotated recording, calibrate using only completed cycles in the first 300 seconds, then predict subsequent complete cycles; exclude any crossing the cutoff. 7 files, 5570 evaluated cycles. This resembles the published temporal calibration but does not replicate its treadmill speed/position conditions or dynamic coefficient selection. Same valid samples for all methods.

All values below concern full gait cycles, not single steps. Training mean is an engineering comparator, not Aetron or a published model.

## Measured local results
| Protocol | Method | MAE cm | RMSE cm | Mean per-file absolute distance error % |
|---|---|---:|---:|---:|
| File holdout | 2021 | 45.08 | 110.60 | 25.73 |
| File holdout | 2022 | 39.23 | 91.00 | 76.63 |
| File holdout | Training mean | 45.13 | 111.91 | 30.79 |
| First 5 min | 2021 | 35.63 | 56.22 | 10.86 |
| First 5 min | 2022 | 23.88 | 41.57 | 7.65 |
| First 5 min | Training mean | 36.88 | 57.38 | 11.44 |

The 2022 equation reduces per-cycle error in both tests and per-file distance error in the temporal calibration test, but worsens mean per-file distance error under file holdout. It generated 9 negative predictions on file holdout and 1 on temporal calibration; not corrected after observing results. Pooled distance errors conceal cancellation and are not a substitute for per-file errors. Authors' published treadmill MAE: 6.44 cm (2021) and 5.64 cm (2022); not reproduced here and not directly comparable. Separate Walking/Running accuracy cannot be inferred. No physical Aetron device assessment or deployment was performed.

## Reproducibility
Run from ekf worktree:
```sh
python3 -m unittest discover -s tooling/benchmark -p test_stride_paper_replay.py -v
python3 tooling/benchmark/stride_paper_replay.py --data ../../asle_research_2026/Benchmark-Dataset-for-Adaptive-Stride-Length-Estimation --out tooling/benchmark/results/stride_paper_replay_20261118
```
3/3 unit tests passed. Independent arithmetic check of exported CSV recomputed MAE, RMSE, pooled and mean-file absolute distance errors matching manifest for both protocols; counts and unique within-protocol file/timestamp keys verified. Prediction SHA256 f6399725f80b76c3a11f4cc6ca60eb7ed50c5cf128b80b1414df3e0c1ca59ad6.
Manifest stores source hashes, fit coefficients, fold sizes and results. No Dart changes, no production selection decision. No Auto-Pause changes.
