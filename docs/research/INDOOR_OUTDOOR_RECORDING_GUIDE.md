# Aetron Indoor–Outdoor Detection (IOD): Field Recording & Benchmarking Guide

## 1. Overview

This document guides researchers and engineers in executing empirical field benchmarking of the Indoor–Outdoor Detection (IOD) classifier integrated into Aetron. The classifier fuses multi-modal smartphone sensor telemetry:
- **Primary Method:** DeepIOD Multi-Source Adaptive Majority Voter (Sensors 2024, 24(16), 5125; PMCID: PMC11360063).
- **Secondary Method:** Seamless Transition Detection via GNSS $C/N_0$ and motion continuity (Electronics 2025, 14(13), 2598; DOI: 10.3390/electronics14132598).

The classifier operates in **purely observational mode** during workout recording, ensuring zero interference with production distance, GPS filtering, or calorie calculations.

---

## 2. Phone Preparation & Pre-Flight Checklist

Before heading into the field, verify:
1. **Device:** Android smartphone running Android 7.0 (API 24) or newer with physical GNSS, photodiode ambient light sensor, and 3-axis magnetometer.
2. **Permissions:**
   - Location: `Allow all the time` (or `While using the app`) with **Precise Location (Fine Location)** enabled.
   - Physical Activity / Activity Recognition: `Allowed`.
3. **Sensor Verification:**
   - When the workout recording begins, inspect the **IOD Debug Pill** positioned at the bottom-left of the screen.
   - Verify that `GNSS` displays a real-time signal level (e.g., `32dB` outdoors) and `LUX` reflects ambient light (e.g., `> 1000lx` in daylight).
4. **App Build:**
   - Launch via `./run.sh` or build release APK via `./package.sh android`.

---

## 3. Real-World Field Recording Protocol

To build a balanced, statistically significant evaluation dataset, conduct recording sessions covering the following canonical environments:

### Trial A: Open Outdoor Baseline
- **Location:** Open athletic field, university plaza, or unobstructed park.
- **Duration:** 3–5 minutes.
- **Ground Truth Action:** Tap the **IOD Debug Pill** and select **`Ngoài trời` (Outdoor)**.
- **Expected Signals:** Top-4 GNSS $C/N_0 \ge 30\text{ dB-Hz}$, $\ge 6$ satellites used in fix, ambient lux $> 1,000-50,000\text{ lx}$, low magnetic variance ($< 5\ \mu\text{T}^2$).

### Trial B: Outdoor-to-Indoor Transition (Entrance Doorway)
- **Location:** Walking from an outdoor courtyard through glass entrance doors into a multi-story building.
- **Procedure:**
  1. Walk outdoors towards the building for 30 seconds (tagged `Outdoor`).
  2. At the exact moment your feet cross the doorway threshold, tap the IOD Pill and select **`Điểm chuyển tiếp` (Transition)**.
  3. Continue walking inside the lobby for 30 seconds, then tap and select **`Trong nhà` (Indoor)**.
- **Expected Signals:** Sudden $C/N_0$ gradient drop ($\Delta C/N_0 \ge 4-8\text{ dB-Hz}$), satellite count drop, ambient lux dropping below $400\text{ lx}$.

### Trial C: Deep Indoor Space
- **Location:** Deep building interior, windowless gym, lecture hall, or underground corridor.
- **Duration:** 3–5 minutes walking and jogging.
- **Ground Truth Action:** Tag as **`Trong nhà` (Indoor)**.
- **Expected Signals:** GNSS signals severely attenuated or lost ($C/N_0 < 18\text{ dB-Hz}$), ambient lux $< 300\text{ lx}$, high magnetic variance ($> 20\ \mu\text{T}^2$) due to structural steel.

### Trial D: Near-Window / Perimeter Zone
- **Location:** Standing or walking within 1–2 meters of large exterior glass windows inside a building.
- **Ground Truth Action:** Tag as **`Gần cửa sổ` (Near Window)**.
- **Challenge:** Satellite signals may penetrate windows causing GPS multipath; the multi-modal voter uses interior light ($< 400\text{ lx}$) and indoor magnetic anomalies to prevent false outdoor classification.

### Trial E: Urban Canyon
- **Location:** Street surrounded by dense 15+ story concrete and glass buildings.
- **Ground Truth Action:** Tag as **`Hẻm đô thị` (Urban Canyon)**.
- **Challenge:** Degraded GPS accuracy ($> 30\text{ m}$); daylight ($> 5,000\text{ lx}$) and uniform geomagnetic field keep the ensemble accurately classified as Outdoor.

### Trial F: Stationary Condition
- **Location:** Standing completely still indoors and outdoors for 60 seconds each.
- **Ground Truth Action:** Tag as **`Đứng yên` (Stationary)**.

---

## 4. Exporting Recorded Experimental Data

1. At any point during or immediately after a workout recording session:
   - Tap the **IOD Debug Pill** (or open the Ground Truth Sheet).
   - Tap the green **`Xuất CSV / JSON` (Export Data)** button.
2. The system packages:
   - `export_iod_<sessionId>.csv`: Comma-delimited time-series containing all 1 Hz epochs.
   - `export_iod_<sessionId>.json`: Structured JSON document.
