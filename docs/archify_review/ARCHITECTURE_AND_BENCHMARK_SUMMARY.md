# Aetron — Architecture (Archify & Floorplan) + Literature Review & Benchmark Suite

> Thư mục này (`docs/archify_review/`) đã được thêm vào `.gitignore` theo yêu cầu để bạn thoải mái mở đọc trên trình duyệt hoặc đưa sang Overleaf mà không làm bẩn lịch sử commit của dự án.

---

## 1. Bộ Trình duyệt Tương tác HTML (Mở trực tiếp trên Safari / Chrome / Edge)

1. **[index.html](./index.html)** — **Cổng Trung tâm (Interactive Portal)**: Hiệu ứng hạt chuyển động, bảng chỉ số KPI thực nghiệm và điều hướng nhanh sang 3 trình xem chuyên sâu.
2. **[aetron_floorplan.html](./aetron_floorplan.html)** — **Bản vẽ Mặt bằng Codebase (`Floorplan`)**:
   - Chia toàn bộ repo thành **6 Phân khu (Wings)** và **22 Phòng chức năng (Rooms)**: Mobile UI & Shell, GNSS & IMU Lab, DeepIOD & AI Lab, Dual Local Vault (Isar + SQLite), Supabase Deno Cloud & PostGIS, và Benchmark Proving Ground.
   - Hỗ trợ kéo thả (Pan), phóng to/thu nhỏ (Zoom), tìm kiếm tức thì, bật/tắt đường dây kết nối dữ liệu và bảng kiểm toán sức khỏe/bảo mật.
3. **[aetron_archify.html](./aetron_archify.html)** — **Sơ đồ Luồng Thực thi & Biên dịch Kiến trúc (`Archify`)**:
   - Dựa trên **Typed JSON IR** gắn nhãn bằng chứng mã nguồn (`SRC` file & dòng lệnh thực tế, 0 thành phần hư cấu).
   - **4 Chế độ Sơ đồ**: (1) Runtime Architecture, (2) GNSS P01→P02→P03 & IMU Pipeline, (3) Offline-First Isar ↔ Server Authority Reconciliation, (4) DeepIOD & Yoo Transition Data-Flow.
   - Hiệu ứng hạt dữ liệu chạy trực tiếp (**Trace Motion**) và nút xuất file ảnh vector **SVG**.
4. **[aetron_literature_benchmark.html](./aetron_literature_benchmark.html)** — **Trình đọc Học thuật & Khám phá Benchmark Tương tác**:
   - Hiển thị công thức Toán học (KaTeX), thanh tiến độ đọc, mục lục tự động bám vị trí cuộn (Scroll-Spy TOC), hiệu ứng xuất hiện mượt và biểu đồ thanh động đối sánh từng tập dữ liệu.
5. **[aetron_benchmark_playbook.html](./aetron_benchmark_playbook.html)** — **Cẩm nang Đo lường & Áp dụng Benchmark Thực chiến (Playbook + Live Calculators)**:
   - Giải thích chi tiết theo cấu trúc 3 cột cho từng nhóm thuật toán: **① Bài báo gốc thiết lập thiết bị chuẩn & chia tập dữ liệu ra sao → ② Công thức từng bước để ra con số trong bảng → ③ Cách bạn tự đo ngoài thực địa & chạy code trên Aetron để lấy đúng con số đó**.
   - Tích hợp **3 máy tính tương tác trực tiếp trên trình duyệt** (400m Track GPS Scott/Bland-Altman, 100m Gait Step/Stride Renaudin, và Confusion-Matrix Macro-F1) tự động sinh dòng bảng LaTeX `booktabs` để dán thẳng vào bài báo.

---

## 2. Bài báo Khoa học LaTeX Chuẩn Quốc tế (`IEEEtran`)

- **File chính:** [latex/aetron_literature_review_benchmark.tex](./latex/aetron_literature_review_benchmark.tex)
- **Cơ sở dữ liệu trích dẫn:** [latex/references.bib](./latex/references.bib) (đầy đủ 25 công trình và bộ dữ liệu công khai kèm DOI xác thực)

### Hướng dẫn biên dịch sang PDF
- **Trên Overleaf:** Tạo project trống → Upload 2 file `aetron_literature_review_benchmark.tex` và `references.bib` → Chọn trình biên dịch `pdfLaTeX` → Nhấn **Recompile**.
- **Trên máy cục bộ (khi cài MacTeX / BasicTeX):**
  ```bash
  cd docs/archify_review/latex
  pdflatex aetron_literature_review_benchmark.tex
  bibtex aetron_literature_review_benchmark
  pdflatex aetron_literature_review_benchmark.tex
  pdflatex aetron_literature_review_benchmark.tex
  ```

---

