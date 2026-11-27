# SDD-02 GNSS robust gate = Adaptively robust filtering (Yang–He–Xu)

> **[OPTIONAL / FUTURE WORK]** P01 preprocessing hiện tại ĐÃ ĐẠT 1.34% sai số quãng đường cùng P02 AEKF — giữ nguyên cho Thesis; IGG-III là OPTIONAL / FUTURE WORK.

> **Vai trò trong hướng thống nhất:** thành phần kháng outlier của bộ lọc thống nhất (SDD-08). Xem [UNIFIED_RESEARCH_DIRECTION.md](../UNIFIED_RESEARCH_DIRECTION.md).

> ## HƯỚNG NGHIÊN CỨU (khai báo rõ)
> - **Hướng:** Adaptively robust filtering (lọc bền vững thích nghi, hình học trắc địa)
> - **Bài báo nền:** [Y01] Yang, He, Xu, J. Geodesy 2001, 10.1007/s001900000157
> - **Loại:** FAITHFUL cho hàm trọng số IGG-III; áp dụng lên quan sát GNSS điện thoại là mở rộng miền ứng dụng
> - **Lấy từ bài:** Hàm trọng số IGG-III, k0/k1, R̄=R/w
> - **KHÔNG lấy từ bài (phải khai báo trong báo cáo):** Ước lượng σ_v từ accuracy thiết bị; ngưỡng gap 5 s; giới hạn vật lý
> - **Loại bỏ/không dùng:** Loại bỏ hoàn toàn 'M-estimator gate' tự tổ hợp hiện tại
**Mục tiêu:** thay "Robust M-estimator gate" tự tổ hợp bằng hàm trọng số IGG-III của bài báo.
**Paper:** Yang Y., He H., Xu G., "Adaptively robust filtering for kinematic geodetic positioning", J. Geodesy 75, 109–116 (2001) — verify DOI/phương trình.
**Phạm vi:** `mobile_gvio_quality_gate.dart`, `kinematic_limits.dart`, `gps_input_quality_gate.dart`, `trajectory_outlier_detector.dart` → module `robust_igg3_weight.dart` + adapter vào `trajectory_preprocessor_interface`.
## Yêu cầu
- FR1: residual chuẩn hoá ṽ_i = |v_i|/σ_i; trọng số w = 1 (≤k0), k0/|ṽ|·((k1−|ṽ|)/(k1−k0))² (k0<|ṽ|≤k1), 0 (>k1); k0,k1 theo bài.
- FR2: w → nhân lên R (covariance scale) thay `covarianceScale` ad-hoc; reject khi w=0.
- FR3: xoá ngưỡng vật lý tự đặt; giới hạn cứng (tốc độ không thể) chỉ giữ nếu ghi provenance "hardware/physical limit".
- FR4: gap > ngưỡng → segment break (không nội suy) giữ như hiện tại, ghi provenance.
## Đánh giá
TU Wien (2694 epoch RTK), SnapperGPS. Metric: RMSE, MAE, adjacent-distance error vs RTK; so raw, Fixed Alpha, gate hiện tại. Ablation: gate-only (không AEKF) và gate+SDD-03.
## Test
Unit hàm trọng số tại k0, k1 (giá trị biên); inject outlier tổng hợp; regression test pipeline. Chấp nhận: không tệ hơn gate hiện tại về RMSE & dist err trên held-out, hoặc KEEP-CURRENT.

## Bài báo & phương trình (S0: đối chiếu PDF)
**[Y01]** https://doi.org/10.1007/s001900000157 — xem [PAPERS.md](../PAPERS.md).
Hàm trọng số IGG-III cho residual chuẩn hoá `ṽ_i = |v_i| / σ_{v_i}`:
`w_i = 1` nếu ṽ ≤ k0; `w_i = (k0/ṽ)·((k1−ṽ)/(k1−k0))²` nếu k0 < ṽ ≤ k1; `w_i = 0` nếu ṽ > k1.
Hiệu chỉnh hiệp phương sai quan sát: `R̄_i = R_i / w_i` (w=0 ⇒ loại quan sát). Giá trị k0, k1 lấy **đúng bài** (S0: ghi lại trang/phương trình; không tự chọn).
## Giao diện & file
- `lib/features/workout/domain/services/trajectory_preprocessing/robust_igg3_weight.dart` (hàm thuần `double igg3Weight(double vTilde, {k0, k1})`), adapter thay `mobile_gvio_quality_gate.dart`.
- Test: `test/trajectory_preprocessing/robust_igg3_weight_test.dart` (w=1 tại k0, w=0 tại k1, liên tục, đơn điệu giảm).
- Benchmark: dùng `gnss_p01_p02_active_replay_test.dart` + biến thể.
## Constant provenance
| Hằng số | Nguồn |
|---|---|
| k0, k1 | [Y01] |
| σ_v | từ accuracy thiết bị báo + innovation covariance S = HPHᵀ+R (định nghĩa Kalman chuẩn) |
| gap break (5 s) | hiện tại tự đặt → đưa vào grid trên validation hoặc ghi "tự đặt, ngoài phạm vi paper" |
## Kế hoạch bước
S0 → S1 test hàm trọng số → S2 adapter → S3 chạy TU Wien/SnapperGPS: raw, Fixed Alpha, gate cũ, gate IGG-III → S4 báo cáo → S5 quyết định.
