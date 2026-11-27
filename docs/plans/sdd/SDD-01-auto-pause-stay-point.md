# SDD-01 Auto-Pause = xác suất chế độ stationary trong IMM ([BB88]); Zheng 2009 = comparator

> **[OPTIONAL / FUTURE WORK]** Auto-Pause bằng T-DBSCAN hiện tại ĐÃ ĐẠT 98.97% precision trên STAGA — giữ nguyên cho Thesis; IMM / Zheng 2009 là OPTIONAL / FUTURE WORK.

> ## ĐỒNG NHẤT HƯỚNG (cập nhật 2026-11-27)
> Theo [UNIFIED_RESEARCH_DIRECTION.md](../UNIFIED_RESEARCH_DIRECTION.md): hướng chính là **IMM stationary/moving** ([BB88] Blom & Bar-Shalom, 10.1109/9.1299, cài trong SDD-08); `paused = MAP(mode)`. Zheng stay-point bên dưới chỉ còn là **comparator** (offline/causal) để so F1; không còn là runtime chính. Loại: Adaptation. Siêu tham số Π, Q_stationary: validation only.

> ## HƯỚNG NGHIÊN CỨU (khai báo rõ)
> - **Hướng:** Stay-point detection (phát hiện điểm dừng theo thời gian–không gian)
> - **Bài báo nền:** [Z09] Zheng et al., WWW 2009, 10.1145/1526709.1526816
> - **Loại:** ADAPTATION: bài gốc offline, thang đô thị → bản causal, θd/θt tune trên validation
> - **Lấy từ bài:** Ý tưởng/định nghĩa stay point; phương trình dist<θd & Δt≥θt
> - **KHÔNG lấy từ bài (phải khai báo trong báo cáo):** Cơ chế neo causal; giá trị θd, θt; định nghĩa nhãn stop từ tốc độ RTK
> - **Loại bỏ/không dùng:** Không dùng Skog (SHOE cần IMU gắn chân, không hợp điện thoại); T-DBSCAN chỉ so sánh offline
**Mục tiêu:** thay ngưỡng tự đặt (3 s / 60 s) bằng stay-point detection công bố, dạng causal.
**Paper:** Zheng, Zhang, Xie, Ma — WWW 2009, 10.1145/1526709.1526816 (verify). Stay point: chuỗi điểm liên tiếp i..j có dist(p_i,p_k) < θd ∀k và t_j − t_i ≥ θt.
**Phạm vi code:** `workout_tracking_engine.dart` (nhánh rest/stationary), `stay_point_segmenter.dart`, `dbscan/gps_dbscan_service.dart`. Tạo `lib/features/workout/domain/services/stop_detection/zheng_stay_point_detector.dart` (interface `StopDetector`, cài song song).
## Yêu cầu
- FR1: input = fix đã qua P01/P02 (lat, lon, t); output = event `StopStart(t_detect, t_onset)`, `StopEnd`.
- FR2: causal — chỉ dùng quan sát ≤ t; công bố độ trễ = θt.
- FR3: θd, θt chọn **chỉ trên validation split**; ghi mọi giá trị thử.
- NFR: O(n) amortized, bộ nhớ cửa sổ ≤ θt; không dùng GT.
## Công bố khác biệt
Paper gốc offline và thang đô thị (θd=200 m, θt=20 min) → bản workout là *adapted*; T-DBSCAN (Chen 2014) offline nên chỉ là comparator tham khảo.
## Đánh giá
Nhãn stop: segment mà tốc độ RTK tham chiếu < v_stop (định nghĩa nhãn, cố định trước, không phải input). Split theo session. Metric: precision/recall/F1, false STOP/h, latency chuyển trạng thái. So với: code hiện tại, bản paper tham số gốc, bản paper tham số validation. **Không** so với Fixed Alpha.
## Test
Unit: chuỗi tổng hợp đứng yên/đi/đứng; causal (cắt tương lai không đổi output); biên θd/θt. Benchmark script `tooling/benchmark/autopause_eval.dart`.
## Chấp nhận
F1 ≥ code hiện tại trên test held-out và không tăng false STOP; nếu không → KEEP-CURRENT. Data gap: không có nhãn người cho hoạt động thật → ghi rõ.

## Bài báo & phương trình (S0: đối chiếu PDF)
**[Z09]** https://doi.org/10.1145/1526709.1526816 — xem [PAPERS.md](../PAPERS.md).
Stay point từ chuỗi P = {p_i..p_j}: `Distance(p_i,p_k) < θd` với mọi k∈[i,j] và `T_j − T_i ≥ θt`; toạ độ stay point = trung bình các p_k. Thuật toán gốc quét tuyến tính, đặt i=j+1 sau khi phát hiện.
**Bản causal của Aetron:** giữ neo p_i; mỗi fix mới, nếu dist(p_i,p_new) ≥ θd thì dịch neo; nếu đã đạt `t_new − T_i ≥ θt` và vẫn trong θd ⇒ phát `StopStart(onset=T_i)`. Đây là *adaptation* (bài gốc offline) → ghi vào báo cáo.
## Giao diện & file
- `abstract class StopDetector { StopEvent? update(TrajectoryPoint p); void reset(); }`
- `lib/features/workout/domain/services/stop_detection/zheng_stay_point_detector.dart`, test `test/stop_detection/zheng_stay_point_detector_test.dart`, benchmark `tooling/benchmark/autopause_eval.dart`.
- Feature flag `AETRON_STOP_DETECTOR=zheng|legacy`.
## Constant provenance
| Hằng số | Nguồn |
|---|---|
| θd, θt | lưới tìm trên validation split; bài gốc 200 m / 20 phút (đô thị, không dùng được) |
| v_stop (nhãn) | định nghĩa nhãn, cố định trước khi chạy, không là input thuật toán |
## Kế hoạch bước
S0 đối chiếu PDF → S1 test đỏ → S2 detector → S3 harness + split theo session → S4 chạy legacy vs paper → S5 báo cáo `docs/research/AUTOPAUSE_ZHENG_<date>.md` → S6 quyết định.
