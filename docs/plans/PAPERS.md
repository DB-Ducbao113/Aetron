# Danh mục Bài báo Khoa học Tham chiếu (Đã xác minh DOI qua Crossref)

> **PDF đã tải về lưu cục bộ tại `docs/plans/papers/`:**
> - [Bakirtzis2022_IOD_JIoT.pdf](papers/Bakirtzis2022_IOD_JIoT.pdf) — **Bài lõi cho IOD (SDD-06)** *(đã đọc toàn văn & trích xuất thông số)*
> - [Bai2022_HybridIOD.pdf](papers/Bai2022_HybridIOD.pdf) — Hybrid Wi-Fi/GNSS SNR IOD *(tham khảo bổ sung)*
> - [10_1109_EMBC_2018_8513319.pdf](papers/10_1109_EMBC_2018_8513319.pdf) — Oxford WPD *(đã đọc toàn văn Table III)*
>
> Các bài đóng quyền truy cập (IEEE/ACM/Springer) hoặc MDPI chặn tải tự động được giữ **link DOI chính thức** bên dưới; có thể mở trực tiếp qua trình duyệt hoặc tài khoản thư viện trường nếu cần đối chiếu sâu thêm.

## A. Nhóm cốt lõi cho phạm vi ít sửa đổi (Core Thesis Scope)

| Ref | Bài báo | DOI / Link | PDF cục bộ | Dùng cho |
|---|---|---|---|---|
| **[Bk22]** | Bakirtzis, Qiu, Wassell, Fiore, Zhang. *Deep Learning-based Multivariate Time Series Classification for Indoor/Outdoor Detection.* IEEE Internet of Things Journal (2022) | https://doi.org/10.1109/JIOT.2022.3190555 | [PDF](papers/Bakirtzis2022_IOD_JIoT.pdf) | **SDD-06 (Chính: CAP-ALSTM + SHAP)** & bộ dữ liệu CIOD (`10.17863/CAM.82668`) |
| **[D24]** | Dastagir, Tariq, Han. *DeepIOD: Towards a Context-Aware Indoor–Outdoor Detection Framework Using Smartphone Sensors.* Sensors 24(16), 5125 (2024) | https://doi.org/10.3390/s24165125 | Link OA (MDPI) | **SDD-06 (Baseline đối sánh: Model A/B/C)** |
| **[A18]** | Ashraf, Hur, Park. *MagIO: Magnetic Field Strength Based Indoor–Outdoor Detection with a Commercial Smartphone.* Micromachines 9(10), 534 (2018) | https://doi.org/10.3390/mi9100534 | Link OA (MDPI/PMC6215188) | **SDD-06 (Baseline không dùng cảm biến ánh sáng / iOS)** |
| **[Z19]** | Zhu, Luo, Wang, Zhao, Ning, Ke, Zhang. *A Fast Indoor/Outdoor Transition Detection Algorithm Based on Machine Learning.* Sensors 19(4), 786 (2019) | https://doi.org/10.3390/s19040786 | Link OA (MDPI) | **SDD-06 (Bộ lọc thời gian Causal 2-state HMM)** |
| **[L14]** | Li, Zhou, Zheng, Li. *IODetector.* ACM Trans. Sensor Networks 11(2), 28 (2014) | https://doi.org/10.1145/2659466 | Link DOI | **SDD-06 (Baseline ngưỡng kinh điển)** |
| **[Ba22]** | Bai, Holden, Kealy, Zaminpardaz, Choy. *A hybrid indoor/outdoor detection approach for smartphone-based seamless positioning.* J. Navigation 75(4), 946–965 (2022) | https://doi.org/10.1017/S0373463322000194 | [PDF](papers/Bai2022_HybridIOD.pdf) | Tham khảo đối sánh ngưỡng SNR GPS |
| **[HP25]** | *Human Activity Recognition Dataset for Pedestrians with Mobility Disabilities (HAR-PMD).* Scientific Data 13 (2025) | https://doi.org/10.1038/s41597-025-06527-y | Dataset `10.5281/zenodo.7939223` | **SDD-06 (Kiểm thử tổng quát hoá ngoài phân phối & locomotion confounding)** |
| **[S18]** | Salvi, Velardo, Brynes, Tarassenko (Oxford). *An optimised algorithm for accurate steps counting from smart-phone accelerometry.* EMBC 2018, pp. 4423–4427 | https://doi.org/10.1109/EMBC.2018.8513319 | [PDF](papers/10_1109_EMBC_2018_8513319.pdf) | **SDD-04, 05 (Đếm bước đi bộ)** |
| **[X22]** | Xu, Li, Li, Yu. *Smartphone-based unconstrained step detection fusing a variable sliding window and an adaptive threshold.* Remote Sens. 14(12), 2926 (2022) | https://doi.org/10.3390/rs14122926 | Link OA (MDPI) | **SDD-04, 05 (Đếm bước chạy bộ)** |
| **[Sk10]** | Skog, Händel, Nilsson, Rantakokko. *Zero-velocity detection — an algorithm evaluation.* IEEE TBME 57(11), 2657–2666 (2010) | https://doi.org/10.1109/TBME.2010.2060723 | Link DOI | **SDD-04 (MV-GLRT loại bước giả khi đứng yên)** |
| **[BH13]** | Brajdic, Harle. *Walk detection and step counting on unconstrained smartphones.* UbiComp 2013, pp. 225–234 | https://doi.org/10.1145/2493432.2493449 | Link DOI | **SDD-04 (Khái niệm walk-bout & benchmark)** |
| **[R12]** | Renaudin, Susi, Lachapelle. *Step length estimation using handheld inertial sensors.* Sensors 12, 8507–8525 (2012) | https://doi.org/10.3390/s120708507 | Link OA (MDPI) | Độ dài bước Eq.8 (đã nghiệm thu) |