## 3. Tóm tắt Đối sánh Benchmark Cốt lõi (Bài báo Gốc vs. Aetron)

| Trụ cột Thuật toán | Bộ dữ liệu & Cách Bài báo Gốc Đo Chuẩn | Số liệu Tham chiếu / Baseline | Số liệu Thực nghiệm Aetron |
| :--- | :--- | :--- | :--- |
| **GNSS P01 + P02 (4-State AEKF)** | **TU Wien Smartphone Phase-RTK** (`10.48436/y6gxm-6mg51`, $N=2{,}694$ mốc giây khớp trạm Leica RTK) | Raw GNSS: RMSE `2.11 m`, Dist Err `4.15%`<br/>Fixed Alpha: RMSE `8.75 m`, Dist Err `9.77%`<br/>Legacy EKF: RMSE `10.18 m`, Dist Err `11.55%` | **P01 + P02 (AEKF):** RMSE **`3.43 m`**, Sai số quãng đường **`1.34%`** (Đạt chuẩn `GOOD < 5%` của Scott et al., 2016) |
| **GNSS Cycling Stress Test** | **Oxford SnapperGPS 2** (`10.5287/ora-xq5b8xva7`, $N=20{,}770$ mốc giây khớp u-blox ZED-F9P RTK, thiếu vận tốc Doppler) | Tác giả báo cáo Raw Median: `14.5 m`<br/>Raw Dist Err: `360.34%` | Aetron Raw Matched Median: **`14.455 m`**<br/>`P01+EKF` Dist Err: **`13.41%`**; `P01+AEKF`: RMSE `138.23 m`, Dist Err `15.18%` *(Ghi nhận trung thực kết quả âm tính)* |
| **GNSS P03 (Monotone PCHIP)** | Che các điểm ở giữa mỗi chu kỳ 5 giây, đo RMSE tái tạo so với RTK (`10.3390/app16188972`) | Linear Chord: `2.108 m` (TU Wien) / `14.114 m` (Cycling) | Monotone PCHIP: **`2.125 m`** (TU Wien) / **`15.486 m`** (Cycling) — Chỉ dùng vẽ đường hiển thị mượt |
| **Điểm dừng T-DBSCAN & Auto-Pause** | **STAGA Stop/Trip** ($122{,}808$ mẫu GPS, $\Delta t_{\text{med}}=10\text{ s}$, nhật ký hành trình) | Causal 3s Speed Gate ($v \le 0.8\text{ m/s}$): Precision `96.44%`, `1,117` cụm dừng giả | **T-DBSCAN ($\varepsilon=6.5\text{ m}$):** Precision **`98.97%`**, chỉ **`122`** cụm dừng giả; **Zheng Stay-Point:** F1 **`82.10%`** |
| **Đếm bước Đi bộ (Oxford WPD)** | **Salvi et al. 2018** (12 phiên, 4,107 bước) + **OxWalk** (39h) + **PedEval** (90 phiên, 56,668 bước) | Bản Java tác giả: Accuracy **`93.36%`** (WAPE `6.65%`) | `OxfordStepDetector` nhân quả: **`93.16%`** (`97.69%` trên tập phần cứng); PedEval Regular 6s MAE **`8.41 spm`**, `0` lệch tổng bước |
| **Đếm bước Chạy bộ (Xu 2022)** | **Xu Group 3** (`10.3390/rs14122926`, 5 phiên chạy, 1,280 bước chuẩn) | StepCount cũ: `89.92%`<br/>Xu công bố: **`98.94%`** | `XuRunningStepDetector` nhân quả: **`98.69% ± 1.28%`** (1,279/1,280 bước, WAPE **`1.17%`**, MAE **`2.02 spm`**) |
| **Chiều dài Bước (Renaudin LOSO)** | **SLEDataset2** (114 phiên đi bộ) & **Fukuchi RBDS** (`10.7717/peerj.3298`, 84 phiên chạy trên thảm đo lực) | Hằng số tĩnh cũ: Walk MAPE `12.99%`; Run MAPE `17.30%` (`20.21%` ở 4.5 m/s) | **Renaudin Eq. 8 LOSO:** Walk MAE **`8.61 cm`** (MAPE **`12.01%`**, đi nhanh **`9.97%`**); Run MAE **`17.80 cm`** (MAPE **`15.29%`**, chạy nhanh **`14.59%`**) |
| **Nhận diện Trong nhà / Ngoài trời** | **Cambridge CIOD** (`10.17863/CAM.82668`, Held-Out Sessions 72..84 = $201{,}731$ mẫu không rò rỉ phiên) | Always-Indoor: Acc `58.97%`, Macro-F1 `37.10%`<br/>DeepIOD in-domain 8-ch: `>95%`<br/>MagIO GNB+HMM (`10.3390/mi9100534`): Acc `73.38%`, Macro-F1 `70.67%` | **8-Ch Model C (Research):** Acc **`90.59%`**, Macro-F1 **`90.17%`**<br/>**Android 4-Ch C-Mobile (`Light+Mag+Acc+Day`):** Acc **`73.64%`** (`0%` trên iOS do thiếu Light)<br/>**iOS Light-Free `[MagIO+Acc+Daytime]` MLP+HMM:** Acc **`77.07%`** (Macro-F1 **`74.97%`**, HMM **`75.65%` / `74.77%`**), hoạt động 100% trên iPhone + kết hợp `CMAltimeter` & `CoreLocation` |
| **Nén Đường chạy & Năng lượng** | **Google Encoded Polyline** (30,381 điểm thực) & **2024 Adult Compendium** (`10.1016/j.jshs.2023.10.010`) | Raw JSON: `1,418,305 bytes` | **Precision 5:** **`82,523 bytes`** (**tiết kiệm `94.18%` / `17.19×`**, RMSE `0.375 m`); MET khớp 100% Client–Server |

