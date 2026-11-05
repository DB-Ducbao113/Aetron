# KIỂM TOÁN TẬP DỮ LIỆU GPS THỰC ĐỊA CUỐI CÙNG (FINAL GPS DATASET AUDIT)
## HỆ THỐNG ĐỊNH VỊ VÀ ĐO ĐẠC HÀNH TRÌNH AETRON

> **Tài liệu:** `GPS_FINAL_DATASET_AUDIT.md`  
> **Dự án:** Aetron — Flutter Fitness Tracking Application  
> **Repository:** `DB-Ducbao113/FitnessExerciseApplication`  
> **Nhánh thực thi:** `fix/gps-step1-raw-signal-gap`  
> **Commit kiểm toán:** `4fcaf8f` (HEAD)  
> **Thời điểm thẩm định:** 05/11/2026 12:35 (UTC+7)  
> **Tài khoản thu thập thực địa:** `user1` (`user1@aetron.local` / UUID: `3e0069df-41f2-4491-856d-611c836fd181`)  
> **Thiết bị phần cứng thu thập:** iPhone ("Bảo Bụng Bự" — Apple CoreLocation via Geolocator Stream)  
> **Tệp dữ liệu xuất chuẩn hóa:** `exports/research_7_sessions/aetron_7_new_sessions_raw.csv`  
> **Mã băm toàn vẹn (SHA-256):** `f167931a9d9e6a33c6e9a6c59c66b59adc1f04ca8e773be3b34a0a72aa9ce111`  
> **Quy mô tập dữ liệu mới:** 595 bản ghi GPS thô (1 tiêu đề + 595 dòng dữ liệu)

---

## 1. MỤC TIÊU VÀ NGUYÊN TẮC KIỂM TOÁN DỮ LIỆU

Mục tiêu của báo cáo này là kiểm toán toàn diện tính toàn vẹn khoa học, chất lượng tín hiệu cảm biến và tính tương thích phiên bản của **7 buổi tập thực tế mới thu thập** trên thiết bị thật, phục vụ việc lựa chọn thuật toán lọc GPS cuối cùng cho môi trường vận hành (production) của Aetron.

### Các nguyên tắc khoa học bất biến:
1. **Không tráo đổi tập dữ liệu (No Substitution):** Tuyệt đối không thay thế 7 phiên thực địa mới thu thập bằng 7 phiên đạp xe lịch sử cũ (10.779 fixes tại `exports/aetron_raw_gps_combined.csv`).
2. **Minh bạch lỗi ghi nhận (No Silent Exclusion):** Mọi hiện tượng mất mẫu, ngắt sóng, hay lỗi đệm tải lên (truncated upload) phải được phơi bày nguyên trạng, truy tìm tận gốc mã nguồn và ghi nhận rõ ràng.
3. **Trung thực về Ground Truth:** Không ngộ nhận dữ liệu thực địa ngoài đường phố là có Ground Truth khi không có thiết bị đo đạc trắc địa chuyên dụng (RTK-GNSS).
4. **Bảo tồn dữ liệu thô (Raw Provenance):** Mọi đánh giá thuật toán phải xuất phát từ cùng một dòng tọa độ và thời gian thô do phần cứng phát sinh.

---

## 2. DANH MỤC CHI TIẾT 7 PHIÊN THỰC ĐỊA MỚI THU THẬP

Toàn bộ 7 buổi tập thực tế được người dùng `user1` thực hiện trên cùng một cung đường đạp xe vòng lặp (~1,0 km) tại khu vực Quận 6 / Bình Tân, TP.HCM (Tọa độ: $10.7359^\circ\text{N} - 10.7391^\circ\text{N}$, $106.6235^\circ\text{E} - 106.6255^\circ\text{E}$).

