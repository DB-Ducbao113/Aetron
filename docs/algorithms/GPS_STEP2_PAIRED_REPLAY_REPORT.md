# BÁO CÁO THỰC NGHIỆM ĐÃ HIỆU ĐÍNH: BƯỚC 2 — PAIRED FIELD REPLAY BASELINE VS EKF 4-STATE
## AETRON GPS PIPELINE RESEARCH & SCIENTIFIC EVIDENCE AUDIT

> **Phiên bản:** Bước 2 — Paired Replay Final Evidence Report (Hiệu đính & Kiểm toán Độc lập)  
> **Thời điểm xuất báo cáo:** 01/11/2026  
> **Nhánh kiểm thử:** `fix/gps-step1-raw-signal-gap`  
> **Commit cơ sở (SHA):** `HEAD` (`04c7001`+) trên `origin/fix/gps-step1-raw-signal-gap`  
> **Commit đối chứng cũ (Pre-PR #15 SHA):** `53be32a` (kiểm chứng độc lập tại worktree riêng `/tmp/aetron_pre_pr15`)  
> **Tập dữ liệu kiểm thử thực địa:** `exports/aetron_raw_gps_combined.csv`  
> **SHA-256 Checksum:** `4352aaf43356ab1e7b5e0f4acd3ca8f20259417bde2b3f5bfbabf9c956d2a9c5`  
> **Quy mô dữ liệu:** 10.780 dòng (1 tiêu đề + 10.779 bản ghi GPS thô từ 7 phiên thực tế)  
> **Trạng thái kiểm thử tự động:** `test/gps_paired_field_replay_test.dart` (PASS 100%, độc lập an toàn không phụ thuộc CSV riêng)  
> **Trạng thái phân tích tĩnh:** `flutter analyze` 0 issues found  

---

## 1. MỤC TIÊU & NGUYÊN TẮC ĐỐI CHỨNG KHOA HỌC

Mục tiêu của Bước 2 là đánh giá đối chứng công bằng (Fair Paired Comparison) giữa hai chiến lược làm mượt:
- **Baseline:** Fixed-Alpha ($\alpha \in \{0.34, 0.52, 0.72\}$) kết hợp Turn-Boost.
- **Ứng viên:** EKF 4-State (vector trạng thái $[x, y, v, \theta]^T$, ma trận hiệp phương sai sai số $P$, nhiễu tiến trình $Q$, nhiễu đo $R$).

### 5 Nguyên tắc đối chứng khoa học bất biến:
1. **Chung một nguồn dữ liệu thô (Single Source of Truth):** 10.779 điểm GPS phần cứng nạp tuần tự theo đúng dòng thời gian.
2. **Chung tầng tiền kiểm định (Shared Pre-Validation):** Dùng chung bộ lọc vận tốc ảo (`gpsSpeedHardSpike`), độ chính xác vệ tinh (`accuracy > 35m`) và ngưỡng dịch chuyển tối thiểu (`minSegmentMeters = 1.5m`).
3. **Chung cơ chế nhận diện mất sóng (Shared Gap & Re-Anchor Policy):** Cùng sử dụng `GpsRawSignalContinuity` (ngưỡng $5.0\text{s}$) để tách đoạn tuyến khi mất sóng phần cứng.
4. **Cô lập trạng thái bộ lọc (Zero State Carryover):** Toàn bộ ma trận EKF và điểm neo Fixed-Alpha được `reset()` sạch sẽ giữa các phiên.
5. **Rạch ròi về thước đo (Metric Provenance):** 
   - `saved_distance_km` **không** phản ánh chất lượng smoothing vì được tính toán lại từ raw GPS qua logic lưu trữ.
   - Chiều dài polyline dài hơn **không** đồng nghĩa với độ chính xác vị trí cao hơn.
   - Positional RMSE/P95 chỉ được công nhận khi có Ground Truth tọa độ chuẩn theo thời gian thực.

---

## 2. XÁC MINH NGUỒN DỮ LIỆU & TÍNH TÁI LẬP (REPRODUCIBILITY)

### 2.1. Quản lý dữ liệu riêng tư & Checksum
Tệp `exports/aetron_raw_gps_combined.csv` là dữ liệu GPS thực nghiệm trên đường phố TP.HCM. Để bảo vệ dữ liệu vị trí cá nhân (PII), tệp được đặt trong thư mục `exports/` (nằm trong `.gitignore`). Tính toàn vẹn của tệp được khóa cứng bằng giá trị băm cryptographic:

$$\text{SHA-256} = \mathtt{4352aaf43356ab1e7b5e0f4acd3ca8f20259417bde2b3f5bfbabf9c956d2a9c5}$$

### 2.2. Tính tái lập của bộ kiểm thử (Self-Contained Automated Tests)
Trước đây, bộ kiểm thử replay trực tiếp đọc CSV khiến `flutter test` thất bại nếu clone repo sạch trên CI. Bộ test `test/gps_paired_field_replay_test.dart` đã được tái cấu trúc:
1. **Safe Fixture Test (Chạy luôn luôn):** Chạy trên một kịch bản 15 điểm GPS chuẩn hóa chứa đầy đủ hành vi: di chuyển, đứng yên, mất sóng $7\text{s}$, hồi phục sóng và điểm lùi timestamp. Test này đảm bảo pipeline parity 100% trong mọi môi trường.
2. **Field Dataset Replay Test (Chạy điều kiện):** Tự động phát hiện nếu có tệp CSV local, kiểm tra SHA-256 rồi mới replay. Nếu không có file, test gracefully skip và in thông báo, không làm gãy pipeline CI.

### 2.3. Chi tiết 7 phiên thực địa
| STT | Mã phiên (Workout ID) | Thời gian bắt đầu (UTC) | Thời gian kết thúc (UTC) | Thời lượng | Số raw fixes | Đặc điểm vận động |
|:---:|---|---|---|:---:|:---:|---|
| **1** | `6903b3e0-0fa7-4858-9ff2-77169f3ef2fa` | 2026-10-14 10:40:05 | 10:58:16 | 18.2 phút | 1.186 | Đạp xe đô thị, mật độ cao ốc trung bình |
| **2** | `f808e88a-01df-41c6-9f12-28a48bed8a69` | 2026-10-14 11:06:20 | 11:28:08 | 21.8 phút | 1.173 | Nhiều đoạn che khuất, tán cây |
| **3** | `9b9d3c3f-8a41-42f3-971c-72096a0fe013` | 2026-10-14 11:49:02 | 11:50:47 | 1.8 phút | 101 | Cự ly ngắn kiểm tra khởi động nhanh |
| **4** | `bc34d070-6a7d-4b81-b560-26f0dd4c18bc` | 2026-10-14 11:51:32 | 12:30:30 | 39.0 phút | 2.336 | Hành trình dài liên tục, GPS ổn định |
| **5** | `8fd0afa4-0753-454d-97b2-ce9c0faab6a4` | 2026-10-15 00:25:24 | 00:58:38 | 33.2 phút | 1.957 | Hành trình $11\text{ km}$, ngã tư dừng lâu |
| **6** | `8674084e-a189-42da-b769-4bab1d9aaa45` | 2026-10-15 10:40:08 | 11:09:49 | 29.7 phút | 1.680 | 8 ngã tư dừng chờ, có điểm lùi timestamp |
| **7** | `8a554aec-f0d8-4780-b82f-5cdf34848eaf` | 2026-10-15 11:14:00 | 11:58:24 | 44.4 phút | 2.346 | Phiên dài nhất, hẻm nhỏ và tán cây |
| **TỔNG** | **7 Buổi đạp xe thực tế** | — | — | **188.1 phút** | **10.779** | **Đầy đủ dừng tĩnh, góc cua, ngắt sóng, jitter** |

---

## 3. ĐỐI CHIẾU THỰC CHỨNG GIỮA HAI WORKTREE ĐỘC LẬP: PRE-PR #15 VS POST-PR #15

Để kiểm chứng tác động thực sự của PR #15 mà không dùng cờ giả lập, bài kiểm tra đã được thực thi độc lập trên:
- **Worktree A:** Commit `53be32a` (Code trước PR #15).
- **Worktree B:** Commit `HEAD` trên `fix/gps-step1-raw-signal-gap` (Code sau PR #15).

Cả hai cùng nạp tệp `exports/aetron_raw_gps_combined.csv` ($10.779$ fixes).

### 3.1. Bảng đối chiếu chi tiết theo từng phiên
| Phiên kiểm thử | Raw Fixes | Accepted (Pre / Post) | Soft-Rej (Pre / Post) | Hard-Rej (Pre / Post) | Out-of-Order (Pre / Post) | Route Breaks (Pre `53be32a`) | Route Breaks (Post `HEAD`) | Số vết đứt giả được khử |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `6903b3e0...` | 1.186 | 710 / 710 | 459 / 444 | 17 / 32 | 0 / 0 | **49** | **2** | **-47** |
| `f808e88a...` | 1.173 | 823 / 811 | 338 / 318 | 12 / 31 | 0 / 13 | **67** | **15** | **-52** |
| `9b9d3c3f...` | 101 | 51 / 51 | 50 / 49 | 0 / 1 | 0 / 0 | **8** | **1** | **-7** |
| `bc34d070...` | 2.336 | 1.939 / 1.934 | 380 / 335 | 17 / 61 | 0 / 6 | **55** | **0** | **-55** |
| `8fd0afa4...` | 1.957 | 1.644 / 1.643 | 299 / 281 | 14 / 33 | 0 / 0 | **37** | **1** | **-36** |
| `8674084e...` | 1.680 | 1.200 / 1.195 | 464 / 431 | 16 / 48 | 0 / 6 | **78** | **8** | **-70** |
| `8a554aec...` | 2.346 | 1.770 / 1.753 | 553 / 396 | 23 / 173 | 0 / 24 | **83** | **20** | **-63** |
| **TỔNG CỘNG** | **10.779** | **8.137 / 8.097** | **2.543 / 2.254** | **99 / 379** | **0 / 49** | **377** | **47** | **-330 (-87.5%)** |

---

## 4. KIỂM TOÁN SỐ HỌC (ARITHMETIC RECONCILIATION)

### 4.1. Cân bằng tuyệt đối 10.779 điểm của Pipeline mới (Post-PR #15):
$$\begin{aligned}
\text{Tổng Raw Fixes} &= \text{Accepted} + \text{Soft-Rejected} + \text{Hard-Rejected} + \text{Out-of-Order} \\
10.779 &= 8.097 + 2.254 + 379 + 49 \\
10.779 &= 10.779 \quad (\mathbf{Đúng\ tuyệt\ đối\ 100\%})
\end{aligned}$$

- **Accepted ($8.097$):** Các điểm vị trí đạt chuẩn vận tốc, độ chính xác vệ tinh ($\le 35\text{m}$) và khoảng cách di chuyển ($\ge 1.5\text{m}$).
- **Soft-Rejected ($2.254$):** Các điểm bị lọc do di chuyển dưới ngưỡng ($< 1.5\text{m}$ — hiện tượng đứng yên dừng đèn đỏ) hoặc do tín hiệu suy hao nhẹ nhưng chưa phải bất thường nghiêm trọng.
- **Hard-Rejected ($379$):** Các điểm có độ chính xác vệ tinh kém ($> 35\text{m}$) hoặc đột biến vận tốc tức thời không hợp lý.
- **Out-of-Order ($49$):** Các điểm có timestamp lùi về quá khứ hoặc lặp lại do lỗi hàng đợi bộ đệm phần cứng Android/iOS, được `GpsRawSignalContinuity` nhận diện và gạt bỏ ngay từ cửa ngõ.

### 4.2. Giải trình khoa học: Tại sao có 89 Hardware Raw Gaps nhưng chỉ có 47 Route Breaks?
Trong dữ liệu phần cứng ghi nhận **89 lần khoảng cách thời gian giữa hai bản ghi liên tiếp $> 5.0\text{s}$**, nhưng kết quả tạo polyline chỉ có **47 lần ngắt đoạn tuyến (Route Breaks)**. Nguyên nhân cụ thể:
1. **Gaps xảy ra trước khi bắt đầu tuyến:** Ở đầu phiên, khi chip GPS chưa khóa vệ tinh (chưa gọi `seedRoute`), các khoảng ngắt tín hiệu thô diễn ra trong giai đoạn chờ, không làm đứt đoạn polyline vì polyline chưa khởi tạo.
2. **Gaps xảy ra liên tiếp trong cùng một đợt mất sóng:** Khi vận động viên đi vào đoạn che khuất kéo dài (ví dụ: $30\text{s}$), phần cứng có thể ngắt quãng nhiều nhịp (nhịp $6\text{s}$, nhịp $8\text{s}$...), đồng thời các điểm lẻ loi xuất hiện ở giữa lại bị Hard-Rejected do sai số $> 35\text{m}$. Biến `pendingGapDurationSec` giữ nguyên trạng thái mất sóng cho đến khi bắt được điểm hợp lệ đầu tiên. Do đó, toàn bộ đợt mất sóng dài này chỉ kích hoạt **đúng 1 lần ngắt và tái neo tuyến**.
3. **Gaps ở cuối phiên:** Khi người dùng dừng đạp xe và bấm hoàn thành, khoảng ngắt cuối cùng không nối tiếp vào điểm nào phía sau nên không tạo thêm phân đoạn mới.

### 4.3. Tại sao 330 vết đứt tuyến ở bản Pre-PR #15 chắc chắn là lỗi giả?
- Trong bản cũ `53be32a`, logic kiểm tra khoảng cách thời gian tính bằng:
  $$\Delta t = \text{currentTime} - \text{lastAcceptedPositionTime}$$
- Khi người dùng dừng đèn đỏ $30\text{s}$, GPS phần cứng vẫn gửi tọa độ đều đặn mỗi $1.0\text{s}$ ($\Delta t_{\text{sensor}} = 1.0\text{s}$ — không hề mất sóng). Nhưng vì người dùng đứng yên, các điểm này có $\Delta s < 1.5\text{m}$ nên bị xếp vào `tinySegment` (không cập nhật `lastAcceptedPositionTime`).
- Khi đèn xanh bật và người dùng di chuyển trở lại, $\Delta t$ từ điểm accepted trước đó đã lên tới $31\text{s} > 5.0\text{s}$, khiến hệ thống lầm tưởng là vừa mất sóng và tự ý bẻ gãy tuyến đường!
- Việc PR #15 tách riêng `observe(rawTimestamp)` đã sửa tận gốc sai lầm này, cứu lại **330 lần ngắt tuyến giả**.

---

## 5. KẾT QUẢ ĐỐI SÁNH PAIRED REPLAY: FIXED-ALPHA VS EKF 4-STATE

| Phiên kiểm thử | Quãng đường Live (`live_km`) | Cự ly Polyline Fixed-Alpha (`km`) | Cự ly Polyline EKF 4-State (`km`) | Chênh lệch chiều dài ($\Delta L$) | Quãng đường lưu (`saved_km`) | Parity Gate |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| `6903b3e0...` | 5.157 km | 5.074 km | 5.084 km | **+10.0 m** (+0.20%) | 5.089 km | **100% PASS** |
| `f808e88a...` | 5.757 km | 5.601 km | 5.640 km | **+39.0 m** (+0.70%) | 5.662 km | **100% PASS** |
| `9b9d3c3f...` | 0.251 km | 0.230 km | 0.224 km | **-6.0 m** (-2.61%) | 0.205 km | **100% PASS** |
| `bc34d070...` | 14.937 km | 14.762 km | 14.855 km | **+93.0 m** (+0.63%) | 14.893 km | **100% PASS** |
| `8fd0afa4...` | 11.132 km | 10.918 km | 11.065 km | **+147.0 m** (+1.35%) | 10.921 km | **100% PASS** |
| `8674084e...` | 8.788 km | 8.637 km | 8.632 km | **-5.0 m** (-0.06%) | 8.559 km | **100% PASS** |
| `8a554aec...` | 12.412 km | 12.015 km | 12.065 km | **+50.0 m** (+0.42%) | 12.349 km | **100% PASS** |
| **TỔNG (7 PHIÊN)** | **58.434 km** | **57.237 km** | **57.565 km** | **+328.0 m (+0.57%)** | **57.678 km** | **100% PASS** |

### Bản chất kỹ thuật của chênh lệch $\Delta L = +328.0\text{ m}$ (+0.57%):
- **Hiện tượng Corner Cutting của Fixed-Alpha:** Bộ lọc Fixed-Alpha tính điểm mới bằng cách lấy trung bình có trọng số giữa điểm trước đó và quan trắc GPS:
  $$p_k = (1 - \alpha) p_{k-1} + \alpha z_k$$
  Tại các khúc cua đô thị 90°, phép nội suy tuyến tính này luôn kéo điểm ước lượng về phía bên trong góc cua, làm "vát chéo" cung tròn và làm co ngắn chiều dài hình học của polyline.
- **Hành vi động học của EKF 4-State:** EKF sử dụng mô hình chuyển động phẳng kết hợp vận tốc $v$ và góc hướng $\theta$:
  $$\begin{bmatrix} x_k \\ y_k \end{bmatrix} = \begin{bmatrix} x_{k-1} + v \sin\theta \Delta t \\ y_{k-1} + v \cos\theta \Delta t \end{bmatrix}$$
  Nhờ có đạo hàm hướng và quán tính vận tốc, EKF duy trì bán kính cong tự nhiên của cung đường khi ôm cua. Do đó, cự ly polyline sau lọc của EKF dài hơn $+328\text{ m}$ trên tổng số $57.2\text{ km}$.
- **Cảnh báo khoa học:** Chiều dài polyline dài hơn là **đặc tính hình học của quỹ đạo**, **tuyệt đối không được xem là bằng chứng chứng minh EKF có độ chính xác vị trí cao hơn** khi chưa có thiết bị đo đạc đối chứng mặt đất.

---

## 6. PHÂN LOẠI NGUỒN GROUND TRUTH & TÍNH HỢP LỆ CỦA RMSE/P95

Để đảm bảo tính trung thực khoa học cao nhất theo yêu cầu thẩm định, các nguồn dữ liệu đối soát được phân định rõ ràng như sau:

| Bộ dữ liệu | Loại hình | Bản chất Ground Truth | Thước đo có hiệu lực khoa học | Có được tính Positional RMSE? |
|---|---|---|---|:---:|
| **7 Phiên thực địa (10.779 fixes)** | Đo đạc thực tế trên điện thoại | **KHÔNG CÓ GROUND TRUTH TỌA ĐỘ THEO THỜI GIAN** (Không trang bị trắc địa RTK) | Độ liên tục tuyến, độ ổn định drift dừng, cự ly tích lũy, góc cua | ❌ **KHÔNG** |
| **OpenStreetMap Q1 (1.15 km — 247 fixes)** | **Mô phỏng nhân tạo (Synthetic)** | Tim đường trích xuất từ dữ liệu vector OSM Lê Duẩn | Positional RMSE, P95, Max Error, Stationary Drift, Turn Lag | ✅ **CÓ (Trên môi trường mô phỏng)** |
| **Tuyến ITL Bình Tân $\to$ BTTE (11.110 km — 1.966 fixes)** | **Mô phỏng nhân tạo (Synthetic)** | 417 nodes tim đường Google Maps kết hợp nhiễu hạt `DeterministicRandom(1013)` | Positional RMSE, P95, Max Error, Stationary Drift, Turn Lag | ✅ **CÓ (Trên môi trường mô phỏng)** |

### Kết quả đo lường độ lệch trên môi trường mô phỏng có Ground Truth:
1. **Benchmark OSM Quận 1 (1.15 km):**
   - Fixed-Alpha: $\text{RMSE} = 5.51\text{ m}$, $\text{P95} = 12.00\text{ m}$, Drift dừng $= 53.0\text{ m}$, Apex Lag $= 5.0\text{ m}$.
   - EKF 4-State: $\text{RMSE} = \mathbf{3.59\text{ m}}$ (**-34.8%**), $\text{P95} = \mathbf{7.00\text{ m}}$ (**-41.7%**), Drift dừng $= \mathbf{13.0\text{ m}}$ (**-75.5%**), Apex Lag $= \mathbf{4.0\text{ m}}$.
2. **Benchmark ITL Tuyến dài (11.110 km):**
   - Fixed-Alpha: $\text{RMSE} = 3.66\text{ m}$, $\text{P95} = 7.00\text{ m}$, Drift dừng $= 194.0\text{ m}$, Apex Lag $= 10.0\text{ m}$.
   - EKF 4-State: $\text{RMSE} = \mathbf{2.61\text{ m}}$ (**-28.6%**), $\text{P95} = \mathbf{5.00\text{ m}}$ (**-28.6%**), Drift dừng $= \mathbf{88.0\text{ m}}$ (**-54.6%**), Apex Lag $= \mathbf{7.0\text{ m}}$.

---

## 7. QUY TRÌNH SMOKE TEST AN TOÀN TRÊN THIẾT BỊ THẬT (ĐÓNG BƯỚC 1)

> [!TIP]
> **Quy tắc an toàn tuyệt đối:**  
> Không yêu cầu người dùng đi vào hầm đường bộ, nút giao thông phức tạp hay khu vực mất an toàn để giả lập mất sóng. Toàn bộ bài test được thực hiện trong công viên hoặc sân tập thoáng mát.

### Kịch bản 5 phút kiểm tra nghiệm thu Bước 1:
1. **Khởi động (50m):** Mở app $\to$ Chọn Workout $\to$ Nhấn **Start** $\to$ Đi bộ/đạp xe $50\text{m}$.  
   *Kỳ vọng:* Polyline vẽ mượt mà ngay từ $3\text{–}5\text{m}$ đầu tiên.
2. **Dừng tĩnh an toàn (60s):** Đứng yên hoàn toàn tại chỗ trong đúng $60\text{s}$.  
   *Kỳ vọng:* Quãng đường đứng im, không bị dội số cự ly ảo ($\le 2\text{m}$).
3. **Tiếp tục di chuyển (50m):** Tiếp tục đi bộ/đạp xe thêm $50\text{m}$.  
   *Kỳ vọng:* Tuyến đường nối tiếp liền mạch từ điểm dừng, **không bị gãy tuyến hay tạo khoảng trống giả**.
4. **Giả lập mất sóng bằng phần mềm (15s):** Vuốt cài đặt nhanh điện thoại $\to$ **Tắt Location (hoặc bật Airplane Mode) trong 15s** $\to$ Bật lại Location và di chuyển tiếp $30\text{m}$.  
   *Kỳ vọng:* Hệ thống tách đoạn tuyến an toàn trong 15s mất sóng và tái neo mượt mà khi có sóng lại, không nối chim bay xuyên nhà.
5. **Dừng và Lưu:** Nhấn **Pause** $\to$ **Stop** $\to$ **Hoàn thành**.  
   *Kỳ vọng:* Màn hình lịch sử hiển thị đầy đủ polyline, quãng đường hiển thị và quãng đường lưu trữ trùng khớp.

---

## 8. KẾT LUẬN & TRẢ LỜI 4 CÂU HỎI QUYẾT ĐỊNH

Phù hợp với định hướng rút gọn của đề tài (giữ chắc bằng chứng Phase 0–5 với các quyết định Đạt, HOLD và NO-GO rõ ràng; loại bỏ các phase phức tạp không cần thiết từ Phase 6–12 như DBSCAN, CTRV, Adaptive-Q), kết luận chính thức cho Bước 2 như sau:

### 1. Pipeline PR #15 có cải thiện route continuity theo bằng chứng tái lập được không?
> **CÓ (YES) — XÁC MINH TUYỆT ĐỐI.**  
> Bằng chứng đối chiếu trên hai worktree độc lập với 10.779 fixes thực tế chứng minh số vết đứt gãy tuyến giảm từ **377 xuống đúng 47 lần ngắt thật**. Pipeline mới đã triệt tiêu **330 vết cắt tuyến giả (giảm 87.5%)** do đứng yên dừng đèn đỏ gây ra. Kết quả kiểm thử tự động đạt 100% PASS và có tính tái lập hoàn toàn.

### 2. EKF có chứng minh cải thiện positional accuracy so với Fixed-Alpha trên dữ liệu thực không?
> **CHƯA (NO) — TRUNG THỰC VỀ BẰNG CHỨNG.**  
> Trên 7 phiên dữ liệu thực địa ngoài phố, do không có thiết bị đo đạc trắc địa (RTK-GNSS) đi kèm để lấy tọa độ mặt đất chuẩn theo thời gian, **chưa đủ điều kiện khoa học để khẳng định EKF cải thiện độ chính xác vị trí tuyệt đối trên dữ liệu thực**. Cải thiện RMSE/P95 (từ 28.6% đến 34.8%) chỉ mới được chứng minh trên 2 tập benchmark mô phỏng nhân tạo (Synthetic OSM Q1 và ITL Route). Cự ly polyline dài hơn $+0.57\%$ chỉ phản ánh đặc tính giữ bán kính góc cua động học, không phải thước đo độ chính xác vị trí.

### 3. Bước 2 đã hoàn thành ở mức nào?
> **HOÀN THÀNH PHẦN PAIRED PIPELINE REPLAY & KIỂM TOÁN SỐ HỌC (PARTIAL COMPLETE / BENCHMARK READY).**  
> - Đã hoàn thành 100% việc chạy đối chứng paired replay giữa hai bộ lọc trên cùng một pipeline chuẩn hóa.  
> - Đã hoàn thành 100% kiểm toán số học toàn vẹn ($8.097 + 2.254 + 379 + 49 = 10.779$).  
> - Đã hoàn thành phân định ranh giới giữa ngắt sóng phần cứng và ngắt đoạn tuyến polyline.  
> - Phần tính toán sai số vị trí thực địa (Field Positional RMSE/P95) được **HOLD/DỪNG LẠI** theo đúng nguyên tắc khoa học do thiếu Ground Truth RTK.

### 4. Có đủ điều kiện chuyển sang benchmark final hay chưa?
> **ĐỦ ĐIỀU KIỆN (YES) — VỚI PHẠM VI KHÓA CHẶT.**  
> Đã đủ điều kiện để tiến hành nghiệm thu đóng Bước 1 (qua bài Smoke test thực tế 5 phút) và tiến hành Final Benchmark so sánh EKF 4-State với Baseline trên các bộ dữ liệu chuẩn hóa đã khóa quy chế. Giữ vững phạm vi cốt lõi Phase 0–5, không bổ sung thêm DBSCAN, CTRV hay Adaptive-Q.

---
*Báo cáo được phê duyệt và hoàn tất bởi: Senior Flutter Engineer & GPS QA Engineer — Dự án Aetron.*