## B. Nhóm mở rộng / Future Work (Không bắt buộc trước hạn nộp thesis)

| Ref | Bài báo | DOI / Link | Dùng cho |
|---|---|---|---|
| **[Z09]** | Zheng, Zhang, Xie, Ma. *Mining interesting locations and travel sequences from GPS trajectories.* WWW 2009, pp. 791–800 | https://doi.org/10.1145/1526709.1526816 | SDD-01 (Baseline Stay-Point) |
| **[BB88]** | Blom, Bar-Shalom. *The interacting multiple model algorithm for systems with Markovian switching coefficients.* IEEE TAC 33(8), 780–783 (1988) | https://doi.org/10.1109/9.1299 | SDD-01, 08 (IMM Future Work) |
| **[Y01]** | Yang, He, Xu. *Adaptively robust filtering for kinematic geodetic positioning.* J. Geodesy 75, 109–116 (2001) | https://doi.org/10.1007/s001900000157 | SDD-02 (IGG-III Future Work) |
| **[MS99]** | Mohamed, Schwarz. *Adaptive Kalman filtering for INS/GPS.* J. Geodesy 73, 193–203 (1999) | https://doi.org/10.1007/s001900050236 | SDD-03 (IAE Future Work) |
| **[NK09]** | Newson, Krumm. *Hidden Markov map matching through noise and sparseness.* ACM SIGSPATIAL GIS 2009, pp. 336–343 | https://doi.org/10.1145/1653771.1653818 | SDD-07 (HMM Map Matching Future Work) |
| **[K60]** | Kalman. *A new approach to linear filtering and prediction problems.* J. Basic Eng. 82, 35–45 (1960) | https://doi.org/10.1115/1.3662552 | SDD-08 (Nền tảng Kalman) |
| **[GP20]** | *Accurate and direct GNSS/PDR integration using extended Kalman filter for pedestrian smartphone navigation.* Gyroscopy & Navigation (2020) | https://doi.org/10.1134/S2075108720020054 | SDD-08 (GNSS/PDR Future Work) |
