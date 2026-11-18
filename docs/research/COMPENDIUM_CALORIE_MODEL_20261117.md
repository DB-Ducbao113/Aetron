# Aetron calorie estimation — 2024 Adult Compendium (17/11/2026)

## Nguồn gốc và phạm vi

- Nguồn bảng mã **chính thức**: [2024 Adult Compendium](https://pacompendium.com/adult-compendium/), [PDF 27 trang](https://pacompendium.com/wp-content/uploads/2024/01/2024-adult-compendium_1_2024.pdf), các nhóm **Bicycling (01), Running (12), Walking (17)**.
- Nguồn học thuật: **Herrmann SD, Willis EA, Ainsworth BE, et al.** (2024), *2024 Adult Compendium of Physical Activities: A third update of the energy costs of human activities*, *Journal of Sport and Health Science* 13(1):6–12, DOI [10.1016/j.jshs.2023.10.010](https://doi.org/10.1016/j.jshs.2023.10.010).
- Theo [định nghĩa](https://pacompendium.com/) và [bảng đổi đơn vị](https://pacompendium.com/unite-conversions/) của Compendium: **1 MET quy ước = 1 kcal/kg/giờ**. Bảng 2024 nhắm tới người lớn **19–59 tuổi**. Đây là MET chuẩn của nhóm hoạt động, **không phải phép đo tiêu hao năng lượng của người dùng cụ thể**; một số MET từ nghiên cứu calorimetry, một số là giá trị ước tính.

## Công thức production

```text
gross_workout_kcal_estimate = published_standard_MET × weight_kg × active_seconds / 3600
active_seconds = movingDurationSec (>0) nếu có, nếu không dùng durationSec
speed_mph = speed_km_per_hour / 1.609344
```

- Không dùng `weight × distance × k`, hệ số giới tính `female=0.95`, hoặc các bonus `+0.05` tại tốc độ 10/15 km/h. Giới tính không tự động điều chỉnh standard MET.
- Để giữ **quy tắc không ghi calorie khi đứng yên** hiện hữu, hoạt động Running/Walking/Cycling có `distanceKm<=0` hoặc không có thời gian hợp lệ trả về **0**, kể cả khi đồng hồ elapsed đang chạy. Quy tắc này là **app policy**, không phải kết luận rằng cơ thể không tiêu hao năng lượng khi đứng yên.
- Phương pháp lấy mã dựa trên **tốc độ trung bình đang di chuyển** do caller cung cấp. Nếu tốc độ bằng 0/không xác định, hoặc nằm giữa các khoảng bảng không chỉ rõ, trả về đúng mã **self-selected/general** của bảng gốc, **không nội suy MET, không tự tạo band**. Một số mục ghi đúng **một vận tốc duy nhất** (ví dụ chạy 7 mph); chỉ áp dụng khi tốc độ bằng vận tốc đó, không tự nới khoảng. Không suy tốc độ từ khoảng cách nếu caller không cung cấp.
- Giá trị MET và thời gian từ đầu phiên được nhân để tính **gross exercise energy**, không trừ phần resting (không phải *net active calories* theo định nghĩa physiological). Bộ đếm kcal hiển thị là ước lượng; không chứng minh sai số so với calorimetry.

## Bảng ánh xạ mã PACOMPENDIUM chính thức

Mọi khoảng bên dưới dùng **mph**, tham số API nhận **km/h**. Các điều kiện vận động/địa hình trong mô tả bản gốc chỉ là giả định vì Aetron hiện không có thông tin về dốc, gió, drafting, công suất hoặc phong cách tập luyện.

| Hoạt động | Tốc độ mph (đúng mô tả nguồn) | Code 2024 | MET | Ghi chú |
| --- | --- | --- | ---: | --- |
| Walking | `0 < v < 2.0` | `17151` | 2.3 | Level, strolling, very slow |
| Walking | 2.0–2.4 | `17152` | 2.8 | Level, firm |
| Walking | 2.5 (đúng mốc) | `17170` | 3.0 | Level, firm |
| Walking | 2.8–3.4 | `17190` | 3.8 | Level, firm |
| Walking | 3.5–3.9 | `17200` | 4.8 | Brisk, exercise, level |
| Walking | 4.0–4.4 | `17220` | 5.5 | Very brisk, level |
| Walking | 4.5–4.9 | `17230` | 7.0 | Very brisk, level |
| Walking | 5.0–5.5 | `17231` | 8.5 | Level, firm |
| Walking | Unknown hoặc ngoài các band | `17255` | 4.0 | Self-selected walking, firm |
| Running | 4.0–4.2 | `12028` | 6.5 | Level running |
| Running | 4.3–4.8 | `12029` | 7.8 | Level running |
| Running | 5.0–5.2 | `12030` | 8.5 | Level running |
| Running | 5.5–5.8 | `12045` | 9.0 | Level running |
| Running | 6.0–6.3 | `12050` | 9.3 | Level running |
| Running | 6.7; 7.0; 7.5; 8.0 | `12060`; `12070`; `12080`; `12090` | 10.5; 11.0; 11.8; 12.0 | Các mốc đơn lẻ |
| Running | 8.6; 9.0 | `12100`; `12110` | 12.5; 13.0 | Các mốc đơn lẻ |
| Running | 9.3–9.6 | `12115` | 14.8 | Level running |
| Running | 10; 11; 12; 13; 14 (đúng mốc) | `12120`; `12130`; `12132`; `12134`; `12135` | 14.8; 16.8; 18.5; 19.8; 23.0 | Các mốc đơn lẻ |
| Running | Unknown hoặc ngoài các band | `12145` | 10.5 | Running, self-selected pace |
| Cycling | `0 < v < 10` | `01010` | 4.0 | Leisure, áp dụng giả định leisure |
| Cycling | 10–11.9 | `01020` | 6.8 | Leisure, slow |
| Cycling | 12–13.9 | `01030` | 8.0 | Moderate |
| Cycling | 14–15.9 | `01040` | 10.0 | Fast / vigorous |
| Cycling | 16–19 | `01050` | 12.0 | Very fast / racing, not drafting |
| Cycling | `v > 20` | `01060` | 16.8 | Racing, not drafting (chưa xác minh drafting) |
| Cycling | Unknown, `19 < v <= 20`, hoặc ngoài các band | `01014` | 7.0 | Bicycling, general |

**Không suy diễn:** ví dụ Running 7,46 mph không có band bao trùm, nên chọn `12145=10.5 MET` thay vì nội suy giữa `12070` và `12080`. Cycling `v>20` dùng đúng mã `01060`, nhưng không có cảm biến phân biệt drafting/racing; việc gán mã theo speed vẫn là **mapping application**, không phải reproduction khoa học của một phép đo cá nhân. Walking `v<2 mph` chỉ dùng khi tốc độ thật sự dương.

## Đối chiếu phần còn thiếu

1. **Chất lượng tốc độ và thời gian.** Caller `WorkoutMetricsCalculator` dùng `distance / movingTime` nếu moving time >0, hoặc `distance / elapsed` khi missing/zero. Do đó nếu moving time chưa cập nhật, tốc độ có thể bị thấp và thời gian tạm dừng bị tính vào kcal. `UserProfile.calculateCalories` chưa phân biệt được “không truyền moving time” với “truyền 0” vì mặc định public API bằng 0; **không tự tuyên bố paused-energy chính xác**.
2. **Downstream ceiling policy.** Live controller và finalizer hiện có `max(previousCalories, newEstimate)`; nếu một giá trị cũ cao hơn, việc chuyển công thức có thể không hạ ngay giá trị trên phiên đang chạy. Không chỉnh các file này theo scope được giao.
3. **Khác nhóm vận động.** Yoga, strength, swimming và fallback hoạt động khác giữ mapping MET legacy để tránh thay đổi hành vi ngoài phạm vi. Những số này **chưa được kiểm định truy xuất theo từng mã Compendium 2024** và không được quảng bá là đã làm mới.
4. **Giới hạn khoa học.** Compendium 2024 áp dụng 19–59; chưa cá nhân hóa theo tuổi, giới, VO2, cân nặng thành phần cơ thể, địa hình, stride, sức cản gió, thời gian tại mỗi tốc độ, hoặc calorimetry; **cần thử nghiệm đo thực địa** trước khi tuyên bố chính xác. Speed bands chọn theo tốc độ trung bình toàn phiên chứ không cộng tích phân MET theo từng đoạn.

## Verification

- Unit tests `test/workout_data_consistency_test.dart`: mã + MET chính xác, band, vùng không được mô tả, unknown speed, kcal/giờ, moving/elapsed, không có multiplier giới tính, stationary zero, persisted/display.
- Regression `test/stationary_calories_and_gps_gaps_regression_test.dart`: stationary và red-light moving time, cùng GPS gap tests nguyên trạng.
- Chạy analyzer và các test này; ghi rõ kết quả trong handoff.
