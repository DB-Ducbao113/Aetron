# SDD-03 AEKF = Innovation-based adaptive estimation (Mohamed & Schwarz 1999)

> **[OPTIONAL / FUTURE WORK]** 4-state AEKF-NIS hiện tại ĐÃ ĐẠT 3.432 m RMSE / 1.34% dist err trên TU Wien — giữ nguyên cho Thesis; IAE Mohamed & Schwarz 1999 là OPTIONAL / FUTURE WORK.

> **Vai trò trong hướng thống nhất:** thành phần thích nghi R của bộ lọc thống nhất (SDD-08). Xem [UNIFIED_RESEARCH_DIRECTION.md](../UNIFIED_RESEARCH_DIRECTION.md).

> ## HƯỚNG NGHIÊN CỨU (khai báo rõ)
> - **Hướng:** Innovation-based adaptive estimation (IAE) cho Kalman filter
> - **Bài báo nền:** [MS99] Mohamed & Schwarz, J. Geodesy 1999, 10.1007/s001900050236
> - **Loại:** ADAPTATION: bài cho INS/GPS; áp dụng mô hình 4-state constant-velocity chỉ-GNSS
> - **Lấy từ bài:** Ĉ_v theo cửa sổ, R̂=Ĉ_v−HPHᵀ (hoặc Q̂=KĈ_vKᵀ)
> - **KHÔNG lấy từ bài (phải khai báo trong báo cáo):** Mô hình trạng thái 4-state; m; Q0/R0; xử lý R̂ âm nếu bài không nêu
> - **Loại bỏ/không dùng:** Bỏ NIS-adaptive tự thiết kế và logic drift-suppression trong gps_smoothing_service
**Mục tiêu:** thay AEKF NIS tự thiết kế bằng IAE công bố.
**Paper:** Mohamed A.H., Schwarz K.P., "Adaptive Kalman filtering for INS/GPS", J. Geodesy 73, 193–203 (1999) — verify DOI. Ước lượng Ĉ_v = (1/m)Σ v_i v_iᵀ trên cửa sổ m innovations; R̂ = Ĉ_v − HPHᵀ (và/hoặc Q̂ = KĈ_vKᵀ).
**Phạm vi:** `adaptive_gnss_correction_engine.dart`, `ekf/extended_kalman_filter.dart`, `gps_smoothing_service.dart`; mô hình trạng thái 4-state giữ (constant-velocity là Kalman chuẩn), phần thích nghi thay.
## Yêu cầu
- FR1: cửa sổ m, khởi tạo R0/Q0 từ accuracy do thiết bị báo; m chọn trên validation.
- FR2: đảm bảo R̂ ≥ 0 theo cách bài mô tả (không tự chế clip khác; nếu bài không nói, ghi là adaptation).
- FR3: bỏ logic "stationary drift suppression" tự đặt trong `gps_smoothing_service.dart`; chuyển trạng thái dừng cho SDD-01.
- FR4: không dùng accuracy như GT.
## Đánh giá
Cùng harness SDD-02. Metric RMSE/MAE/dist err; so raw (2.11 m), Fixed Alpha (8.75 m / 9.77%), legacy EKF, AEKF-NIS hiện tại (3.43 m / 1.34%). Báo cả kết quả âm (raw RMSE đang tốt hơn). Chỉ kết luận trên held-out sau khi tune ở validation, session holdout.
## Test
Unit: ổn định số (P đối xứng, dương), hội tụ với nhiễu giả lập đã biết (R̂→R thật), regression numeric trên fixture. ADOPT nếu dist err ≤ hiện tại và RMSE không xấu hơn; không thì KEEP-CURRENT.

## Bài báo & phương trình (S0: đối chiếu PDF)
**[MS99]** https://doi.org/10.1007/s001900050236 — xem [PAPERS.md](../PAPERS.md).
Innovation `v_k = z_k − H x̂_k⁻`. Ước lượng thực nghiệm trên cửa sổ m: `Ĉ_v = (1/m) Σ_{i=k−m+1..k} v_i v_iᵀ`.
- Thích nghi R: `R̂_k = Ĉ_v − H P_k⁻ Hᵀ`.
- Thích nghi Q: `Q̂_k = K_k Ĉ_v K_kᵀ`.
Bài trình bày cả hai dạng; chọn đúng một dạng cho 4-state CV model (S0 ghi rõ dạng nào và vì sao, ưu tiên R̂ do quan sát GNSS là nguồn bất định chính).
## Giao diện & file
- `ekf/innovation_adaptive_filter.dart` triển khai `GnssCorrectionInterface` cũ; `adaptive_gnss_correction_engine.dart` giữ làm bản legacy sau flag `AETRON_GNSS_FILTER=iae|nis_legacy`.
- Test: nhiễu giả lập R_true đã biết → R̂ hội tụ trong sai số tương đối đăng ký trước; P đối xứng & PSD qua mọi bước.
## Constant provenance
| Hằng số | Nguồn |
|---|---|
| m (cửa sổ) | validation grid |
| Q0, R0 khởi tạo | accuracy thiết bị / mô hình CV chuẩn; ghi rõ |
| xử lý R̂ âm | theo bài nếu có; nếu không → ghi "adaptation" |
## Đánh giá
RMSE/MAE/dist err vs RTK; so raw (2.113 m), Fixed Alpha (8.75 m, 9.77%), legacy EKF (10.18 m, 11.55%), AEKF-NIS (3.43 m, 1.34%). Báo cả trường hợp raw tốt hơn.
