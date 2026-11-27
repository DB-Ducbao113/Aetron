# SDD-04 Kiểm toán & Ablation A/B cho StepMotionGate (Giữ Oxford WPD / Xu 2022 / Skog MV-GLRT)

> ## HƯỚNG NGHIÊN CỨU & VAI TRÒ TRONG THESIS
> - **Phạm vi (Minimal-Change):** **GIỮ NGUYÊN** bộ đếm bước [S18] Oxford WPD, [X22] Xu 2022 và bộ lọc đứng yên MV-GLRT [Sk10] vốn đã đạt kết quả tốt. Mục tiêu của SDD này là **tách bạch nguồn gốc hằng số** (đối chiếu PDF [S18] đã tải) và **chạy thí nghiệm A/B bật/tắt** `StepMotionGate` (`step_motion_gate.dart`) để báo cáo trung thực tác động của phần thiết kế kỹ thuật riêng.
> - **Bài báo đã kiểm S0 từ PDF:**
>   - **[S18]** Salvi et al. (EMBC 2018, `10.1109/EMBC.2018.8513319`, [PDF cục bộ](../papers/10_1109_EMBC_2018_8513319.pdf)) — **Table III (trang 4):** `M=13`, Gaussian window `SD=0.35`, cutoff `3 Hz`, Mean Difference `N=35`, threshold `c=1.2`, post-processing `t_window=200 ms`.
>   - **[X22]** Xu et al. (Remote Sensing 2022, `10.3390/rs14122926`).
>   - **[Sk10]** Skog et al. (IEEE TBME 2010, `10.1109/TBME.2010.2060723`) — MV-GLRT ZUPT.
>   - **[BH13]** Brajdic & Harle (UbiComp 2013, `10.1145/2493432.2493449`) — tài liệu tham chiếu khái niệm bout, **không phải** nguồn gốc của 3 hằng số tự đặt trong Aetron.

## Yêu cầu cụ thể
1. **Đối chiếu code `oxford_step_detector.dart` với Table III của [S18]:** xác nhận mọi hằng số (`M=13`, `SD=0.35`, `3Hz`, `N=35`, `c=1.2`, `200ms`) đều khớp PDF hoặc ghi rõ sai khác nếu có.
2. **Làm rõ comment & provenance trong `step_motion_gate.dart`:**
   - Ghi rõ: MV-GLRT là của Skog [Sk10]; còn `kMinBoutSteps = 5`, `kMaxBoutBuildGap = 2200 ms`, `kActiveBoutTimeout = 3500 ms`, và ngưỡng GPS displacement `2.5 m` là **Engineering Design của Aetron**, được lấy cảm hứng từ [BH13] nhưng không phải hằng số trích từ bài báo.
3. **Thí nghiệm A/B (không thay thế nếu chưa chứng minh tốt hơn):**
   - Chạy `oxford_wpd` (12 traces, 4,107 ref steps) & `xu_group3` (5 traces, 1,280 ref steps) + tập đứng yên/gõ màn hình (`2.2 m/s²`) dưới 3 cấu hình:
     - (A) Raw detector (Oxford / Xu thuần, tắt cả MV-GLRT và Bout Gate)
     - (B) Detector + MV-GLRT (không Bout Gate)
     - (C) Detector + MV-GLRT + Bout Gate (hiện tại của Aetron)
   - Đo: Macro Count Accuracy, WAPE, False steps/phút khi đứng yên.
4. **Quyết định:** Nếu (C) giữ `100%` loại bước giả mà không làm tụt Count Accuracy $> 0.5\%$ so với (A), **GIỮ NGUYÊN (C)** và đưa bảng A/B vào Chương 4 Thesis như bằng chứng ablation. Nếu tụt mạnh, mở cờ cấu hình hoặc tinh chỉnh trên validation.