### Bảng 1: Bảng kiểm kê chi tiết 7 phiên thực địa
| STT | Nhóm phiên | Workout ID | Thời gian bắt đầu (UTC) | Thời gian kết thúc (UTC) | Thời lượng | Cự ly Live | Số Raw Fixes | Dải Accuracy (m) | Vận tốc TB (km/h) | Số GPS Gaps (>5s) | Trạng thái dữ liệu thô |
|:---:|:---:|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **1** | Nhóm 1 (Pre-Fix) | `1e26939b-81cb-4903-b109-50c13d270c06` | 2026-11-03 13:53:35 | 2026-11-03 13:56:05 | 144s | 1.019 km | 143 | 4.7 – 96.1 (TB: 10.8) | 23.7 km/h | 1 gap (5.44s) | **ĐẦY ĐỦ 100% (Valid)** |
| **2** | Nhóm 1 (Pre-Fix) | `e64747d3-9c21-4043-87fe-2cad7f4acedc` | 2026-11-03 14:10:32 | 2026-11-03 14:12:54 | 142s | 1.045 km | 143 | 8.0 – 46.3 (TB: 10.0) | 24.2 km/h | 0 gap | **ĐẦY ĐỦ 100% (Valid)** |
| **3** | Nhóm 1 (Pre-Fix) | `dd24bacf-dfba-495d-bad7-2a23d9d7363e` | 2026-11-03 14:13:01 | 2026-11-03 14:15:30 | 149s | 1.001 km | 138 | 8.0 – 14.2 (TB: 8.5) | 25.3 km/h | 1 gap (8.00s) | **ĐẦY ĐỦ 100% (Chứa gap 8s)** |
| **4** | Nhóm 2 (Post-Fix) | `cd4da398-b5d2-48f0-9065-cb6dce5f9cbf` | 2026-11-05 03:29:59 | 2026-11-05 03:32:23 | 143s | 0.998 km | 9 | 12.4 – 18.6 (TB: 14.8) | 6.5 km/h* | 0 gap | **BỊ CẮT XÉN (Truncated: 8s)** |
| **5** | Nhóm 2 (Post-Fix) | `5a777e45-7c8c-4f98-8f69-7b465034682d` | 2026-11-05 03:32:37 | 2026-11-05 03:35:11 | 153s | 1.003 km | 10 | 9.0 – 22.2 (TB: 16.2) | 7.5 km/h* | 0 gap | **BỊ CẮT XÉN (Truncated: 12s)** |
| **6** | Nhóm 2 (Post-Fix) | `18c54f6e-4c4f-4b93-a114-51fbde02b6e1` | 2026-11-05 03:35:18 | 2026-11-05 03:37:45 | 147s | 1.005 km | 4 | 18.6 – 56.0 (TB: 30.2) | 1.3 km/h* | 0 gap | **BỊ CẮT XÉN (Truncated: 7s)** |
| **7** | Nhóm 2 (Post-Fix) | `93af3737-54c0-456a-8e2a-62319ce898aa` | 2026-11-05 03:37:52 | 2026-11-05 03:40:30 | 158s | 1.004 km | 148 | 8.0 – 58.2 (TB: 10.2) | 22.1 km/h | 0 gap | **ĐẦY ĐỦ 100% (Valid)** |
| **TỔNG** | **7 Buổi thực địa** | — | — | — | **1.036s** | **7.116 km** | **595** | — | — | **2 gaps** | **4 phiên Full / 3 phiên Truncated** |

*\* Ghi chú: Vận tốc trung bình của phiên 4, 5, 6 bị kéo thấp cục bộ do các điểm thô lưu được chỉ nằm ở 7-12 giây đầu tiên lúc người dùng vừa bấm xuất phát.*

---

## 3. PHÂN ĐỊNH VÀ LOẠI TRỪ CÁC DỮ LIỆU KHÔNG THUỘC PHẠM VI

