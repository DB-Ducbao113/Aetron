# SDD-07 Route matching = HMM map matching (Newson & Krumm 2009)

> **[OPTIONAL / FUTURE WORK]** Route correction worker hiện đã khóa an toàn (stub fallback filtered) — giữ nguyên cho Thesis; Newson & Krumm HMM là OPTIONAL / FUTURE WORK.

> **Vai trò trong hướng thống nhất:** hậu xử lý Bayes (HMM) trên quỹ đạo đã lọc của SDD-08. Xem [UNIFIED_RESEARCH_DIRECTION.md](../UNIFIED_RESEARCH_DIRECTION.md).

> ## HƯỚNG NGHIÊN CỨU (khai báo rõ)
> - **Hướng:** Hidden Markov Model map matching
> - **Bài báo nền:** [NK09] Newson & Krumm, SIGSPATIAL 2009, 10.1145/1653771.1653818
> - **Loại:** FAITHFUL (Viterbi, emission Gauss, transition mũ, σ_z/β theo median); phụ thuộc OSM extract & dataset Seattle
> - **Lấy từ bài:** Phương trình emission/transition, ước lượng σ_z, β
> - **KHÔNG lấy từ bài (phải khai báo trong báo cáo):** Bán kính ứng viên nếu bài không cố định; graph OSM
> - **Loại bỏ/không dùng:** Bỏ nhãn confidence tự đặt 'high_confidence'
**Mục tiêu:** thay trạng thái/confidence tự đặt trong `route_match_quality_service.dart` + route-correction-worker bằng thuật toán công bố.
**Paper:** Newson P., Krumm J., "Hidden Markov Map Matching Through Noise and Sparseness", ACM SIGSPATIAL GIS 2009, 10.1145/1653771.1653818 (verify). Emission: Gaussian theo khoảng cách tới đoạn đường (σ_z); transition: mũ theo |d_great_circle − d_route| (β); Viterbi.
**Phạm vi:** `backend/supabase/functions/route-correction-worker`, `route_match_quality_service.dart`; module Deno `hmm_map_matcher.ts`. Ghi chú: cần OSM extract cố định + routing graph.
## Yêu cầu
- FR1: σ_z, β ước lượng theo công thức bài (median absolute deviation) trên **validation**, không đặt tay.
- FR2: confidence = đại lượng xác suất Viterbi (nếu bài không định nghĩa, không phát "high confidence"; chỉ trả matched/unmatched).
- FR3: khoảng cách chỉ lấy từ matched khi matcher thành công; còn lại giữ filtered (hành vi hiện tại, bảo toàn).
- FR4: gap > ngưỡng → tách segment; không nối.
## Đánh giá
Dataset Seattle công bố cùng bài (ground-truth route) hoặc dataset thay thế đã xác minh: route mismatch fraction, distance error. So: matcher hiện tại, HMM bản paper. Nếu dataset không truy cập được → NOT REPRODUCED, giữ hiện tại.
## Test
`deno test` với fixture đường nhỏ; Viterbi đúng trên ví dụ tay; test regression `scientific_result_integration_test`. Không deploy Supabase từ máy này (CLI không có).

## Bài báo & phương trình (S0: đối chiếu PDF)
**[NK09]** https://doi.org/10.1145/1653771.1653818
- Emission: `p(z_t | r_i) = (1/(√(2π) σ_z)) · exp(−0.5 · (‖z_t − x_{t,i}‖_great-circle / σ_z)²)`.
- Transition: `p(d_t) = (1/β) · exp(−d_t / β)`, `d_t = | ‖z_t − z_{t+1}‖_gc − ‖x_{t,i*} − x_{t+1,j*}‖_route |`.
- Ước lượng tham số: `σ_z = 1.4826 · median_t(‖z_t − x_{t,i*}‖)`; `β = (1/ln 2) · median_t(d_t)`.
- Giải bằng Viterbi trên các ứng viên đường trong bán kính tìm kiếm.
S0: đối chiếu từng công thức, hằng 1.4826, và quy trình lấy mẫu thưa trong bài.
## Giao diện & file
`backend/supabase/functions/route-correction-worker/hmm_map_matcher.ts` + `hmm_map_matcher_test.ts` (fixture lưới đường nhỏ + ví dụ Viterbi tính tay). Dart: `route_match_quality_service.dart` chỉ chuẩn hoá output (matched / unmatched / fallback_filtered), bỏ nhãn "high_confidence" nếu không có định nghĩa xác suất trong bài.
## Constant provenance
σ_z, β: công thức bài trên validation; bán kính ứng viên: tham số bài hoặc ghi "tự đặt". Dataset: Seattle sample công bố kèm bài (S0 xác nhận truy cập; không có → NOT REPRODUCED).
