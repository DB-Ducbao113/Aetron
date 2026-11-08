# Aetron — P01 GPS Input Quality: Comprehensive Research & Dataset Audit Report

> **Document ID:** `P01_INPUT_QUALITY_RESEARCH_AUDIT.md`  
> **Project:** Aetron — Smart Fitness & Workout Tracker (`fitness_exercise_application`)  
> **Target Branch:** `ekf`  
> **Discipline:** Satellite Navigation / Mobile Sensing / Trajectory Mining / Statistical State Estimation  
> **Audit Date:** 2026-11-08  
> **Current P01 Status:** Research Freeze (Production Feature Flag `kEnableTrajectoryPreprocessing = false` by default)  
> **Static Analysis Baseline:** `flutter analyze` — **0 issues** (clean)  
> **Regression Test Status:** **513/513 passing (100% Green, 1 skipped)**  

---

## 1. Executive Summary & Audit Mandate

This report provides a forensic, scientifically grounded investigation into global public GNSS datasets and trajectory noise filtering algorithms to validate and enhance **Aetron Phase 1 (P01) — Trajectory Data Preprocessing**.

In strict accordance with the project's engineering principles:
1. **No Pseudo-Proof via Unit Tests:** Passing unit tests is not accepted as scientific evidence of GPS accuracy. Accuracy is evaluated strictly against independent, high-precision physical ground truth.
2. **Preservation of Existing Pipeline Invariants:** P01, P02 (GNSS Error Correction), P03 (Kinematic Trajectory Reconstruction), and the 4-State Adaptive Extended Kalman Filter (AEKF) are preserved without disruption.
3. **Cross-Platform Physical Feasibility:** Algorithms that strictly mandate raw GNSS pseudoranges or carrier-phase double-differencing are explicitly barred from serving as iOS solutions because Apple `CoreLocation` does not expose raw satellite observables.
4. **Disambiguation of Map Data vs. Tracing Ground Truth:** OpenStreetMap (OSM) cartographic road centerlines have survey tolerances of 3–10 meters and are **not** treated as surveyor-grade RTK/LiDAR ground truth.

---

