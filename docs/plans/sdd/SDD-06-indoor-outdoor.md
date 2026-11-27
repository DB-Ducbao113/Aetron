# SDD-06 Indoor/Outdoor Detection (IOD) = CAP-ALSTM + SHAP Feature Ablation (Bakirtzis et al., IEEE IoT J 2022)

> ## HƯỚNG NGHIÊN CỨU & VAI TRÒ TRONG THESIS
> - **Hướng nghiên cứu:** Context-Aware Hybrid Time-Series & Recursive Bayesian State Estimation for Indoor/Outdoor Smartphone Tracking (xem [UNIFIED_RESEARCH_DIRECTION.md](../UNIFIED_RESEARCH_DIRECTION.md))
> - **Vị trí trong Thesis:** **Trọng tâm số 1** — phục vụ trực tiếp chữ *"Indoor and Outdoor Activities"* trong tiêu đề thesis với mức sửa đổi code ít nhất nhưng nâng chất lượng benchmark lên mức công bố quốc tế.
> - **Bài báo chính:** **[Bk22]** Bakirtzis, Qiu, Wassell, Fiore, Zhang — *"Deep Learning-based Multivariate Time Series Classification for Indoor/Outdoor Detection"*, IEEE Internet of Things Journal (2022), DOI: `10.1109/JIOT.2022.3190555` ([PDF cục bộ](../papers/Bakirtzis2022_IOD_JIoT.pdf))
> - **Các baseline đối sánh trong cùng thí nghiệm:**
>   1. **[D24]** DeepIOD Model A/B/C & Model C-Mobile (hiện có trong Aetron — Dastagir et al., Sensors 2024, `10.3390/s24165125`)
>   2. **[A18]** MagIO GNB (Ashraf et al., Micromachines 2018, `10.3390/mi9100534`) & Aetron iOS `[MagIO+Acc+Daytime]` MLP
>   3. **[L14]** IODetector (Li et al., ACM TOSN 2014, `10.1145/2659466`)
> - **Lọc thời gian hậu kỳ (tùy chọn, thuộc họ Bayes):** **[Z19]** Causal 2-state HMM (Zhu et al., Sensors 2019, `10.3390/s19040786`) — chỉ được phép tune tham số chuyển trạng thái trên tập Validation.
> - **Loại:** **FAITHFUL REPRODUCTION** cho kiến trúc CAP-ALSTM & quy trình SHAP trên bộ dữ liệu gốc CIOD; **ADAPTATION** khi đánh giá các tập con cảm biến cho Android/iOS & chống nhiễu vận động (locomotion confounding) trên HAR-PMD.
> - **Phần cũ giữ nguyên/cách ly:** Toàn bộ mode cũ (`deepiodMobile`, `iosMultiSensorHmm`) vẫn giữ để so sánh A/B; không xoá `isObservationalOnly: true` cho đến khi có kiểm chứng thiết bị thật.

---

## 1. Tại sao chọn Bakirtzis 2022 (CAP-ALSTM) là bài báo tối ưu nhất?

