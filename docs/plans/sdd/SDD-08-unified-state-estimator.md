# SDD-08 Khung ước lượng trạng thái Bayes thống nhất (tích hợp)

> **[OPTIONAL / FUTURE WORK]** Khung hợp nhất toàn bộ IMM + GNSS + PDR vào một bộ lọc duy nhất — thuộc OPTIONAL / FUTURE WORK trong Chương 5 Thesis.
> ## HƯỚNG NGHIÊN CỨU
> - **Hướng:** Recursive Bayesian state estimation cho điện thoại ([UNIFIED_RESEARCH_DIRECTION.md](../UNIFIED_RESEARCH_DIRECTION.md))
> - **Bài nền:** [K60] 10.1115/1.3662552; [BB88] 10.1109/9.1299; GNSS/PDR EKF 10.1134/S2075108720020054 (S0 đọc mô hình đo)
> - **Loại:** kiến trúc tích hợp của Aetron — KHÔNG phải reproduction; từng thành phần mang loại riêng ở SDD-01..07
> - **Siêu tham số ngoài bài:** Π, Q_stationary, R_pdr, m — validation only

## Mục tiêu
Một giao diện `StateEstimator` duy nhất mà GNSS (SDD-02/03), mode stop/move (SDD-01), PDR (SDD-04/05), IO gating (SDD-06) cùng cắm vào; route matching (SDD-07) nhận đầu ra.
## Thiết kế
- Trạng thái x=[e,n,v_e,v_n]; mô hình CV (K60). IMM 2 chế độ: *moving* (CV, Q_m) và *stationary* (v≈0, Q_s nhỏ), trộn theo [BB88]: mixing → mode-matched filters → cập nhật μ_j theo likelihood Λ_j → kết hợp.
- Quan sát: z_gnss (R từ IAE, trọng số IGG-III); z_pdr = [speed] với speed = L_step × cadence (L_step từ [R12] cho walking/running).
- Auto-Pause: `paused = argmax μ_j == stationary` (quy tắc MAP, không có ngưỡng tự đặt); onset/latency được báo cáo.
- IO gating: nếu IO=indoor → bỏ z_gnss (hoặc nâng R) — quy tắc tích hợp, ablation.
- API: `abstract class StateEstimator { void predict(DateTime t); void updateGnss(GnssObs o); void updatePdr(PdrObs o); StateEstimate get estimate; ModeProbabilities get modes; }`
- File: `lib/features/workout/domain/services/estimation/{state_estimator.dart,imm_estimator.dart,gnss_update.dart,pdr_update.dart}`; flag `AETRON_ESTIMATOR=unified|legacy`.
## Yêu cầu
FR1 causal; FR2 mọi cập nhật có log innovation/NIS để kiểm nhất quán; FR3 không phụ thuộc UI; FR4 legacy giữ nguyên khi flag=legacy.
## Đánh giá (ablation, H1–H4)
Cấu hình: raw · Fixed Alpha · legacy · +IGG3 · +IAE · +IMM · +PDR · +IO gate · full. Dataset: TU Wien, SnapperGPS (GNSS/dừng), Oxford/Xu (bước), CIOD (IO). Metric: RMSE/MAE/dist err; P/R/F1 + false STOP + latency; lỗi trong artificial gap. Split theo session, tune ở validation.
## Test
Unit: IMM μ tổng =1, chuyển mode khi dữ liệu đứng yên/di chuyển giả lập; NIS χ² nhất quán; legacy parity; `flutter analyze` + `flutter test`.
## Chấp nhận
Mỗi thành phần ADOPT chỉ khi ablation cho thấy không tệ hơn; khung toàn bộ chỉ ADOPT nếu full ≥ legacy trên metric đăng ký trước, ngược lại KEEP legacy và báo cáo kết quả âm.
