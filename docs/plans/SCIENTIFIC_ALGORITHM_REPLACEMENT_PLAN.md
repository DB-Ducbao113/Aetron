# Aetron — Kế hoạch Chuẩn hoá Thuật toán Theo Hướng Khoa học (Minimal-Change Thesis Plan)

Ngày cập nhật: 2026-11-27 · Mục tiêu: **Sửa code ít nhất có thể, giữ nguyên tiêu đề thesis (*"A Mobile Fitness Tracking Application for Indoor and Outdoor Activities"*), nâng benchmark IOD lên tốt nhất bằng bài báo chuẩn quốc tế, và khai báo trung thực 100% nguồn gốc thuật toán.**

## 1. Hướng nghiên cứu thống nhất (Tên dùng cho Thesis)
- **Tên tiếng Anh:** *Context-Aware Hybrid Time-Series & Recursive Bayesian State Estimation for Indoor and Outdoor Smartphone Tracking*
- **Giải thích trung thực:** Aetron dùng mô hình phân lớp ngữ cảnh Indoor/Outdoor dựa trên chuỗi thời gian đa biến (**CAP-ALSTM** + **SHAP** — Bakirtzis 2022) kết hợp lọc thời gian Bayes (**Causal HMM** — Zhu 2019), đi cùng bộ ước lượng trạng thái quỹ đạo đệ quy (**4-state AEKF** — Kalman/NIS), phát hiện dừng (**T-DBSCAN**), và đếm bước/độ dài bước có căn cứ sinh cơ học (**Oxford WPD**, **Xu 2022**, **MV-GLRT**, **Renaudin**).

## 2. Những gì GIỮ NGUYÊN (Đã có bài báo & benchmark tốt)
Xem chi tiết từng dòng trong **[ALGORITHM_PROVENANCE_TABLE.md](ALGORITHM_PROVENANCE_TABLE.md)**:
- GNSS P01 + P02 AEKF + P03 PCHIP (TU Wien `3.432 m` RMSE, `1.34%` dist err; SnapperGPS negative result).
- Auto-Pause T-DBSCAN (STAGA `98.97%` precision).
- Oxford WPD (`93.16%`), Xu 2022 (`98.69%`), Renaudin Eq.8, 2024 Compendium.
- Route Correction Worker (honest fallback `filtered`, không bịa kết quả).

## 3. Kế hoạch hành động cụ thể (3 đầu việc chính)

| Thứ tự | Hạng mục | SDD / Tài liệu | Mức độ ưu tiên |
|---|---|---|---|
| **1** | **Kiểm toán Provenance & Sửa văn bản Thesis** — đưa bảng phân loại trung thực vào Chương 3, sửa cách gọi tên phần Engineering Design | [ALGORITHM_PROVENANCE_TABLE.md](ALGORITHM_PROVENANCE_TABLE.md) | **ĐÃ HOÀN TẤT (Bảng sẵn sàng)** |
| **2** | **Nâng cấp Indoor/Outdoor Detection (Trọng tâm tiêu đề)** — tái hiện **CAP-ALSTM + Kernel SHAP** ([Bk22], PDF đã tải) trên **CIOD** (`201,731` held-out) và kiểm chứng **HAR-PMD** (`12` đối tượng đa thiết bị), đối sánh với DeepIOD / MagIO + Causal HMM | [SDD-06](sdd/SDD-06-indoor-outdoor.md), [Báo cáo SDD-06](../research/CAP_ALSTM_IOD_BENCHMARK_REPORT.md) | **ĐÃ HOÀN TẤT** |
| **3** | **A/B Ablation Step Gate & Cadence** — đối chiếu PDF [S18] đã tải, chạy A/B bật/tắt Bout Gate & 6s Cadence vs Step-Interval Median để lấy bảng số liệu ablation | [SDD-04](sdd/SDD-04-step-gate-removal.md), [SDD-05](sdd/SDD-05-cadence.md), [Báo cáo SDD-04/05](../research/STEP_GATE_AND_CADENCE_AB_REPORT.md) | **ĐÃ HOÀN TẤT** |
| **4** | **Mở rộng & So sánh Khoa học (SDD-01, 02, 03, 07, 08)** — IMM + Causal Zheng Auto-Pause, IGG-III, IAE Mohamed–Schwarz, Newson–Krumm HMM (Deno), Unified `StateEstimator` + PDR gap ablation | [SDD-01](sdd/SDD-01-auto-pause-stay-point.md), [02](sdd/SDD-02-gnss-robust-gate.md), [03](sdd/SDD-03-gnss-adaptive-kalman.md), [07](sdd/SDD-07-map-matching.md), [08](sdd/SDD-08-unified-state-estimator.md), [Closure 2026-11-27](../research/FULL_PLAN_EXECUTION_CLOSURE_20261127.md) | **ĐÃ HOÀN TẤT (Tích hợp vào Thesis Overleaf)** |

## 4. Tài liệu tham chiếu & PDF
- Danh mục đầy đủ kèm DOI và PDF cục bộ: **[PAPERS.md](PAPERS.md)**
- Thư mục PDF đã tải: `docs/plans/papers/` (`Bakirtzis2022_IOD_JIoT.pdf`, `Bai2022_HybridIOD.pdf`, `10_1109_EMBC_2018_8513319.pdf`).
