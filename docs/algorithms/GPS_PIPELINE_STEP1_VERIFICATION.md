# Aetron GPS — Bước 1: Raw Signal Continuity & Distance Provenance

## Phạm vi

Target: một pipeline chung cho Fixed-Alpha + Turn-Boost và EKF 4-State. Đã dựa
trên nhánh parity `experiment/ekf4-main-policy-parity` (PR #13); không sửa
`main`, EKF core, Q/R, DBSCAN hoặc thuật toán R-Opt.

## Lỗi đã kiểm tra bằng code review

1. Live: `WorkoutTrackingEngine.evaluateGpsUpdate()` trước đây dùng
   `lastAcceptedPositionTime` để phát hiện mất GPS. Với 60 giây đứng yên,
   raw fixes vẫn đến đều nhưng bị bỏ qua do tiny segment; lần chạy tiếp theo
   có thể bị coi là mất GPS và vẽ đường đứt giả.
2. Finalize: `analyzeGpsWorkout()` tính gap giữa các điểm sau
   `_filterRawPositions()`, vô tình gộp các khoảng bị validation loại bỏ
   thành thời gian mất tín hiệu.
3. Finalizer: `session.distanceKm` ưu tiên `gpsAnalysis.validDistanceKm`,
   trong khi `filteredRouteJson` là đường hình học sau smoothing. Hai cự ly
   vốn không nhất thiết bằng nhau, nhưng trước đây metadata chưa tách đủ
   live/saved/filtered để chẩn đoán.

## Thay đổi được triển khai

- `GpsRawSignalContinuity`: quan sát timestamp raw theo thứ tự tăng, ghi
  khoảng tín hiệu thật sự bị ngắt, giữ pending gap qua các fix bị loại và chỉ
  xóa khi chấp nhận anchor. Bỏ qua raw fix cũ/trùng trong route, vẫn lưu
  journal để audit.
- Live engine có tham số `rawGpsGapDurationSec` để phân biệt blackout với
  accepted-fix drought. Code cũ không truyền tham số vẫn theo chính sách
  accepted-gap cũ, để các caller legacy không đổi ngầm.
- Re-anchor sau blackout thực ngay cả khi vị trí trở lại gần anchor cũ hơn
  ngưỡng minimum segment; không cộng khoảng vượt gap thành quãng đường.
- Finalize đếm raw gaps từ dữ liệu raw gốc trước khi lọc; raw fixes bị loại
  bởi validation không tự biến thành GPS outage.
- Thêm metadata `raw_gps_fix_count`, `distance_selection_policy`,
  `live_distance_km`, `saved_distance_km`,
  `saved_minus_live_distance_km`,
  `filtered_minus_saved_distance_km`. **Không đổi lựa chọn quãng đường lưu**.
- Điều chỉnh test baseline first-fix cycling 20m và cập nhật test accepted-fix
  8 giây nhưng raw stream vẫn liên tục; thêm regression tests synthetic.

## Test cần chạy (CHƯA CÓ BẰNG CHỨNG PASS)

```bash
flutter pub get
flutter analyze
flutter test test/gps_raw_signal_continuity_test.dart
flutter test test/ekf4_field_recording_readiness_test.dart
flutter test test/workout_recording_architecture_test.dart
flutter test test/gps_pipeline_test.dart
flutter test test/gps_smoothing_service_test.dart
flutter test
```

Các trường hợp test mới: đứng 60 giây với raw 1Hz, mất raw 15 giây,
first fix sau gap rất gần anchor cũ, first fix lỗi accuracy rồi mới hồi phục,
GPS teleport, turn 90°, slow cycling, paired Fixed-Alpha/EKF trên cùng
accepted input, duration gap của finalizer trước/sau prefilter và
distance audit.

## Việc phải kiểm tra bổ sung trước khi ký PASS

1. Review PR #13: 5s là chính sách lịch sử `main`, không phải chứng minh
   đó là ngưỡng thích hợp trong mọi môi trường. Bài test phải phân biệt
   `lastGpsEventTime`, `lastRawFixTimestamp` và
   `lastAcceptedPositionTime`.
2. Replay workout GPS thực có 1.878 raw fixes, xác nhận start, stop/resume,
   route polyline, blackout, stationary gap và nguyên nhân của chênh lệch
   `live_distance_km` vs `saved_distance_km`. Raw tọa độ không commit.
3. Thử end-to-end recording trên máy thật sau khi test pass, kiểm tra
   checkpoint/snapshot/local/remote persistence và không làm mất route đầu.
4. Giữ nguyên lịch sử và evidence nghiên cứu. Không suy diễn sửa pipeline là
   EKF chính xác hơn Fixed-Alpha.
5. PR #14 sửa ngoặc nhọn ở `requestRecenter` cũng đã được cherry-pick về
   mặt nội dung trong branch này để analyzer không bị blocker lint đó.
   Tránh merge lại cùng một thay đổi nếu đã được áp dụng.

## Release decision

**PENDING / NOT READY FOR FIELD FINAL**: Chỉ được duyệt Bước 1 khi regression
tests, analyzer, full suite, paired replay dữ liệu thực và kiểm thử record
tại thiết bị đều được xác minh. PR này là draft để review, không merge
`main` và không xác nhận bằng chứng chưa chạy.