---

## 4. Quy trình Tự Đo & Chạy Ra Con số Benchmark Thực tế trên App Aetron

Ngoài việc phát lại các bộ dữ liệu chuẩn quốc tế, bạn có thể áp dụng đúng quy trình của các bài báo gốc ngay trên điện thoại chạy Aetron (không cần máy trạm RTK đắt tiền) bằng bộ công cụ đánh giá tự động `tooling/benchmark/aetron_field_and_paper_evaluator_test.dart`:

### Bước 1: Xuất dữ liệu buổi tập thực tế từ Aetron
Sau khi cầm điện thoại chạy/đi bộ (ví dụ $N$ vòng sân điền kinh chuẩn $400\text{ m}$ làn 1 $\Rightarrow D_{\text{ref}} = 0.400 \times N\text{ km}$, có bấm giờ các khoảng dừng đèn đỏ nếu muốn đo Auto-Pause/T-DBSCAN):
```bash
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... dart run tool/export_workout.dart <workout-id>
# Xuất ra: exports/<workout-id>/raw_gps_points.csv
```

### Bước 2: Chạy bộ chấm điểm chuẩn bài báo (Xuất bảng số liệu & dòng LaTeX)
```bash
# 1) Chạy Demo tổng hợp (kiểm tra nhanh toàn bộ công thức GNSS + Gait + IOD):
~/development/flutter/bin/flutter test --no-pub tooling/benchmark/aetron_field_and_paper_evaluator_test.dart --reporter expanded

# 2) Chấm điểm buổi chạy thực tế (Raw vs Fixed Alpha vs Legacy EKF vs P01+P02 AEKF + P03 Masked 5s + Polyline + Stop F1):
AETRON_BENCH_MODE=field-gps \
AETRON_CSV=exports/<workout-id>/raw_gps_points.csv \
AETRON_REF_KM=2.000 \
AETRON_ACTIVITY=running \
AETRON_STOP_WIN="120-150,270-300" \
~/development/flutter/bin/flutter test --no-pub tooling/benchmark/aetron_field_and_paper_evaluator_test.dart --reporter expanded

# 3) Chấm điểm nhiều buổi chạy sân vận động theo chuẩn Scott et al. (2016) & Bland-Altman 95% LoA (cặp ref_km:app_km):
AETRON_BENCH_MODE=track-suite \
AETRON_TRIALS="2.0:2.024,2.0:1.982,2.0:2.015,4.0:3.968,4.0:4.031" \
~/development/flutter/bin/flutter test --no-pub tooling/benchmark/aetron_field_and_paper_evaluator_test.dart --reporter expanded

# 4) Chấm điểm Đếm bước & Chiều dài bước đoạn thẳng 100m (Static 0.415H/0.65H vs Renaudin Eq. 8):
AETRON_BENCH_MODE=field-gait \
AETRON_ACTIVITY=running AETRON_DIST_M=100 AETRON_TRUE_STEPS=84 AETRON_APP_STEPS=83 AETRON_DUR_SEC=28.5 AETRON_HEIGHT_CM=172 \
~/development/flutter/bin/flutter test --no-pub tooling/benchmark/aetron_field_and_paper_evaluator_test.dart --reporter expanded

# 5) Chấm điểm Indoor/Outdoor từ file log IodExperimentStorage (Macro-F1 & độ trễ chuyển cửa):
AETRON_BENCH_MODE=field-iod \
AETRON_IOD_JSONL=path/to/session_123.jsonl \
AETRON_IOD_GT=path/to/ground_truth_123.jsonl \
~/development/flutter/bin/flutter test --no-pub tooling/benchmark/aetron_field_and_paper_evaluator_test.dart --reporter expanded
```
