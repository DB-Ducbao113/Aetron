# Aetron — Step Gate & Cadence Provenance + A/B Ablation Report (SDD-04 & SDD-05)

- **Ngày:** 2026-11-27
- **Script tái lập:** `tooling/step_benchmark/run_step_gate_and_cadence_ab_test.dart`
- **Kết quả JSON:** `tooling/step_benchmark/results/sdd04_sdd05_ab_report.json`

---

## 1. Đối chiếu S0: `OxfordStepDetector` vs PDF Salvi et al. (EMBC 2018, Table III)

Từ PDF cục bộ `docs/plans/papers/10_1109_EMBC_2018_8513319.pdf` (Table III, trang 4):

| Tham số | Giá trị bài báo (Table III) | Trong `oxford_step_detector.dart` | Nguồn gốc |
|---|---|---|---|
| Filtering window | `M = 13`, Gaussian, `SD = 0.35`, cutoff `3 Hz` | `List.generate(13, ... 0.35 * 6)` | **Khớp PDF [S18]** |
| Scoring | Mean Difference, `N = 35` | `_smoothWindow(35)`, `score /= 34` | **Khớp PDF [S18]** |
| Detection threshold | `c = 1.2` | `1.2 * _std` | **Khớp PDF [S18]** |
| Post-processing | `t_window = 200 ms` | `_mergeUs = 200000` | **Khớp PDF [S18]** |
| Peak prominence floor | Không có trong Table III | `_minPeakThreshold = 0.35 m/s²` | *Adaptation (Aetron)* |
| Stationary MV-GLRT | Không có trong [S18] | `_zuptMvGamma = 0.36`, `W = 100` | Skog 2010 Eq.13 + Brajdic 2013 `σ≥0.6` |

---

## 2. SDD-04: Kết quả A/B `StepMotionGate` (Tắt vs Bật)

| Tập kiểm thử | Gate OFF (Detector + MV-GLRT) | Gate ON (Production Aetron) | Chênh lệch / Nhận định |
|---|---:|---:|---|
| **Oxford Walking** (12 traces, `4,107` ref steps) | `4,225` steps · Acc **93.09%** · WAPE 6.92% | `4,218` steps · Acc **93.16%** · WAPE 6.84% | **+0.07% Acc** (cắt 7 bước giả đầu chuỗi) |
| **Xu Group 3 Running** (5 traces, `1,280` ref steps) | `1,265` steps · Acc **98.46%** · WAPE 1.48% | `1,265` steps · Acc **98.46%** · WAPE 1.48% | **0.00%** (không rớt bước chạy nào) |
| **Sporadic Impulses** (10 lần vẫy tay 2 bước cách 5s) | `20 / 20` bước giả lọt qua | **`0 / 20`** bước giả lọt qua | **Loại 100%** bước giả rời rạc |

**Quyết định SDD-04:** **GIỮ NGUYÊN `StepMotionGate` ON**; cập nhật comment phân tách rõ MV-GLRT (Skog) với các hằng số bout là *Engineering Design* của Aetron (`kMinBoutSteps = 5`, `2200 ms`, `3500 ms`, `2.5 m` GPS check).

---

## 3. SDD-05: Kết quả A/B Cadence trên Oxford (`2,347` windows 1s)

| Phương pháp | MAE (spm) | RMSE (spm) | Jitter (`|Δcad|`/s) | Nguồn gốc |
|---|---:|---:|---:|---|
| **`window6s` (Production `CadenceCalculatorService`)** | **11.20** | **19.05** | 4.87 | **Engineering Design (Aetron)** |
| `interval_med_3` (`60 / Δt_step`, $N=3$) | 23.45 | 34.60 | 10.68 | Định nghĩa khoảng bước |
| `interval_med_5` (`60 / Δt_step`, $N=5$) | 22.28 | 33.67 | 8.18 | Định nghĩa khoảng bước |
| `interval_med_8` (`60 / Δt_step`, $N=8$) | 15.55 | 27.05 | 3.06 | Định nghĩa khoảng bước |

**Quyết định SDD-05:** **GIỮ NGUYÊN `window6s`**, vì vượt trội hơn hẳn phương pháp nghịch đảo khoảng bước (`11.20` vs `15.55–23.45 spm` MAE) trên tín hiệu step-event điện thoại thực tế, khớp với kết quả trên PedEval (`N=90`, `8.41 spm` MAE) và OxWalk (`N=39`).