3. Use the system share sheet (AirDrop, Google Drive, Email, or ADB pull) to transfer the files to your analysis machine.
   - Files are stored on device at:
     `/data/user/0/com.aetron.app/app_flutter/iod_experiments/`

---

## 5. Exported Dataset Schema

Every exported CSV file follows the strict schema below:

| Column | Type | Description |
| :--- | :--- | :--- |
| `session_id` | String | Unique UUID of the workout session |
| `epoch_index` | Integer | Monotonic 1-second epoch counter ($0, 1, 2, \dots$) |
| `timestamp` | ISO-8601 UTC | Exact time of sensor snapshot |
| `predicted_state` | String | Fused output: `indoor`, `outdoor`, `transition`, `unknown` |
| `confidence` | Float (0.0000–1.0000) | Model confidence metric |
| `deep_iod_p_outdoor` | Float | DeepIOD AMV probability of outdoor environment |
| `transition_p` | Float | Yoo (2025) probability of transition boundary |
| `inference_latency_ms` | Integer | Time taken for feature extraction + inference ($< 10\text{ ms}$) |
| `has_gnss_status` | 0 or 1 | Android GnssStatus callback availability |
| `sat_count` | Integer | Total satellites detected by GNSS chipset |
| `used_sat_count` | Integer | Satellites actively used in positioning solution |
| `mean_cn0` | Float (dB-Hz) | Mean carrier-to-noise density ratio across all satellites |
| `top4_cn0` | Float (dB-Hz) | Mean $C/N_0$ of the 4 strongest satellites |
| `max_cn0` | Float (dB-Hz) | Peak satellite $C/N_0$ |
| `has_gps_fix` | 0 or 1 | Whether location provider produced a fix |
| `gps_lat`, `gps_lon` | Float | Position coordinates (degrees) |
| `gps_acc_m` | Float | Horizontal accuracy 68% confidence radius (meters) |
| `gps_speed_mps` | Float | Kinematic speed (m/s) |
| `has_light_sensor` | 0 or 1 | Ambient photodiode availability |
| `ambient_lux` | Float | Ambient illuminance (lux) |
| `has_imu_data` | 0 or 1 | IMU telemetry availability |
| `accel_mean`, `accel_var`| Float | 3D acceleration magnitude mean & variance ($m/s^2$) |
| `gyro_mean` | Float | 3D angular velocity magnitude ($rad/s$) |
| `mag_mean_ut`, `mag_var` | Float | Geomagnetic field magnitude & variance ($\mu\text{T}$) |
| `step_delta` | Integer | Steps detected in this 1-second window |
| `ground_truth_env` | String | Manually marked reference label: `indoor`, `outdoor`, `transition`, etc. |
| `ground_truth_note` | String | Optional notes timestamped with the label |
| `reasoning` | String | Model explanation and sensor contribution weights |

---

## 6. Offline Benchmark Analysis Script (Python / Pandas / Scikit-Learn)

Use the Python script below to generate the formal benchmark metrics once real field data is collected:

```python
import pandas as pd
import numpy as np
from sklearn.metrics import confusion_matrix, classification_report, accuracy_score

# 1. Load exported session CSV
df = pd.read_csv('export_iod_session_xyz.csv')

# 2. Filter to rows where ground truth was explicitly marked
labeled_df = df[df['ground_truth_env'].notna() & (df['ground_truth_env'] != '')].copy()

# Map fine-grained ground-truth tags to primary classes
label_mapping = {
    'indoor': 'indoor',
    'near_window': 'indoor',
    'outdoor': 'outdoor',
    'urban_canyon': 'outdoor',
    'covered_outdoor': 'transition',
    'transition': 'transition'
}
y_true = labeled_df['ground_truth_env'].map(label_mapping)
y_pred = labeled_df['predicted_state']

# 3. Overall Accuracy & Classification Report
acc = accuracy_score(y_true, y_pred)
print(f"Overall Accuracy: {acc * 100:.2f}%\n")
print(classification_report(y_true, y_pred, digits=4))

# 4. Confusion Matrix
labels = ['indoor', 'outdoor', 'transition']
cm = confusion_matrix(y_true, y_pred, labels=labels)
cm_df = pd.DataFrame(cm, index=[f"True_{l}" for l in labels], columns=[f"Pred_{l}" for l in labels])
print("Confusion Matrix:")
print(cm_df)

# 5. Transition Detection Latency
# Measures elapsed seconds between doorway ground-truth mark and first 'transition' prediction
transition_marks = labeled_df[labeled_df['ground_truth_env'] == 'transition']
for idx, row in transition_marks.iterrows():
    window = df.loc[idx:idx+15] # 15-second subsequent window
    first_detected = window[window['predicted_state'] == 'transition']
    if not first_detected.empty:
        delay_sec = first_detected.iloc[0]['epoch_index'] - row['epoch_index']
        print(f"Transition at epoch {row['epoch_index']} detected with delay: {delay_sec}s")

# 6. Inference Overhead Statistics
print(f"\nMean Inference Latency: {df['inference_latency_ms'].mean():.2f} ms")
print(f"99th Percentile Latency: {np.percentile(df['inference_latency_ms'], 99):.2f} ms")
```
