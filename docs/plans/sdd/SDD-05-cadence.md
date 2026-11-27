# SDD-05 Cadence — Kiểm toán Provenance & Đối sánh A/B (6s Window vs Step-Interval Median)

> ## HƯỚNG NGHIÊN CỨU & VAI TRÒ TRONG THESIS
> - **Phạm vi (Minimal-Change):** **GIỮ NGUYÊN** `CadenceCalculatorService` (cửa sổ trượt 6 giây, đã đo giảm dao động `50.0%`, MAE `8.41 spm`) với nhãn trung thực là **Engineering Design** trong bảng Provenance. Bổ sung thêm chế độ so sánh A/B với định nghĩa thuần khoảng bước `60 / Δt_step` trên Oxford 2,347 windows & Xu Group 3 để có số liệu đối chứng khoa học.

## Yêu cầu cụ thể
1. **Provenance:** Gắn nhãn cửa sổ `6.0 s` trong `lib/core/services/cadence_calculator_service.dart` là *Engineering Design* (không gán cho bài báo nào).
2. **Thí nghiệm đối sánh A/B:** So sánh `window6s` (hiện tại) vs `stepIntervalMedian(N)` ($N \in \{3, 5, 8\}$ bước, chọn trên validation) trên cùng benchmark Oxford (2,347 windows, hiện tại `12.092 spm` MAE) và Xu Group 3 (`2.02 spm` MAE).
3. **Quyết định:** Giữ cấu hình nào đạt MAE thấp hơn và ổn định hơn trên test held-out; giữ nguyên fallback handling khi OS không trả timestamp từng bước.
