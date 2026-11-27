# Aetron — CAP-ALSTM Indoor/Outdoor Detection Benchmark & External Generalization Audit (SDD-06)

- **Ngày:** 2026-11-27
- **Bài báo gốc:** Bakirtzis, Qiu, Wassell, Fiore, & Zhang, *"Deep Learning-based Multivariate Time Series Classification for Indoor/Outdoor Detection"*, IEEE Internet of Things Journal (2022), DOI: [`10.1109/JIOT.2022.3190555`](https://doi.org/10.1109/JIOT.2022.3190555) (PDF cục bộ: `docs/plans/papers/Bakirtzis2022_IOD_JIoT.pdf`)
- **Dataset In-Distribution:** Cambridge CIOD (`10.17863/CAM.82668`, 85 sessions, `1,473,287` rows) — Train `00..59` (`1,046,997`), Val `60..71` (`224,559`), Held-Out Test `72..84` (`201,731`)
- **Dataset Ngoại biên (Zero-Shot External Audit):** HAR-PMD (`10.1038/s41597-025-06527-y`, Zenodo `7939223`) — `12` đối tượng đa thiết bị, `48` bản ghi CRC32/SHA-256 verified, `28,846` 1s epochs (`walking` + `still`, `indoor` + `outdoor`)

---

## 1. Kết quả trên Held-Out Cambridge CIOD (Sessions 72..84, N = 201,731)

Toàn bộ ngưỡng chuẩn hoá (`top-1% clip + Min-Max`), early stopping, kích thước cửa sổ và tham số `Causal 2-state HMM` ([Zhu 2019](https://doi.org/10.3390/s19040786)) được chốt **duy nhất trên Validation `60..71`** trước khi đánh giá một lần trên Held-Out `72..84`.

| Mô hình / Tập kênh | Cửa sổ $w$ | Accuracy | Macro-F1 | Indoor Rec | Outdoor Rec | Median Delay $d$ | Ghi chú |
|---|---:|---:|---:|---:|---:|---:|---|
| *Baseline cũ:* Always-Indoor Majority | — | 58.97% | 37.10% | 100.00% | 0.00% | — | Baseline đa số |
| *Baseline cũ:* DeepIOD Model C-Mobile (4ch) | 10s | 73.64% | 69.59% | 93.37% | 45.28% | — | Báo cáo cũ `IOD_INDEPENDENT_...` |
| *Baseline cũ:* DeepIOD Model C (8ch) | 10s | 90.59% | 90.17% | 94.33% | 85.20% | — | Báo cáo cũ |
| *Baseline cũ:* iOS `[MagIO+Acc+Daytime]` MLP+HMM | 10s | 75.65% | 74.77% | — | 69.48% | — | MLP raw `77.07%` / `74.97%` |
| **CAP-ALSTM `8ch_full` (Raw val-th)** | 12s | 92.58% | 92.37% | 92.67% | 92.45% | 2.0 s | +SHAP, `84,737` params, `0.61 ms` CPU |
| **CAP-ALSTM `8ch_full` + Causal HMM** | 12s | 92.74% | 92.54% | 92.35% | 93.30% | 3.0 s | 45/46 transitions detected |
| **CAP-ALSTM `8ch_full` (Raw val-th)** | 25s | 93.75% | 93.54% | — | — | — | Khớp xu hướng $w$ tăng trong [Bk22] |
| **CAP-ALSTM `7ch_nosound` + Causal HMM** *(Android)* | **12s** | **94.07%** | **93.87%** | **95.14%** | **92.53%** | **7.0 s** | **Tốt nhất tổng thể (không cần Mic)** |
| **CAP-ALSTM `6ch_android_motionfree` + HMM** | 12s | 91.17% | 90.89% | 92.16% | 89.74% | 9.0 s | Raw: `92.77%` Acc / `92.34%` MF1 (bỏ `Acc`) |
| **CAP-ALSTM `4ch_mobile` + Causal HMM** | **12s** | **78.82%** | **78.63%** | **74.74%** | **84.68%** | **0.0 s** | **Vượt Model C-Mobile +9.04 điểm MF1** |
| **CAP-ALSTM `3ch_mobile_motionfree` + HMM** | 12s | 69.61% | 69.56% | 62.50% | 79.83% | 7.0 s | Bỏ `Acc` khi thiếu cellular PHY |
| **CAP-ALSTM `3ch_ios_lightfree` + HMM** *(iOS)* | **12s** | **76.14%** | **75.54%** | **77.83%** | **73.70%** | **0.5 s** | **Vượt iOS MLP+HMM bằng 1 bài báo duy nhất** |
| **CAP-ALSTM `2ch_ios_motionfree` + HMM** | 12s | 69.36% | 68.69% | 71.17% | 66.76% | 0.0 s | Chỉ `Mag + Daytime` |

---

## 2. Exact Shapley Feature Attribution (Eq. 6 của Bakirtzis 2022)

Tính chính xác trên toàn bộ $2^8 = 256$ liên minh (coalitions) đối với `CAP-ALSTM 8ch_full (w=12)` (`n_eval=256`, background `n_bg=16` từ Train):

| Hạng | Kênh cảm biến | Mean $|\phi_i|$ | Vai trò & Ý nghĩa |
|---:|---|---:|---|
| 1 | `RSRP` | **0.1956** | Tín hiệu quyết định mạnh nhất (suy hao sóng di động qua tường) |
| 2 | `Acc` | **0.1268** | Đứng thứ 2 trong CIOD — nguồn gốc gây locomotion confounding khi thiếu RSRP |
| 3 | `Daytime` | **0.1099** | Ngữ cảnh ngày/đêm |
| 4 | `Mag` | **0.0833** | Nhiễu từ trường trong nhà |
| 5 | `Proximity` | **0.0828** | Che khuất cảm biến ánh sáng |
| 6 | `Sound` | **0.0697** | Bỏ được trên Android (`7ch_nosound` vẫn đạt `94.07%` Acc) |
| 7 | `RSRQ` | **0.0389** | Bổ trợ chất lượng sóng |
| 8 | `Light` | **0.0344** | Hữu ích cục bộ nhưng nhạy với túi quần / ánh sáng ngoài trời cực đại |

---

## 3. Kiểm định Ngoại biên & Kết quả Âm trên HAR-PMD (`12` đối tượng, `48` bản ghi, `28,846` epochs)

Đánh giá **zero-shot** (không retrain, không chỉnh ngưỡng) cho thấy cả DeepIOD lẫn CAP-ALSTM **khi thiếu `RSRP/RSRQ`** đều suy giảm nghiêm trọng khi chuyển sang tập thiết bị/quốc gia hoàn toàn mới:

| Mô hình (Train trên CIOD) | Overall MF1 | Indoor Rec | Outdoor Rec | Walking MF1 | Still MF1 |
|---|---:|---:|---:|---:|---:|
| DeepIOD Model C-Mobile (4ch) | 55.26% | 50.1% | 60.7% | 33.49% | 53.71% |
| CAP-ALSTM `4ch_mobile` (w=12) | 42.47% | 10.4% | 95.2% | 33.34% | 49.51% |
| CAP-ALSTM `3ch_mobile_motionfree` (w=12) | 39.43% | 12.4% | 80.5% | 33.15% | 45.21% |
| CAP-ALSTM `3ch_ios_lightfree` (w=12) | 37.12% | 5.7% | 92.0% | 33.34% | 39.71% |
| CAP-ALSTM `2ch_ios_motionfree` (w=12) | 35.29% | 12.5% | 68.1% | 31.81% | 35.75% |

**Nguyên nhân định lượng (Domain Shift + Weighted-BCE Bias):**
1. **Lệch thang đo vật lý:** Trên HAR-PMD, `Acc` trung vị là **`1.42 m/s²`** (gấp **46×** mức `0.031 m/s²` của CIOD Train), `Mag` trung vị là **`50.46 µT`** (so với `40.90 µT`), và `Light` đạt cực đại **`291,031 lux`** (so với ngưỡng clip `8,577 lux` / max `10,000` ở CIOD). Min-Max scaler học từ CIOD bão hoà hoàn toàn đầu vào HAR-PMD.
2. **Weighted BCE (`pos_weight = 1.74`) + `Daytime=1.0`:** Kéo ranh giới quyết định lệch sang Outdoor (`OutRec = 92–95%`, `InRec = 6–12%`) khi thiếu tín hiệu `RSRP` làm mỏ neo.
3. **Kết luận kiến trúc:** Không xoá bỏ tính chất `isObservationalOnly: true`; giữ nguyên cờ cách ly không cho IOD tự ý ngắt GNSS/PDR ngoài thực địa khi chưa hiệu chuẩn theo từng thiết bị.

---

## 4. Python–Dart Inference Parity & Kiểm thử Phần mềm

- **Implementation:** `lib/features/iod/domain/services/cap_alstm_model.dart`, `cap_alstm_iod_classifier.dart`, tích hợp `IodClassifierMode.capAlstm` trong `iod_composite_classifier.dart`, weights tại `assets/models/iod/`.
- **Parity Test (`test/iod_cap_alstm_parity_test.dart`):** `500` cửa sổ ngẫu nhiên từ CIOD Held-Out cho mỗi model (`2,000` cửa sổ tổng cộng) đối chiếu với PyTorch `float64`:
  - `cap_alstm_7ch_nosound_w12_wbce`: `max |logit_dart - logit_py| <= 1e-5`, `100%` khớp nhãn — **PASS**
  - `cap_alstm_6ch_android_motionfree_w12_wbce`: `<= 1e-5`, `100%` khớp nhãn — **PASS**
  - `cap_alstm_4ch_mobile_w12_wbce`: `<= 1e-5`, `100%` khớp nhãn — **PASS**
  - `cap_alstm_3ch_ios_lightfree_w12_wbce`: `<= 1e-5`, `100%` khớp nhãn — **PASS**
- **Toàn bộ `flutter analyze` = 0 issues**; **50/50 IOD tests PASS** (`+50 ~1`, 1 test cũ bỏ qua do cần biến môi trường `AETRON_CIOD_CSV`).