1. **Khớp 100% với bộ dữ liệu CIOD đang dùng:** Chính Bakirtzis et al. (2022) là nhóm tác giả công bố tập **Cambridge CIOD** (`10.17863/CAM.82668`, `tooling/data/ciod/Data_Supporting_IOD_DL_MTSC_JIoT.csv`). Trước đây Aetron dùng dataset của Bakirtzis 2022 nhưng lại cài mô hình DeepIOD (2024) và chỉ đạt `73.64%` Acc / `69.59%` Macro-F1 / `45.28%` Outdoor Recall trên full 201,731 mẫu.
2. **Có sẵn toàn văn PDF & thông số chính xác (đã kiểm S0 trực tiếp từ `Bakirtzis2022_IOD_JIoT.pdf`):** Không phải đoán kiến trúc hay suy diễn từ abstract.
3. **Giải quyết trực tiếp bài toán Fitness App (Locomotion Confounding trên HAR-PMD):** Báo cáo `HAR_PMD_EXTERNAL_BENCHMARK_REPORT.md` phát hiện DeepIOD Model C-Mobile sụp đổ còn `55.36%` Macro-F1 trên HAR-PMD vì học nhầm *"Acc cao = Outdoor"*. Bakirtzis 2022 cung cấp sẵn **Kernel SHAP feature attribution & sensor ablation (Mục III-D & Mục V)** — cho phép chứng minh khoa học việc **cắt/giảm phụ thuộc `Acc`** để giữ độ chính xác khi người dùng chạy/đi bộ trong nhà (treadmill) lẫn ngoài trời!
4. **Nhẹ & nhanh trên mobile:** Bản CAP-ALSTM gốc chỉ có **~74K tham số**, chiếm **5.4 MB**, thời gian suy luận đơn điểm **4.9 ms** (Bảng I của bài báo, trang 8), hoàn toàn chạy được bằng thuần Dart trên điện thoại như `DeepIodModelC`.

---

## 2. Đặc tả chính xác từ PDF [Bk22] (Đã kiểm S0)

### 2.1. Dữ liệu & Tiền xử lý (Mục III-A, trang 4)
- **8 kênh đầu vào gốc ($M=8$):** `RSRP`, `RSRQ`, `Light`, `Mag`, `Acc`, `Sound`, `Proximity`, `Daytime` (0/1).
- **Tần số lấy mẫu:** `1 Hz`. Đầu vào là cửa sổ trượt nhân quả (causal) $X_t \in \mathbb{R}^{w \times M}$ trên $(t - w, t]$ với bước trượt $s = 1$.
- **Kích thước cửa sổ thử nghiệm (Mục IV-B & IV-C, trang 8–10):** $w \in \{6, 12, 25, 50\}$ giây.
- **Làm sạch & chuẩn hoá (trang 4):** Loại bỏ top 1% outlier cực đoan (do lỗi cảm biến), sau đó áp dụng **min-max normalization**.
  - *Biện pháp chống rò rỉ dữ liệu của Aetron:* Ngưỡng percentile 99% và min/max chỉ tính trên **tập Train (Sessions 00..59)** rồi áp dụng cố định lên Validation (`60..71`) và Held-Out Test (`72..84`).

### 2.2. Kiến trúc CAP-ALSTM (Mục III-C, Hình 3 & 4, trang 5–6, 8)
1. **Block 1 (Conv1D + MaxPool tùy chọn — lặp 2 lần):**
   - Lần 1: `Conv1D(filters=32, kernel_size=3, padding='same', activation='relu')`
   - Lần 2: `Conv1D(filters=64, kernel_size=3, padding='same', activation='relu')`
   - *Quy tắc pooling theo $w$ (Mục IV-C, trang 9):* bỏ `MaxPool1D(2)` khi $w \in \{6, 12\}$; dùng 1 `MaxPool1D(2)` khi $w = 25$; dùng 2 `MaxPool1D(2)` khi $w = 50$ sao cho chuỗi vào ASPP có độ dài $\approx 12$.
2. **Block 2 — ASPP (Atrous Spatial Pyramid Pooling, trang 6):**
   - 4 nhánh song song từ đầu ra Block 1:
     - Nhánh 1: `Conv1D(64, k=3, dilation_rate=1, padding='same', relu)`
     - Nhánh 2: `Conv1D(64, k=3, dilation_rate=2, padding='same', relu)`
     - Nhánh 3: `Conv1D(64, k=3, dilation_rate=3, padding='same', relu)`
     - Nhánh 4: `Conv1D(64, k=3, dilation_rate=4, padding='same', relu)`
   - `Concatenate` (256 kênh) $\rightarrow$ `Conv1D(32, k=1, relu)` nén còn 32 kênh.