Để tránh nhầm lẫn dữ liệu, các tập dữ liệu sau đây được nhận diện và phân định dứt khoát:
1. **Tập dữ liệu lịch sử (`exports/aetron_raw_gps_combined.csv` — 10.779 fixes):** Thu thập ngày 14–15/10/2026 với 7 phiên đạp xe dài từ $18$ đến $44$ phút. Đây là tập dữ liệu đối chứng của PR #15 (Bước 1 & Bước 2 cũ), không phải là tập dữ liệu kiểm chuẩn mới.
2. **Hai phiên đi bộ ngày 11/10/2026 (`d48a81b4`, `ebc2047b`):** Thời lượng chỉ 35–38 giây, 0 raw points trên bảng đám mây, là các bài test giao diện ban đầu. Loại trừ.
3. **Hai phiên đạp xe sơ bộ ngày 02–03/11/2026 (`a102a633`, `f2afdf52`):** Phiên `f2afdf52` gặp sự cố luồng GPS watchdog khởi động lại liên tục (12 fixes), phiên `a102a633` thu thập trước khi quy chuẩn hóa quy trình test 1 km. Loại trừ khỏi bộ 7 phiên chuẩn.

---

## 4. KIỂM TOÁN TÍNH TOÀN VẸN DỮ LIỆU (DATA INTEGRITY AUDIT)

### 4.1. Tọa độ và Sai số vệ tinh
- **Tọa độ null / NaN:** $0$ trường hợp ($0\%$). Toàn bộ kinh độ, vĩ độ nằm chính xác trong hình chữ nhật đô thị TP.HCM.
- **Accuracy null:** $0$ trường hợp. Giá trị sai số vệ tinh dao động từ $4.7\text{ m}$ đến $96.1\text{ m}$. Đa số ($> 85\%$) nằm trong khoảng $8.0 - 14.0\text{ m}$.
- **Tốc độ cảm biến (Speed):** Tối đa $11.92\text{ m/s}$ ($42.9\text{ km/h}$), hoàn toàn hợp lý với vận tốc đạp xe thực tế, không có bước nhảy vận tốc siêu thực ($> 150\text{ km/h}$).

### 4.2. Tính thứ tự và Trùng lặp Timestamp
- **Bản ghi lùi thời gian (Out-of-Order):** $0$ bản ghi ($0\%$). Bộ đệm của iOS CoreLocation cung cấp chuỗi thời gian đơn điệu tăng.
- **Bản ghi trùng lặp (Duplicate Timestamp):** Chỉ phát hiện đúng $1$ bản ghi trùng thời gian tại Phiên 5 (`2026-11-05T03:32:37.319`), được `GpsRawSignalContinuity` gạt bỏ an toàn.

### 4.3. Phân tích nguyên nhân gốc rễ lỗi tải thiếu dữ liệu thô (Truncated Uploads)
Tại Phiên 4, 5, 6, trong khi cự ly live và polyline lưu trữ (`filtered_route_json`) ghi nhận đầy đủ $115, 122, 121$ điểm (~$1.0\text{ km}$), bảng dữ liệu thô `raw_gps_points` trên Supabase chỉ nhận được lần lượt $9, 10, 4$ bản ghi đầu tiên.

**Nguyên nhân kỹ thuật đã được xác định chính xác trong mã nguồn:**
Trong tệp `lib/features/workout/presentation/screens/record/record_providers.dart`:
```dart
// Dòng 830: Gọi xả hàng đợi raw GPS bất đồng bộ (unawaited)
unawaited(
  _recordingCoordinator.flushPendingRawTracking(
    workoutId: finalization.sessionId,
    force: true,
  )
);
// Dòng 840: Mới đánh dấu shell sẵn sàng!
_recordingCoordinator.markRemoteWorkoutShellReady();
```
Trong khi đó, hàm `flushPendingRawTracking` trong `workout_recording_coordinator.dart` có điều kiện bảo vệ:
```dart
if (!_remoteWorkoutShellReady) return;
```
Do `_remoteWorkoutShellReady` chỉ chuyển thành `true` **sau** khi lệnh flush đã trả về, các bản ghi thô tích lũy trong RAM không được đẩy lên Supabase lúc kết thúc buổi tập mà phải chờ Timer định kỳ 5 giây. Nếu người dùng đóng màn hình hoặc chuyển tab ngay sau khi hoàn thành, phương thức `reset()` được kích hoạt và xóa sạch mảng `_pendingRawGpsPoints`, làm mất các điểm thô chưa kịp đồng bộ!
Chỉ ở Phiên 7 (`93af3737`), do người dùng giữ màn hình đủ lâu, toàn bộ $148$ điểm thô mới được đẩy lên đám mây trọn vẹn.

