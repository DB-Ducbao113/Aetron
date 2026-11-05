# Indoor–Outdoor Detection (IOD) Research Fidelity & Traceability

## 1. Executive Summary & Research Basis

This document establishes the scientific grounding, implementation boundaries, and method traceability for Indoor–Outdoor Detection (IOD) within the Aetron application. The implementation adheres strictly to published peer-reviewed research, avoiding improvised heuristics or unverified assumptions.

### Primary Research Basis
* **Title:** *DeepIOD: Towards a Context-Aware Indoor–Outdoor Detection Framework Using Smartphone Sensors*
* **Authors:** Muhammad Bilal Akram Dastagir, Omer Tariq, and Dongsoo Han (School of Computing, KAIST)
* **Journal:** *Sensors* (MDPI), 2024, Vol. 24, Issue 16, Article 5125
* **DOI:** [10.3390/s24165125](https://doi.org/10.3390/s24165125) | **PMCID:** PMC11360063

### Secondary Research Basis
* **Title:** *Seamless Indoor–Outdoor Localization Through Transition Detection*
* **Author:** Jaehyun Yoo (Department of AI Convergence, Sungshin Women's University)
* **Journal:** *Electronics* (MDPI), 2025, Vol. 14, Issue 13, Article 2598
* **DOI:** [10.3390/electronics14132598](https://doi.org/10.3390/electronics14132598)

---

## 2. Research Fidelity & Artifact Availability Audit

A thorough audit of publicly accessible research repositories, MDPI supplementary materials, and author code hosting was conducted:

| Artifact Dimension | DeepIOD (Sensors 2024) | Yoo (Electronics 2025) | Impact on Aetron Implementation |
| :--- | :--- | :--- | :--- |
| **Source Code Public Availability** | **Not Publicly Released** (No official GitHub link provided in paper text) | **Not Publicly Released** | Algorithm implemented from mathematical models and published operational flow |
| **Pretrained Deep Neural Network Weights** | **Unavailable** (Proprietary to KAIST lab) | **N/A** (Probabilistic transition formulation) | Implementation is an **explicitly labeled Literature Baseline**, not a claim of exact DNN reproduction |
| **Benchmark Dataset** | **Proprietary** (Collected across 6 campus buildings) | **Proprietary** (3 buildings, 3 devices) | Aetron provides an offline ground-truth recording tool to collect field benchmarking datasets |
| **Feature Definitions & Preprocessing** | Fully documented in paper (1 Hz normalized epoch, 9-axis IMU, Lux, GPS, AMV) | Fully documented (GNSS $C/N_0$, $N_{\text{sat}}$, $H_{\text{acc}}$, motion continuity) | **Exact alignment** with published input parameters and physical sensor metrics |

---

## 3. Method Traceability Table

The table below maps each paper component to its concrete counterpart in Aetron, explicitly declaring whether each element is an **Exact Reproduction** or a **Declared Adaptation**.

| Component | Published Paper Specification | Aetron Implementation (`lib/features/iod/`) | Traceability Status | Adaptation Justification & Gap |
| :--- | :--- | :--- | :--- | :--- |
| **Sensor Inputs: IMU** | 3-axis Accelerometer, 3-axis Gyroscope, 3-axis Magnetometer ($B = \sqrt{B_x^2+B_y^2+B_z^2}$) | `sensors_plus` aggregated into 1 Hz mean & variance windows | **Exact Reproduction** | Standardized to 1 Hz epoch as specified in DeepIOD Section 3. |
| **Sensor Inputs: Light** | Smartphone ambient light sensor (lux) with indoor/outdoor discrimination | Android `Sensor.TYPE_LIGHT` via native platform channel | **Exact Reproduction** | Gracefully marks `hasLightSensor = false` on hardware lacking ambient light diode. |
| **Sensor Inputs: GNSS** | Carrier-to-noise density ratio ($C/N_0$ dB-Hz), satellite count ($N_{\text{sat}}$), fix accuracy ($H_{\text{acc}}$) | Android `GnssStatus.Callback` & `Geolocator` | **Exact Reproduction** | Reports mean, max, and top-4 $C/N_0$ directly from hardware GNSS chipset. |
| **Sampling Rate** | 1 Hz normalized epoch | 1-second rolling sensor window in `IodSensorAcquisitionService` | **Exact Reproduction** | Prevents battery drain and aligns multi-rate sensors. |
| **DeepIOD: DNN Classifiers** | Deep neural network models (CNN, LSTM) trained on KAIST dataset | Literature-grounded baseline (`DeepIodBaselineClassifier`) | **Declared Adaptation** | **Gap:** Author model weights are unreleased. Aetron implements physical sensor feature modules and voting. |
| **DeepIOD: Light Module** | Dynamic threshold based on illuminance continuity and day/night state | `_evaluateLightModule` with $< 500\text{ lux}$ (indoor) vs $> 1000\text{ lux}$ (outdoor) and solar time check | **Declared Adaptation** | Replicates threshold logic while accounting for night-time pocket mode. |
| **DeepIOD: GPS Module** | GPS satellite fix validity and position dispersion | `_evaluateGpsModule` assessing fix validity, $H_{\text{acc}}$, and speed | **Declared Adaptation** | Does NOT treat weak GPS as indoor; incorporates signal quality. |
| **DeepIOD: Adaptive Majority Voter (AMV)** | Reliability-weighted consensus: $S = \sum w_i P_i$ | `AdaptiveMajorityVoter` dynamically downweighting missing or degraded sensors | **Exact Architectural Reproduction** | Dynamically adapts weights $w_{\text{imu}}, w_{\text{light}}, w_{\text{gps}}$ based on sensor health. |
| **Yoo (2025): Transition Model** | Probabilistic transition detection separating Indoor, Outdoor, and Transition zones | `SeamlessTransitionDetector` calculating likelihoods based on $C/N_0$, $N_{\text{used}}$, and motion continuity | **Exact Reproduction** | Identifies intermediate transition zones (e.g. entrance doors, building thresholds). |
| **App-level State Space** | `Indoor`, `Outdoor`, `Transition`, `Unknown` | `IndoorOutdoorState` enum | **Exact Reproduction** | Decouples raw module outputs from application-level state. |

---

## 4. Architectural Separation & Non-Interference Guarantee

To safeguard production fitness tracking:
1. **Zero Impact on Production Distance:** Production distance calculations (accumulated meters, pace, speed) continue to use the baseline and EKF filters in `WorkoutTrackingEngine`.
2. **Observational Mode Only:** IOD predictions are recorded in parallel and exposed via UI/diagnostics. They do not pause workouts, do not discard GPS points, and do not trigger step-fallback mode during this research phase.
3. **Ground-Truth Isolation:** Manually tagged ground-truth events (e.g. tapping "Outdoor" or "Transition" during field tests) are logged to a distinct field and are never fed into the classifier inputs.
4. **No Unsafe DB Migrations:** Experiment logs are stored locally as structured JSON Lines (`.jsonl`) and Comma-Separated Values (`.csv`) in application documents storage, allowing immediate offline extraction and CSV/Python analysis without modifying Isar or Supabase schemas.