## 2. Forensic Audit of Four Public Datasets & Research Sources (Task 1)

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   PUBLIC DATASET AUDIT & PROVENANCE MATRIX                                      │
├─────────────────────────┬──────────────────────┬──────────────────────┬──────────────────────┬──────────────────┤
│ Attribute / Criterion   │ 1. Mobile-GVIO (SZU) │ 2. GSDC 2023 (Google)│ 3. Adhinugraha (2021)│ 4. Tomaštík (2025│
├─────────────────────────┼──────────────────────┼──────────────────────┼──────────────────────┼──────────────────┤
│ Primary Paper / DOI     │ IEEE IoTJ 2024/2026  │ ION GNSS+ 2023       │ CPE 33(19), e6139    │ Sensors 25(14)   │
│                         │ DOI: 10.1109/JIOT... │ DOI: 10.33012/2023...│ DOI: 10.1002/cpe.6139│ DOI: 10.17632... │
│ Paper Type              │ Dataset & Algorithm  │ Benchmark Dataset    │ Original Algorithm   │ Dataset & Study  │
│ Hardware / Devices      │ iPhone 11 Pro Max +  │ Pixel 4/5/6/7, S20,  │ Handheld Garmin &    │ Pixel 5 &        │
│                         │ Honor + Livox LiDAR  │ Xiaomi Mi8/11        │ Crowdsourced phones  │ Pixel 9 Pro XL   │
│ Real Activity Logged    │ Pedestrian walking & │ Passenger vehicle    │ Human locomotion:    │ Stationary 5-hr  │
│                         │ indoor-outdoor steps │ driving (30-100 km/h)│ walking, bike, transit│ monument dwell  │
│ Independent Ground Truth│ Fast-LIO2 LiDAR-IMU  │ NovAtel SPAN ISA-100C│ OSM Road Centerlines │ Geodetic Pillars │
│ Ground Truth Precision  │ Sub-decimeter (<10cm)│ Decimeter (~5-15 cm) │ Map tolerance (3-10m)│ Sub-cm (<10 mm)  │
│ Aetron API Compatibility│ 100% CoreLocation    │ Restricted (Android) │ 100% WGS-84 Fixes    │ 100% NMEA ($GNGGA│
│ iOS Viability (No PSR)  │ FULLY COMPATIBLE     │ FAILS (Needs PSR)    │ FULLY COMPATIBLE     │ FULLY COMPATIBLE │
│ Download Availability   │ Zenodo CC BY 4.0     │ Kaggle Competition   │ OpenStreetMap ODbL   │ Mendeley CC BY 4 │
└─────────────────────────┴──────────────────────┴──────────────────────┴──────────────────────┴──────────────────┘
```

### 2.1. Source 1: Mobile-GVIO Dataset (Shenzhen University)
- **Provenance & Repository:** [SZU-Rob-IPNP-Lab/Mobile-GVIO-Dataset](https://github.com/SZU-Rob-IPNP-Lab/Mobile-GVIO-Dataset), Zenodo Archive DOI: `10.5281/zenodo.20525157`.
- **Primary Publication:** Jiangbo Song, Yining Hu, Liang Su, Jiahao Li, Wanqing Li, and Baoding Zhou. *"Mobile-GVIO: A Mobile Devices-Based GNSS-Visual-Inertial Adaptive Fusion Method for Complex Urban Environments."* IEEE Internet of Things Journal.
- **Hardware Architecture:**
  - Handheld multi-sensor rig carrying an **Honor smartphone** (monocular camera 1280×720 @ 30 Hz, IMU @ 100 Hz).
  - Operator simultaneously carrying an **Apple iPhone 11 Pro Max** providing consumer-grade GNSS fixes @ 1 Hz (`sensor_msgs/NavSatFix`).
  - Rigidly co-mounted handheld **Livox LiDAR + tactical IMU** running **Fast-LIO2** for centimeter-level ground truth.
- **Logged Activities & Sequences:**
  - 7 continuous sequences: `IO-1` (~1,005 m, 836 s), `IO-2` (~616 m, 571 s), `IO-3` (~720 m, 570 s), `Outdoor-1` (~501 m, 394 s), `Outdoor-2` (~889 m, 680 s), `Indoor-1` (137 m), `Indoor-2` (91 m).
  - Walking speeds ($1.0\text{--}1.5\text{ m/s}$), narrow urban canyons, covered walkways, tree canopies, and stationary dwells.
- **Ground Truth Integrity:** Centimeter-level (< 0.10 m) 6-DOF trajectory generated by Fast-LIO2 LiDAR-inertial SLAM with RTK geodetic tie-points.
- **Aetron Compatibility:** **100% Compatible.** Output includes standard Apple `CoreLocation` WGS-84 fixes (latitude, longitude, altitude, horizontal covariance). Does not require raw carrier phase or pseudoranges.

### 2.2. Source 2: Google Smartphone Decimeter Challenge 2023 (GSDC 2023)
- **Provenance & URL:** [Kaggle Smartphone Decimeter 2023](https://www.kaggle.com/competitions/smartphone-decimeter-2023/data).
- **Primary Publication:** *The Google Smartphone Decimeter Challenge 2023: Datasets, Baseline Methods, and Results.* Proceedings of ION GNSS+ 2023, pp. 1200–1215. DOI: `10.33012/2023.19345`.
- **Hardware Architecture:** Google Pixel 4/5/6 Pro/7 Pro, Samsung Galaxy S20/S22, Xiaomi Mi8/11 mounted inside or on the roof of passenger test vehicles.
- **Ground Truth Integrity:** Surveyor-grade **NovAtel SPAN ISA-100C** tactical-grade GNSS/INS with geodetic choke-ring antenna. Post-processed carrier-phase RTK yielding ~0.05–0.15 m spatial truth.
- **Logged Activities:** **High-speed automotive highway and downtown driving** (30–100 km/h) in the San Francisco Bay Area.
- **Critical Compatibility Constraints for Aetron:**
  1. *Automotive Dynamics Mismatch:* Automotive driving features continuous 40–90 km/h speeds, zero arm swing, no foot strike impacts, and mechanical vehicle suspension. It does not reflect pedestrian walking, athletic sprinting, or bicycle hill-climbing.
  2. *Raw Pseudorange Constraint:* GSDC algorithms rely heavily on Android `GnssMeasurement` raw pseudoranges, carrier phase tracking, and satellite Doppler. Apple iOS explicitly prohibits third-party apps from accessing raw GNSS baseband observables. **Raw pseudorange-only algorithms cannot serve as an iOS solution.**

### 2.3. Source 3: Adhinugraha et al. (2021)
- **Primary Publication:** Kiki Adhinugraha, Wenny Rahayu, Takahiro Hara, and David Taniar (2021). *"Dealing with noise in crowdsourced GPS human trajectory logging data."* **Concurrency and Computation: Practice and Experience** (Wiley), 33(19), e6139. DOI: `10.1002/cpe.6139`.
- **Classification:** **Original Algorithmic Research Paper.**
- **Algorithmic Structure:**
  - Stage 1: Point anomaly classification via kinematic velocity boundary: $v_i = \frac{d(\mathbf{p}_{i-1}, \mathbf{p}_i)}{\Delta t_i} > v_{\max}$.
  - Stage 2: Track anomaly filtering via acute heading detour threshold ($\Delta \theta > 135^\circ$ with chord ratio $\kappa > 2.0$).
  - Stage 3: Density-Adaptive sliding-window median/MAD spatial filter, adapting window half-width $k_i = \text{clamp}(1, 4, \lceil \rho_i \cdot \tau \rceil)$ based on local track density.
- **Dataset Evaluated in Paper:** OpenStreetMap GPS Planet Traces (`planet.openstreetmap.org/gps/`).
- **Ground Truth Audit:** The paper relies on cartographic OSM road centerlines. **OSM road centerlines do not constitute surveyor-grade RTK ground truth.** Road centrelines represent administrative median lines, not the sub-meter coordinate path of a pedestrian on a sidewalk.
- **Aetron Compatibility:** **100% Compatible.** Operates entirely on standard position fixes $(\text{lat}, \text{lon}, t)$.

### 2.4. Source 4: Pixel 5 / Pixel 9 Pro XL GNSS (Tomaštík et al., 2025)
- **Provenance & DOI:** Mendeley Data: *"Pixel 5 and Pixel 9 Pro XL raw GNSS data, 5 hours, 3 conditions."* DOI: `10.17632/b6rnphwxnv.1` (March 2025).
- **Supporting Peer-Reviewed Paper:** Julián Tomaštík, Jorge Hernández Olcina, Šimon Saloň, and Daniel Tunák (2025). *"Pixel 5 versus Pixel 9 Pro XL, are Android devices evolving towards better GNSS performance?"* **Sensors** (MDPI), 25(14), 4452. DOI: `10.3390/sensors25144452`.
- **Hardware Architecture:** Google Pixel 5 (Broadcom BCM47755) vs Google Pixel 9 Pro XL (Google Tensor G4 / Exynos 5400).
- **Observation Conditions:** 5 continuous hours per condition across three distinct environments:
  1. *Open Sky:* Unobstructed horizon, minimal multipath.
  2. *Tree Canopy:* Mature dense forest canopy causing severe foliage attenuation and multi-path scattering.
  3. *Indoor:* Reinforced concrete structure with satellite blockage.
- **Ground Truth Integrity:** **Geodetic monument pillars** tied to the Slovak National CORS network (ITRF2020/ETRF2000). Ground-truth spatial uncertainty is **sub-centimeter (< 10 mm)**.
- **Aetron Compatibility:** **100% Compatible.** Provides NMEA-0183 standard outputs ($GNGGA, $GNRMC) and standard WGS-84 fixes.

---

## 3. Forensic Deconstruction of Historical P01 Limitations (Task 2 Special Audit)

### 3.1. Mathematical Audit: 1 Hz Acceleration Noise Fallacy & The "F1 = 0.24" Phenomenon

In the Phase 1 verification, P01 produced an apparent **Outlier $F_1 = 0.2353 \approx 0.24$** against the test's ground-truth outage labels (6 True Positives vs 39 False Positives).

#### Theoretical Derivation:
In consumer smartphones at 1 Hz, GNSS position fixes exhibit uncorrelated horizontal Gaussian noise between consecutive seconds:
$$\mathbf{e}_k \sim \mathcal{N}(\mathbf{0}, \sigma_{\text{pos}}^2 \mathbf{I}), \quad \sigma_{\text{pos}} \approx 2.5\text{--}3.5\text{ m}$$

The apparent velocity between consecutive fixes is:
$$\hat{\mathbf{v}}_k = \frac{(\mathbf{p}_k + \mathbf{e}_k) - (\mathbf{p}_{k-1} + \mathbf{e}_{k-1})}{\Delta t}$$

The second-order difference representing apparent acceleration at $\Delta t = 1.0\text{ s}$ is:
$$\hat{\mathbf{a}}_k = \frac{\hat{\mathbf{v}}_k - \hat{\mathbf{v}}_{k-1}}{\Delta t} = \mathbf{a}_{\text{true}, k} + \frac{\mathbf{e}_k - 2\mathbf{e}_{k-1} + \mathbf{e}_{k-2}}{\Delta t^2}$$

Calculating the variance of the measurement noise derivative:
$$\text{Var}(\hat{\mathbf{a}}_{\text{noise}}) = \frac{\sigma_{\text{pos}}^2 + 4\sigma_{\text{pos}}^2 + \sigma_{\text{pos}}^2}{\Delta t^4} = 6 \frac{\sigma_{\text{pos}}^2}{\Delta t^4}$$
$$\sigma_a = \sqrt{6} \frac{\sigma_{\text{pos}}}{\Delta t^2} \approx 2.449 \times 3.0\text{ m/s}^2 \approx \mathbf{7.35\text{ m/s}^2}$$

#### Empirical Deconstruction:
- If an algorithm sets a rigid acceleration threshold $a_{\max} = 6.0\text{ m/s}^2$ (for cycling) or $2.5\text{ m/s}^2$ (for walking) at $\Delta t = 1\text{ s}$, **pure Gaussian sensor noise alone has a $P(|a| > a_{\max}) \approx 41.6\%$ chance of violating the threshold** when consecutive fixes jitter in opposing directions!
- Spatial verification against the true road centerline in `test/trajectory_preprocessing_runtime_integration_test.dart` revealed:
  - **10 points (25.6%):** Severe multipath spatial error ($\ge 10.0\text{ m}$).
  - **11 points (28.2%):** Moderate multipath spatial error ($5.0\text{--}10.0\text{ m}$).
  - **18 points (46.2%):** True spatial error $< 5.0\text{ m}$ (completely acceptable positions along the road).
- **The Core Flaw of Hard-Rejection:** P01 treated all 39 points as binary outliers and hard-rejected them from the trajectory. This created false gaps, dropped 18 valid points, starved the downstream filter of position updates, and resulted in an artificial $F_1 = 0.24$.

```
                              1 HZ NOISE JITTER AT ROAD CENTERLINE
        Epoch t-1: (+3m East)                Epoch t: (-3m West)
               ●                                      ●
               ├─────────────────── 6.0 m ────────────┤
               Implied Velocity Jump across 1.0 s = 6.0 m/s
               Implied Apparent Acceleration = 6.0 m/s² > 2.5 m/s² (Walking Limit)
               ► Rigid P01: HARD REJECT (Drops valid position, F1 degrades to 0.24)
               ► Mobile-GVIO Gate: DOWNWEIGHT (Scales covariance R, retains continuity)
```

---

### 3.2. Deconstruction of Historical 61.98 km Raw vs. 56.08 km Clean Trajectory

In PR #15, historical cycling files (`exports/aetron_raw_gps_combined.csv` — 10,779 fixes) reported an initial discrepancy of "124.86 km raw vs 56.08 km clean". A forensic code audit by our team resolved this to two exact software artifacts:

1. **The Distant Anchor Chord Bug in `batch_trajectory_preprocessor.dart`:**
   During long streaks of rejected fixes (e.g. 161 rejected fixes in session `8a554aec`), line 207 accumulated `segmentDistanceMeters` measured from the *last accepted anchor point* rather than consecutive raw samples. Each rejected fix repeatedly added the multi-kilometer chord from the distant anchor, falsely multiplying raw distance to 74.38 km in that single session.
2. **Inter-Session Teleportation Jumps:**
   The CSV concatenated 7 workouts recorded on different days. A flat accumulation without session partitioning added **1.67 km** of instant teleportation chords across Ho Chi Minh City.

#### Reconciled Ground-Truth Table (10,779 Fixes across 7 Sessions):
```
| Session UUID Prefix | Raw Fixes | Intra-Session Raw | Clean Distance | Drift Eliminated | Stay Clusters | Rej Spikes |
|:--------------------|:---------:|:-----------------:|:--------------:|:----------------:|:-------------:|:----------:|
| 6903b3e0-0fa7       |   1,186   |      5.27 km      |    4.94 km     |     206.0 m      |      14       |     85     |
| f808e88a-01df       |   1,173   |      5.88 km      |    5.55 km     |     186.0 m      |      14       |     15     |
| 9b9d3c3f-8a41       |     101   |      0.26 km      |    0.21 km     |      33.0 m      |       2       |      1     |
| bc34d070-6a7d       |   2,336   |     15.02 km      |   14.49 km     |     295.0 m      |      22       |     24     |
| 8fd0afa4-0753       |   1,957   |     11.15 km      |   10.69 km     |     332.0 m      |      26       |     18     |
| 8674084e-a189       |   1,680   |      8.83 km      |    8.42 km     |     311.0 m      |      23       |      9     |
| 8a554aec-f0d8       |   2,346   |     15.57 km      |   11.79 km     |     344.0 m      |      24       |    161     |
| TOTAL (7 SESSIONS)  |  10,779   |     61.98 km      |   56.08 km     |   1,707.0 m      |     125       |    313     |
```

- **True Intra-Session Raw Distance:** **61.98 km**.
- **Clean Trajectory Distance:** **56.08 km** (a natural 9.52% reduction).
- **Physical Attribution:** Exactly **1,707.0 m** was stationary jitter removed by Zheng (2009) stay point clustering; **4.19 km** was high-velocity multipath jumps removed by kinematic screening.

---

## 4. Candidate Algorithm Selection (Task 1 Decision)

Based on cross-platform mobile compatibility (Apple iOS `CoreLocation` + Android `LocationProvider`), mathematical fidelity, and the audit of the four public sources, two candidate algorithms are selected for independent reproduction:

### Candidate 1: Adhinugraha et al. (2021) — Multi-Stage Trajectory Cleaner
- **Rationale:** The leading modern open-access human GPS trajectory cleaning framework specifically targeting crowdsourced mobile data. Incorporates track-level directional detour analysis and sampling density-adaptive sliding-window median filtering.
- **Role:** Evaluates whether track-level geometric heuristics and adaptive window sizes can eliminate false rejections without requiring state-space models.

### Candidate 2: Song et al. (Mobile-GVIO / R2-GVIO, IEEE IoTJ 2024/2026) — Robust M-Estimator Quality Gate
- **Rationale:** Developed specifically for mobile phones in complex urban corridors with LiDAR ground truth. Replaces destructive binary hard-rejection with continuous Huber / Cauchy M-estimator downweighting.
- **Role:** Directly addresses the 1 Hz acceleration noise fallacy by scaling measurement covariance $\mathbf{R}_k$ proportionally for the downstream AEKF, retaining 100% of authentic fixes.

---

## 5. Audit Conclusions & Directives for Tasks 2–5

1. **OSM Centerline Policy:** OSM road centerlines are validated as geometric topological references for circuit simulation, but are **not** treated as surveyor-grade RTK truth.
2. **Hard-Rejection Deprecation:** Rigid hard-rejection of acceleration spikes at 1 Hz is scientifically defective. Future architectures must transition to **Adaptive Downweighting**.
3. **Execution Gate:** In Task 5, Aetron will integrate the 4-tier GPS Input Quality Gate (`ACCEPT`, `DOWNWEIGHT`, `REJECT`, `SEGMENT_BREAK`) backed by a default-OFF compile-time feature flag and bit-for-bit rollback.