3. **Block 3 — Two-Layer LSTM with Intermediate Self-Attention (Hình 3, trang 5–6, 8):**
   - LSTM tầng 1: `LSTM(units=32, return_sequences=True)` tạo chuỗi trạng thái ẩn $h_1, \dots, h_T \in \mathbb{R}^{32}$.
   - Cơ chế Attention kiểu Bahdanau (Phương trình 2–4, trang 5) tạo vector ngữ cảnh $ec_t = \sum_{j=1}^{T} a_{t,j} h_j$ với $e_{t,j} = g(h'_{t-1}, h_j)$ (MLP alignment), $a_{t,j} = \text{softmax}_j(e_{t,j})$.
   - LSTM tầng 2: `LSTM(units=32)` nhận $(y_{t-1}, h'_{t-1}, ec_t)$ (hoặc chuỗi context $ec_1 \dots ec_T$ qua các bước giải mã) $\rightarrow$ trạng thái ẩn cuối $h'_T \in \mathbb{R}^{32}$.
4. **Block 4 — MLP phân loại (trang 6, 8):**
   - `Dense(32, relu)` $\rightarrow$ `Dense(1, sigmoid)` xuất $P(\text{Indoor})$ (hoặc đảo quy ước nhất quán với Aetron $P(\text{Outdoor})$ và ghi rõ quy ước trong manifest).

### 2.3. Huấn luyện & Đánh giá (Mục IV, trang 7–8)
- Optimizer: `Adam(lr=0.001)`, Loss: `BinaryCrossentropy` (bổ sung thử nghiệm class-weighted BCE trên validation vì CIOD lệch lớp Indoor/Outdoor).
- Batch size: `512`, tối đa `250` epochs (dùng Early Stopping trên Validation Macro-F1 để tránh overfit).
- **Metric báo cáo đầy đủ:** Accuracy, Macro-F1, Indoor Recall/Precision, Outdoor Recall/Precision, Transition Detection Delay $d$ (mean ± std, median sec), số tham số, single-prediction latency (ms).

---

## 3. Thiết kế Thử nghiệm để đạt Benchmark Tốt nhất nhưng Hoàn toàn Hợp lệ

### 3.1. Bộ chia dữ liệu nghiêm ngặt (Zero Leakage)
1. **In-Distribution (Cambridge CIOD, 85 sessions):**
   - **Train:** Sessions `00..59` (chỉ fit scaler min-max, trọng số mạng, và SHAP background).
   - **Validation:** Sessions `60..71` (chỉ dùng để chọn $w \in \{6, 12, 25, 50\}$, early stopping, threshold tối ưu Macro-F1, temperature scaling, và tham số chuyển trạng thái HMM [Z19]).
   - **Held-Out Test:** Sessions `72..84` (`201,731` epochs — **TUYỆT ĐỐI KHÔNG CHẠM** cho tới khi đóng băng mọi mô hình).
2. **External Out-of-Distribution & Fitness Stress Test (HAR-PMD, `tooling/data/har_pmd/`):**
   - 120 đối tượng, 40 mẫu điện thoại Android, 480 bản ghi (`288,466` epochs, cân bằng 50% Indoor / 50% Outdoor, có đủ đi bộ/chạy/đứng ở cả hai môi trường).
   - Đánh giá **zero-shot** mô hình train từ CIOD (không fine-tune trên HAR-PMD) để đo thực chất khả năng khái quát hoá trong bối cảnh fitness!

### 3.2. Ma trận Ablation theo năng lực cảm biến thực tế (Platform-Aware + SHAP)
Thực hiện SHAP (Mục III-D của [Bk22]) để chứng minh đóng góp từng cảm biến, sau đó train & test 4 biến thể CAP-ALSTM tương ứng với thực tế mobile:
1. **`CAP-ALSTM-8ch (Paper Full):**` Đủ 8 kênh CIOD — kiểm chứng tái hiện số gốc bài báo (`89.36%` ở $w=6$, `~95.3%` ở $w=50$).
2. **`CAP-ALSTM-Android-6ch (No-Sound, No-Prox hoặc No-Sound):**` `[RSRP, RSRQ, Light, Mag, Acc, Daytime]` (không cần xin quyền Microphone liên tục trong khi tập).
3. **`CAP-ALSTM-4ch-Mobile` vs `CAP-ALSTM-3ch-MotionFree`:**
   - 4ch: `[Light, Mag, Acc, Daytime]` — đối sánh trực tiếp 1-1 với DeepIOD Model C-Mobile hiện tại (`73.64%` Acc / `69.59%` Macro-F1).
   - **3ch Motion-Free (hoặc `Light + Mag + Daytime` / `RSRP + Light + Mag + Daytime`):** Kiểm chứng giả thuyết loại `Acc` theo SHAP để **xoá lỗi locomotion confounding** trên HAR-PMD (`55.36%` $\rightarrow$ mục tiêu cải thiện mạnh trên bài toán đi/chạy trong nhà vs ngoài trời!).
4. **`CAP-ALSTM-iOS-LightFree`:** `[Mag, Acc, Daytime]` và `[Mag, Daytime]` (không cần `TYPE_LIGHT`, không cần `RSRP` vì iOS sandbox hạn chế) — đối sánh trực tiếp với iOS MLP (`74.97%` Macro-F1) và MagIO GNB.
5. **`+ Causal HMM [Z19]` & `+ Validation Threshold Tuning`:** Đo riêng hiệu quả trước và sau bộ lọc thời gian Bayes [Z19] trên validation/test.

---

## 4. Kiến trúc Code & Hợp đồng Tích hợp (Minimal-Change)

### 4.1. Python Training & Benchmark (`tooling/`)
- Tạo mới `tooling/train_cap_alstm_iod.py`:
  - Cài đặt chính xác `CapAlstmModel` (PyTorch) theo Section III-C của `Bakirtzis2022_IOD_JIoT.pdf`.
  - Hỗ trợ `--features`, `--window {6,12,25,50}`, `--class-weight`, `--seed`, xuất `weights.json` + `scaler.json` + `metadata.json` (SHA-256 dataset, split, val threshold, HMM params).
  - Chạy Kernel SHAP / GradientSHAP xuất bảng đóng góp cảm biến.
- Tạo mới `tooling/benchmark/evaluate_cap_alstm_ciod_and_harpmd.py`:
  - Xuất bảng Markdown + JSON so sánh đồng thời: Always-Indoor, IODetector, MagIO GNB, DeepIOD Model A/B/C-Mobile, iOS MLP, **CAP-ALSTM (8ch, Android, Mobile-4ch, MotionFree, iOS-LightFree)** $\pm$ **Causal HMM** trên cả **CIOD Held-Out (201,731)** và **HAR-PMD (288,466)**.

### 4.2. Pure Dart Runtime & Parity (`lib/features/iod/`)
- Tạo mới `lib/features/iod/domain/services/cap_alstm_classifier.dart`:
  - Pure Dart forward pass (Conv1D, Atrous Conv1D $r=1..4$, 2-layer LSTM + Bahdanau Self-Attention, Dense, Sigmoid, + tùy chọn Causal 2-state HMM) đọc weights JSON từ `assets/models/iod/`.
  - Kiểm tra parity Python vs Dart trên `500` cửa sổ ngẫu nhiên của CIOD Held-Out (`max_abs_logit_diff <= 1e-5`, `class_agreement == 100%`) trong `test/iod_cap_alstm_parity_test.dart`.
- Nối vào `IodCompositeClassifier` (`lib/features/iod/domain/services/iod_composite_classifier.dart`) qua enum `IodClassifierMode.capAlstmAndroid` và `IodClassifierMode.capAlstmIos`, **giữ nguyên** `isObservationalOnly: true` và giữ nguyên toàn bộ các mode cũ để A/B test.

---

## 5. Constant Provenance (Bảng nguồn gốc hằng số của SDD-06)

| Hằng số / Siêu tham số | Giá trị | Nguồn |
|---|---|---|
| Tần số lấy mẫu | `1 Hz` | [Bk22] Mục III-A, tr. 4 |
| Outlier clip | Top `1%` | [Bk22] Mục III-A, tr. 4 (fit trên Train) |
| Chuẩn hoá | Min-Max $[0, 1]$ | [Bk22] Mục III-A, tr. 4 (fit trên Train) |
| Conv1D Block 1 | `32 -> 64` filters, `k=3` | [Bk22] Mục III-C, tr. 6 |
| ASPP dilation rates | `r = 1, 2, 3, 4`, `64` filters $\rightarrow$ `1x1` `32` filters | [Bk22] Mục III-C, Hình 4, tr. 6 |
| ALSTM units | `32` + `32` + Bahdanau attention + MLP `32 -> 1` | [Bk22] Mục III-C & IV-A, tr. 5–8 |
| Kích thước cửa sổ $w$ | Tập ứng viên `{6, 12, 25, 50}` s | [Bk22] Mục IV-C, tr. 9 (chọn tối ưu trên Validation) |
| Optimizer / Batch / LR | Adam `0.001`, batch `512`, max `250` epochs | [Bk22] Mục IV, tr. 7 |
| Threshold phân loại & HMM $P_{\text{stay}}$ | Tìm lưới trên Validation `60..71` | Validation-only tuning (không chạm Test) |

---

## 6. Tiêu chí Chấp nhận (Acceptance Gates)
1. **Tái hiện [Bk22] 8-ch trên CIOD:** Mô hình tái hiện hoàn chỉnh trên CIOD đạt hiệu năng tương đương mức công bố của bài báo trên tập đánh giá chuẩn, không rò rỉ dữ liệu.
2. **Đánh bại Baseline trên nhóm cảm biến Mobile/iOS (CIOD Full 201,731):**
   - Biến thể Mobile/Android đạt Macro-F1 > `69.59%` và Outdoor Recall > `45.28%` (mức hiện tại của DeepIOD Model C-Mobile).
   - Biến thể iOS Light-Free đạt Macro-F1 $\ge$ `74.97%` (mức hiện tại của iOS MLP) hoặc cải thiện đáng kể sự cân bằng Indoor/Outdoor Recall.
3. **Kiểm định HAR-PMD (Chống Locomotion Confounding):** Đánh giá & công bố minh bạch hiệu năng biến thể bỏ `Acc` vs có `Acc` trên 120 đối tượng HAR-PMD; nếu biến thể bỏ `Acc` giải quyết được sụp đổ trên người đi bộ/chạy trong nhà, ưu tiên chọn nó cho bối cảnh Fitness App.
4. **Parity & Gates kỹ thuật:** Dart-PyTorch parity $\le 10^{-5}$, `flutter analyze` = 0 issues, `flutter test` pass 100%.

---

## 7. Kế hoạch các bước thực hiện SDD-06
- **S0 (ĐÃ XONG):** Đọc toàn văn `Bakirtzis2022_IOD_JIoT.pdf`, xác nhận toàn bộ thông số & dataset CIOD + HAR-PMD có sẵn trên máy.
- **S1:** Viết `tooling/train_cap_alstm_iod.py` + unit test kiểm tra shape, causal masking (không nhìn tương lai), min-max train-only fit.
- **S2:** Huấn luyện & chạy Kernel SHAP + chọn $w$, threshold, HMM trên Validation `60..71`.
- **S3:** Đóng băng weights $\rightarrow$ Chạy Held-Out CIOD `72..84` (`201,731` mẫu) & External HAR-PMD (`288,466` mẫu), xuất bảng đối sánh đầy đủ.
- **S4:** Cài `cap_alstm_classifier.dart` + `test/iod_cap_alstm_parity_test.dart` (parity $\le 10^{-5}$), nối flag vào `IodCompositeClassifier`.
- **S5:** Cập nhật `docs/research/CAP_ALSTM_IOD_BENCHMARK_REPORT.md` & bảng LaTeX cho Thesis Chương 3 & Chương 4.