---

## 5. ĐÁNH GIÁ TƯƠNG THÍCH ĐA PHIÊN BẢN (CROSS-VERSION COMPATIBILITY)

| Tiêu chí | Nhóm 1: Pre-Fix (Phiên 1, 2, 3) | Nhóm 2: Post-Fix (Phiên 4, 5, 6, 7) | Đánh giá tương thích |
|---|---|---|---|
| **Commit thu thập** | Trước commit `4fcaf8f` (Nov 3) | Sau commit `4fcaf8f` (Nov 5) | Có sự khác biệt logic phục hồi watchdog |
| **Tần số lấy mẫu GPS** | $1.0\text{ Hz}$ (Khoảng cách TB: $1.00 - 1.09\text{s}$) | $1.0\text{ Hz}$ (Khoảng cách TB: $1.05\text{s}$ ở Phiên 7) | **Tương thích hoàn toàn** |
| **Cơ chế Watchdog phục hồi** | Khởi động lại luồng ngay khi tĩnh lặng $> 5\text{s}$ | Thêm Cooldown $15\text{s}$ và kiểm tra độ tươi tọa độ | Nhóm 2 ổn định hơn, không bị bão khởi động |
| **Cơ chế tính Calo tĩnh** | Calo có thể tích lũy nhẹ khi trôi GPS | Khóa chặt `movingDurationSec`, triệt tiêu calo ảo | Cải thiện chất lượng dữ liệu |
| **Độ nguyên vẹn dữ liệu thô** | $3/3$ phiên đầy đủ $100\%$ ($424$ fixes) | $1/4$ phiên đầy đủ, $3/4$ phiên bị ngắt upload | **Không đồng nhất về độ bao phủ** |

---

## 6. KẾT LUẬN TÍNH HỢP LỆ CỦA TẬP DỮ LIỆU (ELIGIBILITY DECISION)

Dựa trên kết quả thẩm định thực chứng:

1. **Nhóm đủ điều kiện chạy Benchmark Replay Toàn phần (Full-Route Benchmark):**
   - **Phiên 1 (`1e26939b` — 143 fixes):** Tuyến hoàn chỉnh, có 1 gap ngắn 5.4s. **HỢP LỆ.**
   - **Phiên 2 (`e64747d3` — 143 fixes):** Tuyến hoàn chỉnh, sóng GPS liên tục 100%. **HỢP LỆ.**
   - **Phiên 3 (`dd24bacf` — 138 fixes):** Tuyến hoàn chỉnh, **chứa khoảng mất sóng phần cứng 8.0s thực tế**. Đây là trường hợp kiểm thử biên cực kỳ giá trị để thẩm định an toàn ngắt tuyến. **HỢP LỆ.**
   - **Phiên 7 (`93af3737` — 148 fixes):** Tuyến hoàn chỉnh trên mã nguồn mới nhất (Post-Fix). **HỢP LỆ.**
   *Tổng cộng 4 phiên này cung cấp $572$ điểm thô hoàn chỉnh, đại diện đầy đủ cho cả trước và sau bản sửa lỗi.*

2. **Nhóm đủ điều kiện một phần (Partially Valid / Limited Eligibility):**
   - **Phiên 4, 5, 6 (`cd4da398`, `5a777e45`, `18c54f6e` — tổng cộng 23 fixes):**
     Do lỗi đệm tải lên phía máy khách, dữ liệu thô chỉ phản ánh 7–12 giây đầu của buổi tập. Nhóm này **chỉ hợp lệ để đánh giá phản ứng khởi tạo tuyến (Seed Route & Initial Jitter)**, **KHÔNG HỢP LỆ để tính toán cự ly lũy kế hay so sánh độ mượt của toàn bộ tuyến đường**.

